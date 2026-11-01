// BowEffect.qml -- a layer.effect that curves an item like the inside of a visor: its top and
// bottom edges come in towards the middle by `amount` px. Only the picture bends: clicks still
// land on the flat item, so keep `amount` small.
import QtQuick

ShaderEffect {
    property real amount: 0
    mesh: GridMesh { resolution: Qt.size(40, 1) }
    vertexShader: "../../shaders/bow.vert.qsb"
    fragmentShader: "../../shaders/bow.frag.qsb"
}
