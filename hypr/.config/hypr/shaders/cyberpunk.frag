#version 300 es
precision highp float;
in vec2 v_texcoord;
uniform sampler2D tex;
uniform float time;
layout(location = 0) out vec4 fragColor;

// ── ORIGINALS (always on) ───────────────────────────────────────────
const float CHROMA_AMOUNT         = 0.0010;
const float SCANLINE_INTENS       = 0.10;
const float SCANLINE_DENSITY      = 720.0;
const float VIGNETTE_AMOUNT       = 0.25;

// ── Feature gates (toggled by ~/.config/hypr/scripts/cyber-toggle.sh) ───
const bool GLITCH_ENABLED  = false;
const bool FLICKER_ENABLED = false;

// ── BURST nier-style: bucket + probability + envelope ──────────────────
const float BURST_BUCKET_SIZE     = 4.0;     // split time in bucket from N sec
const float BURST_PROBABILITY     = 0.35;    // % of bucket having a burst (35% = pretty rares)
const float BURST_DURATION        = 0.70;    // 700ms as nier
const float BURST_FULL_PROB       = 0.20;    // % of micro-tick that are full-screen

// Micro-zone: inside burst, the zone CHANGE rapidly (data corruption look)
const float MICRO_TICK_HZ         = 18.0;    // 18Hz = new zone every ~55ms
const float ZONE_W_MIN            = 0.12;
const float ZONE_W_MAX            = 0.45;
const float ZONE_H_MIN            = 0.10;
const float ZONE_H_MAX            = 0.40;

// Effects inside burst+zone
const float GLITCH_FREQ           = 0.40;
const float GLITCH_INTENSITY      = 0.020;
const float BAND_HEIGHT_MIN       = 0.001;   // 0.1% screen — thin bands
const float BAND_HEIGHT_MAX       = 0.050;   // 5%   screen — thick bands

const float SCANLINE_DRIFT_AMOUNT = 0.18;
const float FLICKER_INTENSITY     = 0.060;

// ── Pseudo-random hashes ────────────────────────────────────────────────
float hash11(float p) {
    p = fract(p * 0.1031);
    p *= p + 33.33;
    p *= p + p;
    return fract(p);
}

float hash21(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

void main() {
    vec2 uv = v_texcoord;

    // ── Burst window: scattered via bucket+probability ─────────────────────
    float bucket       = floor(time / BURST_BUCKET_SIZE);
    float bucketActive = step(1.0 - BURST_PROBABILITY, hash11(bucket + 5.0));

    // Burst start time random inside bucket
    float burstOffsetInBucket = hash11(bucket + 6.0) * (BURST_BUCKET_SIZE - BURST_DURATION);
    float burstStart   = bucket * BURST_BUCKET_SIZE + burstOffsetInBucket;

    float inBurstWin   = step(burstStart, time) * step(time, burstStart + BURST_DURATION);
    float burstActive  = bucketActive * inBurstWin;

    // Burst progress 0→1
    float burstProgress = clamp((time - burstStart) / BURST_DURATION, 0.0, 1.0);

    // Rapid envelope attack → hold → slow decay
    float envelope = smoothstep(0.0, 0.10, burstProgress) *
                     (1.0 - smoothstep(0.50, 1.0, burstProgress));
    float burstIntensity = burstActive * envelope;

    // ── Micro-zone that change at every tick (data corruption) ────────────
    float microTick = floor(time * MICRO_TICK_HZ);
    float fullScreen = step(1.0 - BURST_FULL_PROB, hash11(microTick + 17.3));

    float zoneW   = mix(ZONE_W_MIN, ZONE_W_MAX, hash11(microTick + 3.0));
    float zoneH   = mix(ZONE_H_MIN, ZONE_H_MAX, hash11(microTick + 4.0));
    float zoneCX  = hash11(microTick + 1.0);
    float zoneCY  = hash11(microTick + 2.0);
    float inZone  = step(zoneCX - zoneW*0.5, uv.x) * step(uv.x, zoneCX + zoneW*0.5) *
                    step(zoneCY - zoneH*0.5, uv.y) * step(uv.y, zoneCY + zoneH*0.5);
    float zoneMask = mix(inZone, 1.0, fullScreen);

    float burstZone = burstIntensity * zoneMask;

    // ── Glitch block displacement (bands height variable for microTick) ─
    // Decision strip = scale max. Every strip decide its own bandHeight randomly.
    float decisionStrip = floor(uv.y / BAND_HEIGHT_MAX);
    float heightRoll    = hash11(decisionStrip + microTick * 3.7);
    float bandHeight    = mix(BAND_HEIGHT_MIN, BAND_HEIGHT_MAX, heightRoll);

    float bandSeed    = floor(uv.y / bandHeight);
    float bandRoll    = hash21(vec2(bandSeed, microTick));
    float glitchOn    = GLITCH_ENABLED
                        ? step(1.0 - GLITCH_FREQ, bandRoll) * burstZone
                        : 0.0;
    float glitchShift = (hash21(vec2(bandSeed, microTick + 0.5)) - 0.5) * GLITCH_INTENSITY * glitchOn;

    vec2 sampleUv = vec2(uv.x + glitchShift, uv.y);

    // ── Chromatic aberration (ORIGINAL, always on) ────────────────
    float r = texture(tex, vec2(sampleUv.x - CHROMA_AMOUNT, sampleUv.y)).r;
    float g = texture(tex, sampleUv).g;
    float b = texture(tex, vec2(sampleUv.x + CHROMA_AMOUNT, sampleUv.y)).b;
    float a = texture(tex, sampleUv).a;
    vec3 col = vec3(r, g, b);

    // ── Glitched bands: cyan/magenta boost ─────────────────────────────
    if (glitchOn > 0.5) {
        float hue = hash11(bandSeed + microTick);
        col.r = mix(col.r, col.r * 1.25, hue);
        col.b = mix(col.b, col.b * 1.25, 1.0 - hue);
    }

    // ── Scanlines (ORIGINAL) + drift jump in areas ─────────────────────
    float driftedY = uv.y + burstZone * SCANLINE_DRIFT_AMOUNT * (hash11(microTick + 7.0) - 0.5);
    float scan = sin(driftedY * SCANLINE_DENSITY * 3.14159265) * 0.5 + 0.5;
    col *= 1.0 - SCANLINE_INTENS * (1.0 - scan);

    // ── Flicker in areas ────────────────────────────────────────────────
    float flicker = FLICKER_ENABLED
                    ? (hash11(floor(time * 60.0)) - 0.5) * FLICKER_INTENSITY * burstZone
                    : 0.0;
    col *= 1.0 + flicker;

    // ── Vignette (ORIGINAL) ───────────────────────────────────────────
    vec2 vd = uv - 0.5;
    float vig = 1.0 - dot(vd, vd) * VIGNETTE_AMOUNT * 4.0;
    col *= clamp(vig, 0.0, 1.0);

    fragColor = vec4(col, a);
}
