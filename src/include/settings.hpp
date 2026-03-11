#pragma once

#include <cstdint>
#include <filesystem>
#include <optional>
#include <string>
#include <vector>

struct Settings
{
    std::vector<std::string> ignore;
    std::optional<std::uint64_t> delay;
    std::string cmd;
    bool saveLog;
    std::string logPath;
};

inline constexpr std::uint64_t defaultDelayUs = 1'000'000;
inline constexpr bool defaultSaveLog = false;
inline constexpr const char *defaultLogPath = "zippy.log";

Settings defaultSettings();
std::optional<Settings> loadSettings(const std::filesystem::path &path);
