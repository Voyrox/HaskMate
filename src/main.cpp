#include "commands.hpp"
#include "generate.hpp"
#include "logger.hpp"
#include "settings.hpp"

#include <array>
#include <atomic>
#include <cerrno>
#include <csignal>
#include <cstdint>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <optional>
#include <sstream>
#include <stdexcept>
#include <string>
#include <string_view>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <thread>
#include <unistd.h>

namespace fs = std::filesystem;

namespace
{

    const char *errnoName(int err)
    {
        switch (err)
        {
        case EACCES:
            return "EACCES";
        case EIO:
            return "EIO";
        case ELOOP:
            return "ELOOP";
        case ENAMETOOLONG:
            return "ENAMETOOLONG";
        case ENOENT:
            return "ENOENT";
        case ENOTDIR:
            return "ENOTDIR";
        default:
            return "UNKNOWN";
        }
    }

    std::string statFailureType(int err)
    {
        switch (err)
        {
        case EACCES:
            return " Permission was denied while reading file metadata.";
        case ELOOP:
            return " The path contains too many symbolic-link indirections.";
        case ENAMETOOLONG:
            return " The path is longer than the operating system allows.";
        case ENOENT:
            return " The file or directory does not exist, or it was removed while Zippy was checking it.";
        case ENOTDIR:
            return " A component of the path is not a directory.";
        default:
            return "";
        }
    }

    std::string toErrorMessage(const std::string &prefix)
    {
        return prefix + ": " + std::strerror(errno);
    }

    std::string toStatErrorMessage(const fs::path &path, int err)
    {
        return "failed to read modification time for \"" + path.string() + "\" (" + errnoName(err) + ", errno " + std::to_string(err) + "): " +
               std::strerror(err) + statFailureType(err);
    }

    std::int64_t statMtimeNs(const fs::path &path)
    {
        struct stat info{};
        if (::stat(path.c_str(), &info) != 0)
        {
            const int err = errno;
            throw std::runtime_error(toStatErrorMessage(path, err));
        }
        return static_cast<std::int64_t>(info.st_mtim.tv_sec) * 1'000'000'000LL + static_cast<std::int64_t>(info.st_mtim.tv_nsec);
    }

    std::string replaceAll(std::string source, std::string_view needle, std::string_view replacement)
    {
        std::size_t pos = 0;
        while ((pos = source.find(needle, pos)) != std::string::npos)
        {
            source.replace(pos, needle.size(), replacement);
            pos += replacement.size();
        }
        return source;
    }

    std::string expandPlaceholders(const std::string &command, const fs::path &filePath, const fs::path &dirPath)
    {
        std::string expanded = replaceAll(command, "{file}", filePath.string());
        return replaceAll(expanded, "{dir}", dirPath.string());
    }

    void outWriteAll(const std::string &text)
    {
        std::cout << text;
        std::cout.flush();
    }

    void printSettingsSummary(const Settings &settings, bool hasFile)
    {
        const std::uint64_t effectiveDelay = settings.delay.value_or(defaultDelayUs);
        std::cout << "Zippy configuration (" << (hasFile ? "from Zippy.json" : "defaults") << "):\n";
        std::cout << "  delay (us): " << effectiveDelay << '\n';
        std::cout << "  cmd      : " << settings.cmd << '\n';
        std::cout << "  save_log : " << (settings.saveLog ? "true" : "false") << '\n';
        std::cout << "  log_path : " << settings.logPath << '\n';
    }

    void writeAllFd(int fd, const char *data, std::size_t size)
    {
        std::size_t written = 0;
        while (written < size)
        {
            const ssize_t count = ::write(fd, data + written, size - written);
            if (count < 0)
            {
                if (errno == EINTR)
                {
                    continue;
                }
                break;
            }
            written += static_cast<std::size_t>(count);
        }
    }

    struct ChildProcess
    {
        pid_t pid = -1;
        int stdoutFd = -1;
        int stderrFd = -1;
        std::thread stdoutThread;
        std::thread stderrThread;

        ChildProcess() = default;
        ChildProcess(const ChildProcess &) = delete;
        ChildProcess &operator=(const ChildProcess &) = delete;

        ChildProcess(ChildProcess &&other) noexcept
        {
            *this = std::move(other);
        }

        ChildProcess &operator=(ChildProcess &&other) noexcept
        {
            if (this == &other)
            {
                return *this;
            }
            closeAndJoin();
            pid = other.pid;
            stdoutFd = other.stdoutFd;
            stderrFd = other.stderrFd;
            stdoutThread = std::move(other.stdoutThread);
            stderrThread = std::move(other.stderrThread);
            other.pid = -1;
            other.stdoutFd = -1;
            other.stderrFd = -1;
            return *this;
        }

        ~ChildProcess()
        {
            closeAndJoin();
        }

        void terminate() const
        {
            if (pid <= 0)
            {
                return;
            }
            if (::kill(pid, SIGKILL) != 0 && errno != ESRCH)
            {
                throw std::runtime_error(toErrorMessage("Failed to kill child process"));
            }
        }

