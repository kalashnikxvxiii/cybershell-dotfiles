// Anim.qml — Animazione numerica standard
//
// Usare come sostituzione compatta di NumberAnimation nei Behavior e Transition.
//
// Design guide CP2077:
//   Panel slide-in:  150–200ms OutQuart  (decelerazione rapida, snappy)
//   Panel slide-out: 100–130ms InQuart   (accelerazione, sparisce veloce)
//   Valori data:     0ms                  (aggiornamento istantaneo — no tween su numeri live)
//   Colori:          300ms InOutQuad      (usa CAnim per questo)
//
// Easing.OutQuart → decelerazione più marcata di OutCubic:
//   macchine si fermano di scatto, non scorrono morbidamente.
//
// Override inline:
//   Anim { duration: 400 }
//   Anim { duration: 260; easing.type: Easing.InCubic }
//   Anim { target: root; property: "implicitHeight"; duration: 260 }

import QtQuick

NumberAnimation {
    duration:    200
    easing.type: Easing.OutQuart
}
