// CAnim.qml — Animazione colore standard
//
// Usare nei Behavior on color {} per transizioni colore morbide.
//
// Design guide CP2077:
//   Transizioni colore:  ~120ms — accettabili come smooth (non è un numero live)
//   Per stati urgenti/critici: usa duration più corta (60–80ms) override inline.
//   Per fade ambient (glow pulse): usa NumberAnimation su opacity invece di ColorAnimation.
//
// Override inline:
//   CAnim { duration: 80 }   — stati urgenti, più snappy
//   CAnim { duration: 200 }  — fade più graduale (ambient)

import QtQuick

ColorAnimation {
    duration: 120
}
