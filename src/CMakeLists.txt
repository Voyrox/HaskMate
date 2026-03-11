cmake_minimum_required(VERSION 3.16)

project(zippy_cpp VERSION 1.3.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

add_executable(zippy
    src/main.cpp
    src/commands.cpp
    src/generate.cpp
    src/logger.cpp
    src/settings.cpp
)

target_include_directories(zippy PRIVATE include library)
target_compile_options(zippy PRIVATE -Wall -Wextra -Wpedantic)

find_package(Threads REQUIRED)
target_link_libraries(zippy PRIVATE Threads::Threads)
