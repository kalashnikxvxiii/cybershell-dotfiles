// AiPathChip.qml - one path attached to a prompt, at the top of its card.
//
// The extension's file chip: what the path is at a glance (a folder, a kind of
// file, or the picture itself for an image) and its name. A click opens it
// with the desktop's default application; the full path is in the composer's
// attach list and in what the model was sent, the chip only needs the name
import QtQuick
import Quickshell
import "../../common"
import "../../common/Colors.js" as CP

Item {
    id: root

    property string path: ""
    property real maxWidth: 200

    readonly property bool isDir: root.path.endsWith("/")
    readonly property string name: {
        const p = root.isDir ? root.path.slice(0, -1) : root.path
        return p.slice(p.lastIndexOf("/") + 1) + (root.isDir ? "/" : "")
    }
    readonly property string ext: {
        const i = root.name.lastIndexOf(".")
        return root.isDir || i <= 0 ? "" : root.name.slice(i + 1).toLowerCase()
    }
    readonly property bool isImage:
        ["png", "jpg", "jpeg", "webp", "gif", "bmp", "svg"].indexOf(root.ext) >= 0

    // Font Awesome's file family, by extension. Anything else is a plain page
    readonly property string glyph: root.isDir ? "\uf07b"
        : root.isImage ? "\uf1c5"
        : root.ext === "pdf" ? "\uf1c1"
        : ["zip", "tar", "gz", "xz", "zst", "7z", "rar"].indexOf(root.ext) >= 0 ? "\uf1c6"
        : ["mp3", "flac", "ogg", "wav", "opus", "m4a"].indexOf(root.ext) >= 0 ? "\uf1c7"
        : ["mp4", "mkv", "webm", "mov", "avi"].indexOf(root.ext) >= 0 ? "\uf1c8"
        : ["qml", "js", "py", "sh", "fish", "lua", "c", "cpp", "h", "hpp", "rs", "go",
            "ts", "json", "toml", "yaml", "yml", "css", "html"].indexOf(root.ext) >= 0 ? "\uf1c9"
        : "\uf0f6"
    readonly property color accent: root.isDir ? CP.yellow : CP.cyan
    readonly property color fg: "#d8e0e8"

    implicitWidth: Math.min(root.maxWidth, row.implicitWidth + 14)
    implicitHeight: 20
    width: implicitWidth
    height: implicitHeight

    CutShape {
        anchors.fill: parent
        fillColor: CP.alpha(root.accent, ma.containsMouse ? 0.14 : 0.06)
        strokeColor: CP.alpha(root.accent, ma.containsMouse ? 0.70 : 0.32)
        strokeWidth: 1
        inset: 0.5
        cutBottomLeft: 6
        Behavior on fillColor { ColorAnimation { duration: 120 } }
        Behavior on strokeColor { ColorAnimation { duration: 120 } }
    }

    Row {
        id: row
        x: 7
        anchors.verticalCenter: parent.verticalCenter
        spacing: 5

        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: 12
            height: 12

            Text {
                anchors.centerIn: parent
                visible: thumb.status !== Image.Ready
                text: root.glyph
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
                color: CP.alpha(root.accent, 0.85)
            }

            // An image previews itself, as small as the glyph it replaces
            Image {
                id: thumb
                anchors.fill: parent
                visible: status === Image.Ready
                source: root.isImage
                    ? "file://" + root.path.split("/").map(encodeURIComponent).join("/") : ""
                sourceSize: Qt.size(24, 24)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, root.maxWidth - 14 - 12 - row.spacing)
            text: root.name
            elide: Text.ElideMiddle
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 10
            color: ma.containsMouse ? root.accent : CP.alpha(root.fg, 0.82)
            Behavior on color { ColorAnimation { duration: 120 } }
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached(["xdg-open", root.path])
    }
}
