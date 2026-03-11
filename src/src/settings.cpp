#include "settings.hpp"

#include <fstream>
#include <nlohmann/json.hpp>
#include <sstream>

Settings defaultSettings()
{
    return Settings{
        .ignore = {},
        .delay = defaultDelayUs,
        .cmd = "",
        .saveLog = defaultSaveLog,
        .logPath = defaultLogPath,
    };
}

std::optional<Settings> loadSettings(const std::filesystem::path &path)
{
    std::ifstream file(path);
    if (!file.is_open())
    {
        return std::nullopt;
    }

    nlohmann::json parsed;
    try
    {
        file >> parsed;
    }
    catch (...)
    {
        return std::nullopt;
    }

    Settings settings = defaultSettings();

    if (parsed.contains("ignore") && parsed["ignore"].is_array())
    {
        settings.ignore.clear();
        for (const auto &entry : parsed["ignore"])
        {
            if (entry.is_string())
            {
                settings.ignore.push_back(entry.get<std::string>());
            }
        }
    }

    if (parsed.contains("delay") && parsed["delay"].is_number_unsigned())
    {
        settings.delay = parsed["delay"].get<std::uint64_t>();
    }

    if (parsed.contains("cmd") && parsed["cmd"].is_string())
    {
        settings.cmd = parsed["cmd"].get<std::string>();
    }

    if (parsed.contains("save_log") && parsed["save_log"].is_boolean())
    {
        settings.saveLog = parsed["save_log"].get<bool>();
    }

    if (parsed.contains("log_path") && parsed["log_path"].is_string())
    {
        settings.logPath = parsed["log_path"].get<std::string>();
    }

    return settings;
}
