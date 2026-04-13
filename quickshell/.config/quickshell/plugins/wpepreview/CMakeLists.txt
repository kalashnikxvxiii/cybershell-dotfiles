cmake_minimum_required(VERSION 3.20)
project(wpepreview LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Qml Quick)

qt_add_qml_module(wpepreview
    URI WpePreview
    VERSION 1.0
    PLUGIN_TARGET wpepreview
    OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/WpePreview"
    SOURCES
        wpepreviewitem.hpp wpepreviewitem.cpp
)

target_link_libraries(wpepreview PRIVATE
    Qt6::Core
    Qt6::Qml
    Qt6::Quick
)

install(
    DIRECTORY "${CMAKE_BINARY_DIR}/WpePreview"
    DESTINATION "${CMAKE_INSTALL_PREFIX}/lib/qt6/qml"
)
