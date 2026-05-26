#version 300 es
precision highp float;
in vec2 v_texcoord;
uniform sampler2D tex;
layout(location = 0) out vec4 fragColor;

// ── Tweak here ────────────────────
const float CHROMA_AMOUNT       = 0.0010;   // chromatic aberration (0 = off, 0.003 = marked)
const float SCANLINE_INTENS     = 0.10;     // scanline intensity (90 = off, 0.2 = aggressive)
const float SCANLINE_DENSITY    = 720.0;    // # of scanlines on the screen's height
const float VIGNETTE_AMOUNT     = 0.25;     // vignette on borders (0 = off)

void main() {
    vec2 uv = v_texcoord;

    // ── Chromatic aberration: R shifted <-. B shifted -> ────────
    float r = texture(tex, vec2(uv.x - CHROMA_AMOUNT, uv.y)).r;
    float g = texture(tex, uv).g;
    float b = texture(tex, vec2(uv.x + CHROMA_AMOUNT, uv.y)).b;
    float a = texture(tex, uv).a;
    vec3 col = vec3(r, g, b);

    // ── Scanline stats (no `time` -> damage tracking stay on)
    float scan = sin(uv.y * SCANLINE_DENSITY * 3.14159265) * 0.5 + 0.5;
    col *= 1.0 - SCANLINE_INTENS * (1.0 - scan);

    // ── Vignette: radial dim from borders ─────────────────
    vec2 vd = uv - 0.5;
    float vig = 1.0 - dot(vd, vd) * VIGNETTE_AMOUNT * 4.0;
    col *= clamp(vig, 0.0, 1.0);

    fragColor = vec4(col, a);
}