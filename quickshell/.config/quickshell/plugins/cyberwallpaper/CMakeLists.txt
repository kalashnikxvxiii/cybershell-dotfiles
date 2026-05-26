cmake_minimum_required(VERSION 3.20)
project(cyberwallpaper LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Qml Quick)

qt_add_qml_module(cyberwallpaper
    URI CyberWallpaper
    VERSION 1.0
    PLUGIN_TARGET cyberwallpaper
    OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/CyberWallpaper"
    SOURCES
        wallpaperlayer.hpp wallpaperlayer.cpp
)

target_link_libraries(cyberwallpaper PRIVATE
    Qt6::Core
    Qt6::Qml
    Qt6::Quick
)

install(
    DIRECTORY "${CMAKE_BINARY_DIR}/CyberWallpaper"
    DESTINATION "lib/qt6/qml"
)
