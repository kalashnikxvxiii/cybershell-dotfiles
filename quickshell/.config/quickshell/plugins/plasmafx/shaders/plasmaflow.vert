#version 440

layout(location = 0) in vec4 qt_VertexPosition;
layout(location = 1) in vec2 qt_VertexTexCoord;

layout(location = 0) out vec2 v_uv;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float u_time;
    float u_power;
    vec2 u_resolution;
    vec3 u_baseColor;
    float _pad0;
    vec3 u_glowColor;
    float _pad1;
};

void main() {
    v_uv = qt_VertexTexCoord;
    gl_Position = qt_Matrix * qt_VertexPosition;
}