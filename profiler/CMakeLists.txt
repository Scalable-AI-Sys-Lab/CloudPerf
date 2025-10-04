# Minimum CMake version required
cmake_minimum_required(VERSION 3.10)

# Project name and C++ standard
project(ProfilerProject)
set(CMAKE_CXX_STANDARD 17)

# Find Python
find_package(Python3 REQUIRED COMPONENTS Development)

# Add the executable and link Python includes and libraries
add_executable(profiler profiler.cpp monitor.cpp)
target_include_directories(profiler PRIVATE ${Python3_INCLUDE_DIRS})
target_link_libraries(profiler PRIVATE ${Python3_LIBRARIES} pthread)
