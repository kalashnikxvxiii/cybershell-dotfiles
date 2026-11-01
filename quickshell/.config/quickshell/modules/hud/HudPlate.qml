// HudPlate.qml -- content drawn flat at twice the size, so that once tilted as one
// texture the filtering smooths every edge. Keep the content 2px inside: what touches
// the texture's border stays jagged.
import QtQuick

Item {
    layer.enabled: true
    layer.smooth: true
    layer.textureSize: Qt.size(width * 2, height * 2)
}
