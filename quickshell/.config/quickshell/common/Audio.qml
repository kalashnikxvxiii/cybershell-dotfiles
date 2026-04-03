// Audio.qml — Singleton audio: CavaProvider (FFT) + BeatTracker (BPM)
// Usa il plugin C++ CyberAudio (PipeWire + libcava + aubio).
//
// Uso nei moduli:
//   import ".." (da bar/ o dashboard/)
//   Audio.cava.values[i]      → float 0-1 per ogni barra FFT
//   Audio.cava.bars           → numero di barre configurate (120)
//   Audio.beatTracker.bpm     → BPM corrente (Aubio)
//   Audio.beatTracker.beat    → signal emesso ad ogni beat

pragma Singleton

import QtQuick
import CyberAudio.Services

QtObject {
    id: root

    // CavaProvider: FFT audio con Monstercat smoothing integrato
    property CavaProvider cava: CavaProvider {
        bars: 120
    }

    // BeatTracker: rilevamento BPM via Aubio (utile per sincronizzare animazioni)
    property BeatTracker beatTracker: BeatTracker {}
}
