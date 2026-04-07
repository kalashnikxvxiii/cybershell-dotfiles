// Audio.qml — Audio singleton: CavaProvider (FFT) + BeatTracker (BPM)
// Powered by the CyberAudio C++ plugin (PipeWire + libcava + aubio).
//
// Usage from modules:
//   import ".." (from bar/ or dashboard/)
//   Audio.cava.values[i]      → float 0-1 per FFT bar
//   Audio.cava.bars           → number of configured bars (120)
//   Audio.beatTracker.bpm     → current BPM (Aubio)
//   Audio.beatTracker.beat    → signal fired on every beat

pragma Singleton

import QtQuick
import CyberAudio.Services

QtObject {
    id: root

    // CavaProvider: audio FFT with built-in Monstercat smoothing
    property CavaProvider cava: CavaProvider {
        bars: 120
    }

    // BeatTracker: BPM detection via Aubio (handy for syncing animations to the beat)
    property BeatTracker beatTracker: BeatTracker {}
}
