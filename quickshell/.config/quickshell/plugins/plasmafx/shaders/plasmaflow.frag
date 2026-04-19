#version 440

layout(location = 0) in vec2 v_uv;
layout(location = 0) out vec4 fragColor;

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

// ── Noise ────────────────────────────────────────
vec3 mod289v3(vec3 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec2 mod289v2(vec2 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec3 permute(vec3 x) { return mod289v3(((x * 34.0) + 1.0) * x); }

float snoise(vec2 v) {
    const vec4 C = vec4(0.211324865405187, 0.366025403784439,
                        -0.577350269189626, 0.024390243902439);
    vec2 i = floor(v + dot(v, C.yy));
    vec2 x0 = v - i + dot(i, C.xx);
    vec2 i1 = (x0.x > x0.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
    vec4 x12 = x0.xyxy + C.xxzz;
    x12.xy -= i1;
    i = mod289v2(i);
    vec3 p = permute(permute(i.y + vec3(0.0, i1.y, 1.0))
                            + i.x + vec3(0.0, i1.x, 1.0));
    vec3 m = max(0.5 - vec3(dot(x0, x0), dot(x12.xy, x12.xy),
                            dot(x12.zw, x12.zw)), 0.0);
    m = m * m;
    m = m * m;
    vec3 x = 2.0 * fract(p * C.www) - 1.0;
    vec3 h = abs(x) - 0.5;
    vec3 ox = floor(x + 0.5);
    vec3 a0 = x - ox;
    m *= 1.79284291400159 - 0.85373472095314 * (a0 * a0 + h * h);
    vec3 g;
    g.x = a0.x * x0.x + h.x * x0.y;
    g.yz = a0.yz * x12.xz + h.yz * x12.yw;
    return 130.0 * dot(m, g);
}

float hash(float n) { return fract(sin(n) * 43758.5453); }

float fbm(vec2 p, float t) {
    float f = 0.0, w = 0.5;
    for (int i = 0; i < 4; i++) {
        f += w * snoise(p);
        p *= 2.1;
        p += vec2(t * 0.15, -t * 0.12);
        w *= 0.5;
    }
    return f;
}

// ── SDF helpers ──────────────────────────────────
float sdCircle(vec2 p, float r) { return length(p) - r; }

float sdSegment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

// Inverse-distance glow: 1/d with controllable intensity
float glow(float d, float falloff, float radius) {
    return exp(-pow(d / radius, falloff));
}

void main() {
    vec2 uv = vec2(v_uv.x, 1.0 - v_uv.y); // y=0 bottom, y=1 top
    float t = u_time;
    float ar = u_resolution.x / u_resolution.y;
    vec2 p = (uv - 0.5) * vec2(ar, 1.0); // aspect-corrected, centered

    float pwr = u_power;
    float flowSpeed = mix(0.3, 1.8, smoothstep(0.0, 1.0, pwr));

    // ── Ring parameters ──────────────────────────
    float ringR = 0.14;
    vec2 ringCenter = vec2(0.0, 0.03); // slightly above center in p-space
    vec2 toRing = p - ringCenter;
    float ringDist = length(toRing);
    float ringAngle = atan(toRing.y, toRing.x);

    // Nucleus boprder: cartesian noise cloud
    float borderNoise = snoise(vec2(toRing.x * 18.0 + t * 0.5, toRing.y * 18.0 - t * 0.3)) * 0.015
                        + snoise(vec2(toRing.x * 30.0 - t * 0.4, toRing.y * 25.0 + t * 0.6)) * 0.008;
    borderNoise *= pwr;
    float dNucleus = max(ringDist - ringR - borderNoise, 0.0);

    // Nucleus glow: solid fill that fader outward from edge
    float ringCoreForPulse = glow(dNucleus, 2.0, 0.01);

    // nucleus pulse: radial breathing
    float ringPulse = sin(t * flowSpeed * 2.0) * 0.3 + 0.7;
    ringPulse *= smoothstep(ringR, ringR * 0.5, ringDist) * 0.3 * pwr;

    // Entry splash
    float entryAngleDiff = abs(ringAngle + 1.5708); // distance from -PI/2
    entryAngleDiff = min(entryAngleDiff, 6.28318 - entryAngleDiff);
    float entrySplash = glow(entryAngleDiff, 2.5, 0.6)
                      * glow(dNucleus, 2.0, 0.015) * mix(0.5, 2.0, pwr);

    // Inner fill: cloud-like accumulation from energy flow
    float cloudN1 = snoise(vec2(toRing.x * 10.0 + t * 0.3, toRing.y * 10.0 - t * 0.4)) * 0.5 + 0.5;
    float cloudN2 = snoise(vec2(toRing.x * 20.0 - t * 0.2, toRing.y * 15.0 + t * 0.5)) * 0.5 + 0.5;
    float cloud = cloudN1 * 0.6 + cloudN2 * 0.4;
    float innerFill = smoothstep(ringR * 1.1, ringR * 0.3, ringDist);
    innerFill *= cloud * smoothstep(0.15, 0.4, pwr) * pwr * 0.6;

    // ── Beam (bottom edge to ring) ───────────────
    vec2 beamTop = ringCenter + vec2(0.0, -ringR * 1.01); // bottom of ring
    vec2 beamBot = vec2(0.0, -0.5 / 1.0);          // bottom of card

    // Beam wobble with FBM
    float beamWobble = fbm(vec2(uv.y * 4.0, t * flowSpeed), t * 0.3) * mix(0.005, 0.015, pwr);

    // SDF distance to beam center line (with wobble)
    vec2 beamP = p - vec2(beamWobble, 0.0);
    float dBeam = sdSegment(beamP, beamBot, beamTop);

    // Hourglass shape
    float beamT = clamp((beamP.y - beamBot.y) / (beamTop.y - beamBot.y), 0.0, 1.0);
    float hourglassWidth = mix(0.08, 0.010, smoothstep(0.0, 0.5, beamT));
    // Fade to zero near nucleus instead od widening
    hourglassWidth *= smoothstep(1.0, 0.75, beamT);
    dBeam = max(dBeam - hourglassWidth, 0.0);
    float beamLengthFade = 1.0 - smoothstep(0.82, 1.0, beamT);

    // Beam: multi-layer glow
    float beamCoreForPulse = glow(dBeam, 4.0, 0.005);

    // Energy pulses traveling up the beam
    float pulseY = uv.y;
    float pulse1 = sin((pulseY * 15.0 + t * flowSpeed * 4.0)) * 0.5 + 0.5;
    pulse1 = pow(pulse1, 8.0); // sharp peaks
    float pulse2 = sin((pulseY * 22.0 + t * flowSpeed * 6.0 + 1.7)) * 0.5 + 0.5;
    pulse2 = pow(pulse2, 10.0);
    float pulses = (pulse1 * 0.4 + pulse2 * 0.3) * beamCoreForPulse;

    // Beam noise modulation (organic brightness variation)
    float beamNoiseVal = snoise(vec2(0.0, uv.y * 5.0 + t * flowSpeed * 2.0)) * 0.15 + 0.85;

    // Bottom entry glow (bright spot at card bottom)
    float bottomDist = length(p - beamBot);
    float entryGlow = glow(bottomDist, 2.0, 0.12) * 0.3;

    // ── Particles: bubbling from beam/ring surface ────────────────
    float particles = 0.0;
    float particleVis = mix(0.4, 1.0, smoothstep(0.0, 1.0, pwr));      // more visible at high power
    float particleSpeed = 1.0;

    for (int i = 0; i < 80; i++) {
        float fi = float(i);
        float life = hash(fi * 3.7 + 0.1);
        if (life > particleVis) continue;       // fewer particles at low power

        // Staggered birth cicle - each particle has its own rhythm
        float cycleSpeed = (0.015 + hash(fi * 4.1) * 0.4) * particleSpeed;
        float lifeT = fract(t * cycleSpeed + hash(fi * 7.1));

        // Bubble: slow start (clinging to surface), then accelerate outward
        float bubbleT = 1.0 - pow(1.0 - lifeT, 2.0);
        float alive = smoothstep(0.0, 0.05, lifeT) * smoothstep(1.0, 0.3, lifeT);
        if (alive < 0.01) continue;

        // Spawn position and fly direction
        float spawnX, spawnY, flyAngle;
        float ringY = ringCenter.y;
        float zone = hash(fi * 13.3);       // 0..1 determines beam vs ring

        if (zone < 0.4) {
            // Spawn on ring circumnference
            float rAngle = hash(fi * 9.3) * 6.28318;
            spawnX = ringCenter.x + cos(rAngle) * (ringR + 0.03) / ar;
            spawnY = ringCenter.y + sin(rAngle) * (ringR + 0.03);
            flyAngle = rAngle + (hash(fi * 14.1) - 0.5) * 0.6;      // mostly radial, slight spread
        } else {
            // Spawn on beam edge
            float side = (hash(fi * 6.1) > 0.5) ? 1.0 : -1.0;
            spawnY = beamBot.y + hash(fi * 11.3) * (beamTop.y - beamBot.y);
            float beamLocalT = (spawnY - beamBot.y) / (beamTop.y - beamBot.y);
            float localWidth = mix(0.04, 0.005, smoothstep(0.0, 0.5, clamp(beamLocalT, 0.0, 1.0)))
                            + mix(0.0, 0.015, smoothstep(0.5, 1.0, clamp(beamLocalT, 0.0, 1.0)));
            spawnX = side * (localWidth + 0.03) / ar;
            flyAngle = side > 0.0 ? 0.0 : 3.14159;      // fly left or right
            flyAngle += (hash(fi * 12.7) - 0.5) * 0.8;  // spread angle
        }

        // Bubble trajectory: accelerating outward
        float flyDist = bubbleT * mix(0.15, 0.45, pwr) * (0.4 + hash(fi * 8.3) * 0.6);

        // Slight wobble during flight (bubble jitter)
        float wobX = sin(lifeT * 12.0 + fi * 3.0) * 0.008 * alive;
        float wobY = cos(lifeT * 9.0 + fi * 5.0) * 0.005 * alive;

        float px = spawnX + cos(flyAngle) * flyDist / ar + wobX;
        float py = spawnY + sin(flyAngle) * flyDist * 0.6 + lifeT * 0.02 + wobY;       // slight upward drift

        float dist = length(p - vec2(px, py));

        // Variable size: born small. grow slightly, shrink before death
        float sizeBase = 0.001 + hash(fi * 2.3) * 0.004;
        float sizeLife = smoothstep(0.0, 0.2, lifeT) * smoothstep(1.0, 0.5, lifeT);
        float size = sizeBase * sizeLife;

        float spark = glow (dist, 3.0, size) * alive;

        particles += spark * 0.3;
    }

    // ── Composite ────────────────────────────────────────────────────────
    float beamI = (1.0 / (1.0 + dBeam * dBeam * 625.0)) * beamLengthFade;
    beamI += pulses * 0.3 * beamLengthFade;
    beamI += entryGlow;

    // Nucleus: activated only when beam reaches it, organic fill center → edge
    float beamReachesNucleus = smoothstep(0.38, 0.50, pwr);

    float fillRatio = clamp((pwr - 0.40) / 0.38, 0.0, 1.0);
    float fillAngle = atan(toRing.y, toRing.x);
    float angNoise  = snoise(vec2(cos(fillAngle) * 4.0 + t * 0.30, sin(fillAngle) * 4.0 - t * 0.25)) * 0.12 * fillRatio
                    + snoise(vec2(cos(fillAngle) * 9.0 - t * 0.50, sin(fillAngle) * 9.0 + t * 0.40)) * 0.05 * fillRatio;
    float fillR     = clamp(ringR * (fillRatio + angNoise), 0.001, ringR * 1.05);

    float insideDisk = (1.0 - smoothstep(-0.01, 0.02, ringDist - fillR)) * beamReachesNucleus;

    // Hot gaussian core at center, rotating crossed spokes inside
    float coreGlow = exp(-ringDist * ringDist * 110.0);
    float tendrils  = pow(max(0.0, sin(fillAngle * 5.0 + t * 2.5)), 4.0)
                    * pow(max(0.0, sin(fillAngle * 3.0 - t * 1.8 + 0.7)), 3.0);
    float tendMask  = smoothstep(fillR + 0.01, max(fillR * 0.15, 0.001), ringDist) * insideDisk;

    float nucleusI  = insideDisk * (coreGlow * 0.8 + cloud * 0.35 + tendrils * tendMask * 0.5) * pwr;

    // Glowing ring that tracks the expanding fill front
    float fillFrontGlow = exp(-pow(abs(ringDist - fillR) / 0.008, 2.0)) * beamReachesNucleus * pwr;
    // Outer rim at ringR: appears only when fill is nearly complete
    float nucleusEdge = exp(-pow(abs(ringDist - ringR) / 0.006, 2.0))
                      * beamReachesNucleus * pwr * smoothstep(0.6, 1.0, fillRatio);
    float entryFlash  = glow(length(p - (ringCenter + vec2(0.0, -ringR))), 2.0, 0.03)
                      * beamReachesNucleus * pwr * 1.8;

    ringPulse *= beamReachesNucleus;
    float ringI = nucleusI + nucleusEdge + fillFrontGlow + entryFlash + ringPulse * 0.4;

    // Beam grows bottom → top: lower pixels reach full intensity first
    float heightT = clamp((p.y - beamBot.y) / (ringCenter.y - beamBot.y), 0.0, 1.0);
    float growPwr = smoothstep(heightT * 0.6, heightT * 0.6 + 0.3, pwr);
    float beamPwr = mix(growPwr, pwr, 0.3);
    float total = (beamI * beamPwr + ringI + particles) * (pwr * 1.0 + 0.08);

    // ── Color: single smooth ramp from distance ────────────────────────────────
    float i2 = clamp(total, 0.0, 1.5);

    // Normalize to 0..1 for color mapping
    float colorT = clamp(i2 / 1.2, 0.0, 1.0);

    // Smooth gradient: dark -> glowColor -> baseColor -> white
    // Using a single chain of mix with smooth colorT
    vec3 darkToGlow = mix(vec3(0.0), u_glowColor * 0.5, smoothstep(0.0, 0.3, colorT));
    vec3 glowToBase = mix(darkToGlow, u_baseColor, smoothstep(0.15, 0.6, colorT));
    
    // Lightning network: veins grow asynchronously along their paths

    float spineWobble = snoise(vec2(3.0, uv.y * 6.0)) * 0.02;
    float distFromSpine = abs(uv.x - 0.5 - spineWobble);

    // Central spine - always present
    float spine = smoothstep(0.01, 0.0, distFromSpine);

    float veins = spine * 0.9;
    float tipGlowTotal = 0.0;

    // Each vein layer has its own growth clock
    // Growth travels along Y axis within the vein shape

    // --- Primary veins (4 independent branches) ---
    for (int i = 0; i < 4; i++) {
        float fi = float(i);

        // Each Branch has unique timing
        float branchSpeed = 0.12 + hash(fi * 7.3) * 0.08;
        float branchDelay = hash(fi * 13.1) * 3.0;            // staggered start
        float branchT = fract((t * flowSpeed * branchSpeed) + branchDelay);

        // Growth easing: fast burst then decelerate
        float growEased = 1.0 - pow(1.0 - branchT, 4.0);

        // This branch's noise field
        float seedX = hash(fi * 3.7) * 30.0;
        float seedY = hash(fi * 9.1) * 20.0;
        float freq = 12.0 + fi * 4.0;
        vec2 c1 = vec2((uv.x - 0.5) * freq + seedX, uv.y * (freq * 0.8) + seedY);
        c1 += snoise(floor(c1 * 3.0) * 0.7) * 0.4;
        float r = 1.0 - abs(snoise(c1));
        r = pow(r, 8.0 + fi * 2.0);

        //Growth mask: reveal along Y from a random start height
        float startY = hash(fi * 5.3) * 0.6 + 0.15;
        float growDir = (hash(fi * 11.7) > 0.5) ? 1.0 : -1.0;
        float growLen = 0.3 + hash(fi * 8.3) * 0.4;
        float growTip = startY + growDir * growEased * growLen;

        float growMask;
        if (growDir > 0.0) {
            growMask = smoothstep(growTip, growTip - 0.04, uv.y) * step(startY, uv.y);
        } else {
            growMask = smoothstep(growTip, growTip + 0.04, uv.y) * step(uv.y, startY);
        }

        // Also require proximity to spine (veins grow outward)
        float spineGrow = smoothstep(growEased * 0.3, growEased * 0.3 - 0.02, distFromSpine);
        growMask *= spineGrow;

        // Tip glow at the growth front
        float tipDist = abs(uv.y -  growTip);
        float tipGlow = smoothstep(0.04, 0.0, tipDist) * r * 0.6 * spineGrow;
        tipGlowTotal += tipGlow;

        // Fade: vein holds then dissolves
        float holdFade = smoothstep(1.0, 0.75, branchT);

        veins += r * growMask * holdFade * (0.5 + fi * 0.1);
    }

    // --- Secondary veins (6 finer branches, delayed) ---
    for (int i = 0; i < 6; i++) {
        float fi = float(i) + 4.0;      // offset seed from primary

        float branchSpeed = 0.08 + hash(fi * 6.1) * 0.06;
        float branchDelay = hash(fi * 14.3) * 4.0 + 0.5;        // start after primaries
        float branchT = fract((t * flowSpeed * branchSpeed) + branchDelay);
        float growEased = 1.0 - pow(1.0 - branchT, 3.0);

        float seedX = hash(fi * 4.7) * 40.0;
        float seedY = hash(fi * 10.3) * 30.0;
        float freq = 22.0 + fi * 5.0;
        vec2 c2 = vec2((uv.x - 0.5) * freq + seedX, uv.y * (freq * 0.7) + seedY);
        c2 += snoise(floor(c2 * 3.0) * 0.7) * 0.4;
        float r = 1.0 - abs(snoise(c2));
        r = pow(r, 11.0 + fi);

        float startY = hash(fi * 6.7) * 0.7 + 0.1;
        float growDir = (hash(fi * 12.9) > 0.5) ? 1.0 : -1.0;
        float growLen = 0.2 + hash(fi * 9.7) * 0.3;
        float growTip = startY + growDir * growEased * growLen;

        float growMask;
        if (growDir > 0.0) {
            growMask = smoothstep(growTip, growTip - 0.03, uv.y) * step(startY, uv.y);
        } else {
            growMask = smoothstep(growTip, growTip + 0.03, uv.y) * step(uv.y, startY);
        }

        float spineGrow = smoothstep(growEased * 0.25, growEased * 0.25, distFromSpine);
        growMask *= spineGrow;

        float tipDist = abs(uv.y - growTip);
        tipGlowTotal += smoothstep(0.03, 0.0, tipDist) * r * 0.4 * spineGrow;

        float holdFade = smoothstep(1.0, 0.7, branchT);

        veins += r * growMask * holdFade * 0.4;
    }

    // --- Hair-thin cracks (8, very delayed, fast) ---
    for (int i = 0; i < 8; i++) {
        float fi = float(i) + 10.0;

        float branchSpeed = 0.15 + hash(fi * 5.3) * 0.1;
        float branchDelay = hash(fi * 15.7) * 5.0 + 1.0;
        float branchT = fract((t * flowSpeed * branchSpeed) + branchDelay);
        float growEased = 1.0 - pow(1.0 - branchT, 2.0);

        float seedX = hash(fi * 5.9) * 50.0;
        float seedY = hash(fi * 11.7) * 40.0;
        float freq = 40.0 + fi * 6.0;
        vec2 c3 = vec2((uv.x - 0.5) * freq + seedX, uv.y * (freq * 0.6) + seedY);
        c3 += snoise(floor(c3 * 3.0) * 0.7) * 0.4;
        float r = 1.0 - abs(snoise(c3));
        r = pow(r, 14.0);

        float startY = hash(fi * 7.9) * 0.8 + 0.05;
        float growDir = (hash(fi * 13.3) > 0.5) ? 1.0 : -1.0;
        float growLen = 0.1 + hash(fi * 10.9) * 0.2;
        float growTip = startY + growDir * growEased * growLen;

        float growMask;
        if (growDir > 0.0) {
            growMask = smoothstep(growTip, growTip - 0.02, uv.y) * step(startY, uv.y);
        } else {
            growMask = smoothstep(growTip, growTip + 0.02, uv.y) * step(uv.y, startY);
        }

        float spineGrow = smoothstep(growEased * 0.2, growEased * 0.2 - 0.015, distFromSpine);
        growMask *= spineGrow;

        float holdFade = smoothstep(1.0, 0.6, branchT);

        veins += r * growMask * holdFade * 0.2;
    }

    veins += tipGlowTotal;

    // Coverage
    float centerFocus = 1.0 - smoothstep(0.0, 0.4, distFromSpine);
    veins *= centerFocus;

    float lightning = clamp(veins, 0.0, 1.0);
    
    // Light pulses traveling UP through the static pattern (opacity reveals it)
    float lp1 = pow(sin(uv.y * 8.0 - t * flowSpeed * 3.0) * 0.5 + 0.5, 4.0);
    float lp2 = pow(sin(uv.y * 12.0 - t * flowSpeed * 5.0 + 1.5) * 0.5 + 0.5, 6.0);
    float lp3 = pow(sin(uv.y * 20.0 - t * flowSpeed * 4.0 + 3.0) * 0.5 + 0.5, 8.0);
    float lightPulse = 0.15 + lp1 * 0.35 + lp2 * 0.3 + lp3 * 0.2;

    // Apply only inside the flow
    float veinMask = smoothstep(0.4, 0.7, colorT);
    vec3 brightColor = u_baseColor * 2.5 + vec3(0.2);       // bright green, not white
    float veinIntensity = lightning * lightPulse * veinMask;
    vec3 col = glowToBase + brightColor * veinIntensity * 0.7;

    // Multiply by intensity for brightness
    col *= (0.5 + i2 * 1.0);

    float alpha = clamp(i2 * 2.0, 0.0, 1.0);

    fragColor = vec4(col, alpha);
}