        void wait()
        {
            if (pid <= 0)
            {
                closeAndJoin();
                return;
            }
            int status = 0;
            while (::waitpid(pid, &status, 0) < 0)
            {
                if (errno == EINTR)
                {
                    continue;
                }
                if (errno == ECHILD)
                {
                    break;
                }
                throw std::runtime_error(toErrorMessage("Failed to wait for child process"));
            }
            pid = -1;
            closeAndJoin();
        }

        void closeAndJoin()
        {
            if (stdoutFd >= 0)
            {
                ::close(stdoutFd);
                stdoutFd = -1;
            }
            if (stderrFd >= 0)
            {
                ::close(stderrFd);
                stderrFd = -1;
            }
            if (stdoutThread.joinable())
            {
                stdoutThread.join();
            }
            if (stderrThread.joinable())
            {
                stderrThread.join();
            }
        }
    };

    void streamPipe(int fd, int targetFd, Logger &logger)
    {
        std::array<char, 4096> buffer{};
        while (true)
        {
            const ssize_t count = ::read(fd, buffer.data(), buffer.size());
            if (count == 0)
            {
                break;
            }
            if (count < 0)
            {
                if (errno == EINTR)
                {
                    continue;
                }
                break;
            }
            writeAllFd(targetFd, buffer.data(), static_cast<std::size_t>(count));
            logger.writeRaw(std::string_view(buffer.data(), static_cast<std::size_t>(count)));
        }
    }

    ChildProcess spawnShell(const std::string &cmd, const fs::path &cwd, bool captureOutput, Logger &logger)
    {
        int stdoutPipe[2] = {-1, -1};
        int stderrPipe[2] = {-1, -1};

        if (captureOutput)
        {
            if (::pipe(stdoutPipe) != 0)
            {
                throw std::runtime_error(toErrorMessage("pipe failed for stdout"));
            }
            if (::pipe(stderrPipe) != 0)
            {
                ::close(stdoutPipe[0]);
                ::close(stdoutPipe[1]);
                throw std::runtime_error(toErrorMessage("pipe failed for stderr"));
            }
        }

        const pid_t pid = ::fork();
        if (pid < 0)
        {
            if (captureOutput)
            {
                ::close(stdoutPipe[0]);
                ::close(stdoutPipe[1]);
                ::close(stderrPipe[0]);
                ::close(stderrPipe[1]);
            }
            throw std::runtime_error(toErrorMessage("fork failed"));
        }

        if (pid == 0)
        {
            if (::chdir(cwd.c_str()) != 0)
            {
                std::cerr << toErrorMessage("chdir failed") << '\n';
                _exit(1);
            }

            if (captureOutput)
            {
                ::close(stdoutPipe[0]);
                ::close(stderrPipe[0]);
                if (::dup2(stdoutPipe[1], STDOUT_FILENO) < 0 || ::dup2(stderrPipe[1], STDERR_FILENO) < 0)
                {
                    std::cerr << toErrorMessage("dup2 failed") << '\n';
                    _exit(1);
                }
                ::close(stdoutPipe[1]);
                ::close(stderrPipe[1]);
            }

            ::execl("/bin/sh", "sh", "-c", cmd.c_str(), static_cast<char *>(nullptr));
            std::cerr << toErrorMessage("exec failed") << '\n';
            _exit(127);
        }

        ChildProcess child;
        child.pid = pid;

        if (captureOutput)
        {
            ::close(stdoutPipe[1]);
            ::close(stderrPipe[1]);
            child.stdoutFd = stdoutPipe[0];
            child.stderrFd = stderrPipe[0];
            child.stdoutThread = std::thread(streamPipe, child.stdoutFd, STDOUT_FILENO, std::ref(logger));
            child.stderrThread = std::thread(streamPipe, child.stderrFd, STDERR_FILENO, std::ref(logger));
        }

        return child;
    }

    ChildProcess runConfiguredCommand(Logger &logger, const Settings &settings, const fs::path &dirPath, const fs::path &filePath)
    {
        if (settings.cmd.empty())
        {
            logger.err("Zippy.json loaded but \"cmd\" is empty");
            throw std::runtime_error("empty command");
        }

        const std::string expanded = expandPlaceholders(settings.cmd, filePath, dirPath);
        logger.info("Running: " + expanded);
        return spawnShell(expanded, dirPath, settings.saveLog, logger);
    }

    struct WatchState
    {
        std::int64_t mtime;
        fs::path filePath;
    };

    WatchState computeWatchState(const fs::path &watchDir, const std::optional<fs::path> &maybeFile)
    {
        if (maybeFile.has_value())
        {
            return WatchState{.mtime = statMtimeNs(*maybeFile), .filePath = *maybeFile};
        }

        std::int64_t bestMtime = statMtimeNs(watchDir);
        fs::path bestPath = watchDir;

        for (const auto &entry : fs::directory_iterator(watchDir))
        {
            const std::int64_t entryMtime = statMtimeNs(entry.path());
            if (entryMtime > bestMtime)
            {
                bestMtime = entryMtime;
                bestPath = entry.path();
            }
        }

        return WatchState{.mtime = bestMtime, .filePath = std::move(bestPath)};
    }

