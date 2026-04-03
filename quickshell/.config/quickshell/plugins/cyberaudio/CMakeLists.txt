cmake_minimum_required(VERSION 3.20)
project(cyberaudio LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Qml Quick)
find_package(PkgConfig REQUIRED)

pkg_check_modules(Pipewire IMPORTED_TARGET libpipewire-0.3 REQUIRED)
pkg_check_modules(Aubio IMPORTED_TARGET aubio REQUIRED)
pkg_check_modules(Cava IMPORTED_TARGET libcava QUIET)
if(NOT Cava_FOUND)
    pkg_check_modules(Cava IMPORTED_TARGET cava REQUIRED)
endif()

qt_add_qml_module(cyberaudio
    URI CyberAudio.Services
    VERSION 1.0
    PLUGIN_TARGET cyberaudio
    OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/CyberAudio/Services"
    SOURCES
        service.hpp service.cpp
        serviceref.hpp serviceref.cpp
        audiocollector.hpp audiocollector.cpp
        audioprovider.hpp audioprovider.cpp
        cavaprovider.hpp cavaprovider.cpp
        beattracker.hpp beattracker.cpp
)

target_link_libraries(cyberaudio PRIVATE
    Qt6::Core
    Qt6::Qml
    Qt6::Quick
    PkgConfig::Pipewire
    PkgConfig::Aubio
    PkgConfig::Cava
)

# Install to QuickShell's QML import path
install(
    DIRECTORY "${CMAKE_BINARY_DIR}/CyberAudio"
    DESTINATION "${CMAKE_INSTALL_PREFIX}/lib/qt6/qml"
)
