// DarkHalo.qml -- a faint dark halo around whatever it wraps, as a layer.effect: lifts
// HUD elements off saturated wallpapers, without a background or a drawn outline.
import QtQuick.Effects

MultiEffect {
    shadowEnabled: true
    shadowColor: "#00060e"
    shadowBlur: 0.6
    blurMax: 12
    shadowOpacity: 0.65
    shadowHorizontalOffset: 0
    shadowVerticalOffset: 0
    autoPaddingEnabled: true
}
