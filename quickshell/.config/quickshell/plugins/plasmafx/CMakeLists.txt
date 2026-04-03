cmake_minimum_required(VERSION 3.20)
project(plasmafx LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Qml Quick ShaderTools)

qt_add_qml_module(plasmafx
    URI PlasmaFX
    VERSION 1.0
    PLUGIN_TARGET plasmafx
    OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/PlasmaFX"
    SOURCES
        plasmaflowitem.hpp plasmaflowitem.cpp
        plasmaflowmaterial.hpp plasmaflowmaterial.cpp
)

qt6_add_shaders(plasmafx "plasmafx_shaders"
    BATCHABLE
    PREFIX "/PlasmaFX"
    FILES
        shaders/plasmaflow.vert
        shaders/plasmaflow.frag
)

target_link_libraries(plasmafx PRIVATE
    Qt6::Core
    Qt6::Qml
    Qt6::Quick
)

install(
    DIRECTORY "${CMAKE_BINARY_DIR}/PlasmaFX"
    DESTINATION "${CMAKE_INSTALL_PREFIX}/lib/qt6/qml"
)