cmake_minimum_required(VERSION 3.22.1)
project(n64host)

add_library(n64host SHARED n64host.c)

find_library(log-lib log)
find_library(egl-lib EGL)
find_library(gles-lib GLESv3)

target_link_libraries(n64host ${log-lib} ${egl-lib} ${gles-lib})
