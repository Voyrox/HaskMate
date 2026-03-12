#include "logger.hpp"

#include <chrono>
#include <ctime>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <stdexcept>
#include <unistd.h>

namespace
{

    constexpr const char *reset = "\x1b[0m";
    constexpr const char *dim = "\x1b[2m";
    constexpr const char *red = "\x1b[31m";
    constexpr const char *yellow = "\x1b[33m";
    constexpr const char *green = "\x1b[32m";
    constexpr const char *cyan = "\x1b[36m";

}

Logger::Logger(std::string name) : name_(std::move(name)), useColor_(::isatty(STDERR_FILENO) != 0) {}

Logger::~Logger()
{
    deinit();
}

void Logger::enableFileLogging(const std::filesystem::path &path)
{
    deinit();
    file_.open(path, std::ios::out | std::ios::app | std::ios::binary);
    if (!file_.is_open())
    {
        throw std::runtime_error("failed to open log file");
    }
    logPath_ = path;
}

void Logger::deinit()
{
    std::lock_guard<std::mutex> lock(mutex_);
    if (file_.is_open())
    {
        file_.flush();
        file_.close();
    }
    logPath_.clear();
}

void Logger::setColor(bool enabled)
{
    useColor_ = enabled;
}

void Logger::info(const std::string &message)
{
    log(Level::info, message);
}

void Logger::warn(const std::string &message)
{
    log(Level::warn, message);
}

void Logger::err(const std::string &message)
{
    log(Level::err, message);
}

void Logger::success(const std::string &message)
{
    log(Level::success, message);
}

void Logger::debug(const std::string &message)
{
    log(Level::debug, message);
}

void Logger::writeRaw(std::string_view data)
{
    std::lock_guard<std::mutex> lock(mutex_);
    if (!file_.is_open())
    {
        return;
    }
    file_.write(data.data(), static_cast<std::streamsize>(data.size()));
    file_.flush();
}

void Logger::log(Level level, const std::string &message)
{
    const std::string ts = formatTimestamp();
    const char *tag = levelTag(level);
    const char *tagColor = levelColor(level);

    std::ostringstream plain;
    plain << ts << " [" << tag << "] " << name_ << ' ' << message << '\n';

    if (useColor_)
    {
        std::cerr << dim << ts << reset << ' ' << tagColor << '[' << tag << ']' << reset << ' ' << cyan << name_ << reset << ' '
                  << message << '\n';
    }
    else
    {
        std::cerr << plain.str();
    }
    std::cerr.flush();

    writeRaw(plain.str());
}

const char *Logger::levelTag(Level level)
{
    switch (level)
    {
    case Level::info:
        return "INFO";
    case Level::warn:
        return "WARN";
    case Level::err:
        return "ERROR";
    case Level::success:
        return "SUCCESS";
    case Level::debug:
        return "DEBUG";
    }
    return "INFO";
}

const char *Logger::levelColor(Level level)
{
    switch (level)
    {
    case Level::info:
        return cyan;
    case Level::warn:
        return yellow;
    case Level::err:
        return red;
    case Level::success:
        return green;
    case Level::debug:
        return dim;
    }
    return cyan;
}

std::string Logger::formatTimestamp()
{
    const auto now = std::chrono::system_clock::now();
    const auto millis = std::chrono::duration_cast<std::chrono::milliseconds>(now.time_since_epoch()) % 1000;
    const std::time_t current = std::chrono::system_clock::to_time_t(now);

    std::tm parts{};
    if (localtime_r(&current, &parts) == nullptr)
    {
        std::ostringstream fallback;
        fallback << current << '.' << std::setw(3) << std::setfill('0') << millis.count();
        return fallback.str();
    }

    std::ostringstream stream;
    stream << std::put_time(&parts, "%Y-%m-%d %H:%M:%S") << '.' << std::setw(3) << std::setfill('0') << millis.count();
    return stream.str();
}
