#include "commands.hpp"

#include <iostream>
#include <string>

namespace
{

    struct Colors
    {
        static constexpr const char *red = "\x1b[31m";
        static constexpr const char *white = "\x1b[37m";
        static constexpr const char *yellow = "\x1b[33m";
        static constexpr const char *green = "\x1b[32m";
        static constexpr const char *reset = "\x1b[0m";
    };

    void printLine(const std::string &text)
    {
        std::cout << text;
    }

    std::string repeatChar(char value, std::size_t count)
    {
        return std::string(count, value);
    }

}

namespace commands
{

    void displayHelpData()
    {
        const std::string message = "Welcome to Zippy!";
        const std::size_t boxWidth = message.size() + 4;
        const std::string line = repeatChar('-', boxWidth - 2);
        const std::size_t paddingCount = (boxWidth - message.size() - 2) / 2;
        const std::string padding = repeatChar(' ', paddingCount);

        printLine(std::string(Colors::red) + "+" + line + "+\n" + Colors::reset);
        printLine(std::string(Colors::red) + "|" + Colors::reset + padding + Colors::green + message + Colors::reset + padding + " |\n");
        printLine(std::string(Colors::red) + "+" + line + "+\n" + Colors::reset);
        printLine(std::string(Colors::green) + "Example:\n" + Colors::reset);
        printLine(std::string(Colors::white) + "  zippy app/Main.hs\n\n" + Colors::reset);
        printLine(std::string(Colors::yellow) + "Commands:\n" + Colors::reset);
        printLine(std::string(Colors::white) + "  --help      Display help information\n" + Colors::reset);
        printLine(std::string(Colors::white) + "  --version   Display version information/Check for updates\n" + Colors::reset);
        printLine(std::string(Colors::white) + "  --config    Configure Zippy\n" + Colors::reset);
        printLine(std::string(Colors::white) + "  --log       Display Zippy log\n" + Colors::reset);
        printLine(std::string(Colors::white) + "  --clear     Clear Zippy log\n" + Colors::reset);
        printLine(std::string(Colors::white) + "  --credits   Display credits\n" + Colors::reset);
    }

    void displayConfigData()
    {
        printLine(std::string(Colors::yellow) + "Configuration options (Zippy.json):\n" + Colors::reset);
        printLine(std::string(Colors::white) + "  delay (u64 microseconds)        Debounce between checks (default 1000000)\n" + Colors::reset);
        printLine(std::string(Colors::white) + "  cmd (string)                    Command to run; placeholders {file}, {dir}\n" + Colors::reset);
        printLine(std::string(Colors::white) + "  save_log (bool)                 Enable log file (default false)\n" + Colors::reset);
        printLine(std::string(Colors::white) + "  log_path (string)               Path to log file (default zippy.log)\n" + Colors::reset);
    }

    void displayLogData()
    {
        printLine(std::string(Colors::yellow) + "--log shows log file contents when save_log=true.\n" + Colors::reset);
        printLine(std::string(Colors::white) + "Log file path is configured via log_path in Zippy.json.\n" + Colors::reset);
        printLine(std::string(Colors::white) + "When save_log=true, child command output is also tee'd to the log.\n" + Colors::reset);
    }

    void displayClearData()
    {
        printLine(std::string(Colors::yellow) + "--clear truncates the configured log file when save_log=true.\n" + Colors::reset);
    }

    void displayCreditsData()
    {
        printLine(std::string(Colors::yellow) + "Credits:\n" + Colors::reset);
        printLine(std::string(Colors::green) + "Developed by: Ewen MacCulloch\n" + Colors::reset);
        printLine(std::string(Colors::green) + "GitHub: Voyrox\n\n" + Colors::reset);
    }

    void displayVersionData()
    {
        const std::string currentVersion = "v1.3.1";
        printLine(std::string(Colors::green) + "  Current version: " + currentVersion + Colors::white + "\n" + Colors::reset);
        printLine(std::string(Colors::white) + "  https://github.com/Voyrox/Zippy/releases/latest\n" + Colors::reset);
    }

} // namespace commands