    void monitorScript(Logger &logger, std::uint64_t delayUs, const fs::path &watchDir, const std::optional<fs::path> &watchFile,
                       const Settings &settings)
    {
        WatchState state = computeWatchState(watchDir, watchFile);
        ChildProcess currentChild = runConfiguredCommand(logger, settings, watchDir, state.filePath);

        while (true)
        {
            std::this_thread::sleep_for(std::chrono::microseconds(delayUs));

            WatchState next = computeWatchState(watchDir, watchFile);
            if (next.mtime > state.mtime)
            {
                logger.warn("File changed; re-running command...");
                currentChild.terminate();
                currentChild.wait();
                currentChild = runConfiguredCommand(logger, settings, watchDir, next.filePath);
                state = std::move(next);
            }
        }
    }

    std::string readFile(const fs::path &path)
    {
        std::ifstream file(path, std::ios::in | std::ios::binary);
        if (!file.is_open())
        {
            throw std::runtime_error("failed to open file: " + path.string());
        }
        std::ostringstream buffer;
        buffer << file.rdbuf();
        return buffer.str();
    }

    void clearFile(const fs::path &path)
    {
        std::ofstream file(path, std::ios::out | std::ios::trunc | std::ios::binary);
        if (!file.is_open())
        {
            throw std::runtime_error("failed to clear file: " + path.string());
        }
    }

} // namespace

int main(int argc, char **argv)
{
    Logger logger("zippy");

    try
    {
        if (argc == 1)
        {
            logger.err("No path provided. Examples: zippy ./Main.hs or zippy .");
            return 1;
        }

        const std::string arg1 = argv[1];

        if (arg1 == "--help" || arg1 == "--h")
        {
            commands::displayHelpData();
            return 0;
        }
        if (arg1 == "--generate" || arg1 == "--gen")
        {
            generate::generateConfig();
            return 0;
        }
        if (arg1 == "--version" || arg1 == "--v")
        {
            commands::displayVersionData();
            return 0;
        }
        if (arg1 == "--credits")
        {
            commands::displayCreditsData();
            return 0;
        }

        const fs::path jsonPath = "Zippy.json";
        const std::optional<Settings> hasSettings = loadSettings(jsonPath);
        Settings settings = hasSettings.value_or(defaultSettings());

        if (hasSettings.has_value())
        {
            logger.success("Loaded settings from Zippy.json");
        }
        else
        {
            logger.warn("No Zippy.json found; using defaults");
        }

        const std::uint64_t delayUs = settings.delay.value_or(defaultDelayUs);

        if (settings.saveLog)
        {
            try
            {
                logger.enableFileLogging(settings.logPath);
            }
            catch (const std::exception &ex)
            {
                logger.warn("Could not open log file " + settings.logPath + ": " + ex.what());
            }
        }

        if (arg1 == "--config")
        {
            printSettingsSummary(settings, hasSettings.has_value());
            return 0;
        }
        if (arg1 == "--log")
        {
            if (settings.saveLog)
            {
                try
                {
                    outWriteAll(readFile(settings.logPath));
                }
                catch (...)
                {
                    logger.warn("Log file not found: " + settings.logPath);
                }
            }
            else
            {
                logger.warn("Logging is disabled (save_log=false)");
            }
            return 0;
        }
        if (arg1 == "--clear")
        {
            if (settings.saveLog)
            {
                try
                {
                    clearFile(settings.logPath);
                    logger.info("Log cleared: " + settings.logPath);
                }
                catch (...)
                {
                    logger.warn("Log file not found: " + settings.logPath);
                }
            }
            else
            {
                logger.warn("Logging is disabled (save_log=false)");
            }
            return 0;
        }

        const fs::path cwd = fs::current_path();
        const fs::path targetPath = fs::absolute(cwd / arg1);

        if (!fs::exists(targetPath))
        {
            throw std::runtime_error("path not found: " + targetPath.string());
        }

        const bool isDir = fs::is_directory(targetPath);
        const fs::path watchDir = isDir ? targetPath : targetPath.parent_path();
        const std::optional<fs::path> watchFile = isDir ? std::nullopt : std::optional<fs::path>(targetPath);

        logger.info("Starting Zippy v1.3.0");
        if (settings.saveLog)
        {
            logger.info("Logging to: " + settings.logPath);
        }
        if (watchFile.has_value())
        {
            logger.info("Watching file: " + watchFile->string());
        }
        else
        {
            logger.info("Watching directory: " + watchDir.string());
        }
        logger.info("Press Ctrl+C to exit");

        monitorScript(logger, delayUs, watchDir, watchFile, settings);
    }
    catch (const std::exception &ex)
    {
        logger.err(ex.what());
        return 1;
    }

    return 0;
}
