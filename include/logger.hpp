#pragma once

#include <filesystem>
#include <fstream>
#include <mutex>
#include <string>
#include <string_view>

enum class Level
{
  info,
  warn,
  err,
  success,
  debug,
};

class Logger
{
public:
  explicit Logger(std::string name = "zippy");
  ~Logger();

  Logger(const Logger &) = delete;
  Logger &operator=(const Logger &) = delete;

  void enableFileLogging(const std::filesystem::path &path);
  void deinit();
  void setColor(bool enabled);

  void info(const std::string &message);
  void warn(const std::string &message);
  void err(const std::string &message);
  void success(const std::string &message);
  void debug(const std::string &message);
  void writeRaw(std::string_view data);

private:
  void log(Level level, const std::string &message);
  static const char *levelTag(Level level);
  static const char *levelColor(Level level);
  static std::string formatTimestamp();

  std::string name_;
  bool useColor_;
  std::ofstream file_;
  std::filesystem::path logPath_;
  std::mutex mutex_;
};
