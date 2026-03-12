cmake_minimum_required(VERSION 3.16)

project(zippy VERSION 1.3.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

set(ZIPPY_SOURCE_DIR src)
set(ZIPPY_INCLUDE_DIR include)
set(ZIPPY_LIBRARY_DIR library)

add_executable(zippy
    ${ZIPPY_SOURCE_DIR}/main.cpp
    ${ZIPPY_SOURCE_DIR}/commands.cpp
    ${ZIPPY_SOURCE_DIR}/generate.cpp
    ${ZIPPY_SOURCE_DIR}/logger.cpp
    ${ZIPPY_SOURCE_DIR}/settings.cpp
)

target_include_directories(zippy PRIVATE ${ZIPPY_INCLUDE_DIR} ${ZIPPY_LIBRARY_DIR})
target_compile_options(zippy PRIVATE -Wall -Wextra -Wpedantic)

find_package(Threads REQUIRED)
target_link_libraries(zippy PRIVATE Threads::Threads)
