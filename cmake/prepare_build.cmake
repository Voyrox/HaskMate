if(NOT DEFINED BUILD_DIR)
	message(FATAL_ERROR "BUILD_DIR is required")
endif()

if(NOT DEFINED SOURCE_DIR)
	message(FATAL_ERROR "SOURCE_DIR is required")
endif()

set(cache_file "${BUILD_DIR}/CMakeCache.txt")
if(NOT EXISTS "${cache_file}")
	return()
endif()

file(STRINGS "${cache_file}" cache_home_line REGEX "^CMAKE_HOME_DIRECTORY:INTERNAL=")
if(NOT cache_home_line)
	return()
endif()

string(REPLACE "CMAKE_HOME_DIRECTORY:INTERNAL=" "" cache_home "${cache_home_line}")
if(NOT cache_home STREQUAL SOURCE_DIR)
	file(REMOVE_RECURSE "${BUILD_DIR}")
endif()