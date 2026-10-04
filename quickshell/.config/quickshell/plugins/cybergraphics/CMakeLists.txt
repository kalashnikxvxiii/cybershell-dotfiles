cmake_minimum_required(VERSION 3.20)
project(cybergraphics LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick Concurrent)

qt_add_qml_module(cybergraphics
    URI CyberGraphics
    VERSION 1.0
    PLUGIN_TARGET cybergraphics
    OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/CyberGraphics"
    SOURCES
        sparklineitem.hpp sparklineitem.cpp
        imageanalyser.hpp imageanalyser.cpp
)

target_link_libraries(cybergraphics PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::Concurrent
)

install(
    DIRECTORY "${CMAKE_BINARY_DIR}/CyberGraphics"
    DESTINATION "${CMAKE_INSTALL_PREFIX}/lib/qt6/qml"
)