import "../../common/Colors.js" as CP
import "../../common"
import QtQuick
import WpePreview 1.0

Item {
    id: root

    required property string source
    required property string title
    required property string thumb
    required property string type
    required property string path
    required property int    entryInterval
    required property int    index

    property bool   _previewPlaying:    false
    property var    wallpaperModel:     null

    readonly property string    _resolvedTitle: {
        if (wallpaperModel) {
            for (var i = 0; i < wallpaperModel.count; i++)
                if (wallpaperModel.get(i).path === root.path)
                    return wallpaperModel.get(i).title
        }
        return root.title
    }
    readonly property int       _barH: 30

    HoverHandler {
        id: _hover
        onHoveredChanged: {
            if (hovered) previewTimer.restart()
            else { previewTimer.stop(); root._previewPlaying = false }
        }
    }
    Timer {
        id: previewTimer
        interval: 2500
        repeat: false
        onTriggered: root._previewPlaying = true
    }

    CutShape {
        anchors.fill: parent
        fillColor: CP.alpha(CP.void2, 0.9)
        strokeColor: PlaylistState.entryHighlightPath === root.path
                    ? CP.alpha(CP.cyan, 0.9)
                    : CP.alpha(CP.yellow, 0.2)
        strokeWidth: PlaylistState.entryHighlightPath === root.path ? 2 : 1
        inset: 0.5
        cutTopLeft: 4; cutBottomRight: 4
    }

    CutShape {
        id: _highlightBorder
        anchors.fill: parent
        visible: PlaylistState.entryHighlightPath === root.path
                || PlaylistState.selectedEntryPath === root.path
        fillColor: "transparent"
        strokeColor: _flashing ? CP.red : CP.cyan
        strokeWidth: 3
        inset: 0.5
        cutTopLeft: 4; cutBottomRight: 4
        z: 100

        property bool _flashing: false

        function _triggerFlash() {
            _flashing = true
            opacity = 1.0
            _flashAnim.restart()
            _settleTimer.restart()
        }

        Component.onCompleted: {
            if (PlaylistState.entryHighlightPath === root.path)
                _triggerFlash()
        } 

        Connections {
            target: PlaylistState
            function onEntryHighlightPathChanged() {
                if (PlaylistState.entryHighlightPath === root.path) {
                    _highlightBorder._triggerFlash()
                }
            }
        }

        SequentialAnimation {
            id: _flashAnim
            loops: 5
            NumberAnimation { target: _highlightBorder; property: "opacity"; from: 1.0; to: 0.1; duration: 100 }
            NumberAnimation { target: _highlightBorder; property: "opacity"; from: 0.1; to: 1.0; duration: 100 }
            onStopped: {
                _highlightBorder._flashing = false
                _highlightBorder.opacity = 1.0
            }
        }

        Timer {
            id: _settleTimer
            interval: 1000
            repeat: false
            onTriggered: {
                _highlightBorder._flashing = false
                _highlightBorder.opacity = 1.0
            }
        }
    }

    // ── Thumbnail ─────────────────────────────────────────────────
    Item {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: _controlBar.top
        clip: true

        Image {
            anchors.fill: parent
            source: root.thumb !== "" ? "file://" + root.thumb : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            opacity: (root._previewPlaying && (root.type === "gif" || root.type === "scene")) ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.InOutQuad } }
        }

        AnimatedImage {
            anchors.fill: parent
            source: root._previewPlaying && root.type === "gif" ? "file://" + root.path : ""
            fillMode: Image.PreserveAspectCrop
            playing: root._previewPlaying && root.type === "gif"
            visible: root.type === "gif"
            opacity: (root._previewPlaying && root.type === "gif") ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.InOutQuad } }
        }

        WpePreviewItem {
            anchors.fill: parent
            visible: root.type === "scene" && root._previewPlaying
            scenePath: root._previewPlaying && root.type === "scene" ? root.path : ""
            fps: 15
            opacity: ready ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.InOutQuad } }
        }

        CutShape {
            x: 3
            y: 3
            width: 22
            height: 16
            fillColor: CP.alpha(CP.void2, 0.85)
            strokeColor: CP.alpha(CP.yellow, 0.5)
            strokeWidth: 1; inset: 0.5
            cutTopLeft: 3; cutBottomRight: 3
            opacity: _hover.hovered ? 1.0 : 0.65

            Behavior on opacity { NumberAnimation { duration: 150 } }

            Text {
                anchors.centerIn: parent
                text: (root.index + 1).toString()
                font.family: "Oxanium"
                font.pixelSize: 9
                font.letterSpacing: 1
                color: Colours.accentPrimary
            }
        }

        Item {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 3
            anchors.rightMargin: 3
            width: 22
            height: 16
            opacity: _hover.hovered ? 1.0 : 0

            Behavior on opacity { NumberAnimation { duration: 150 } }

            CutShape {
                anchors.fill: parent
                fillColor: CP.alpha(CP.void2, 0.85)
                strokeColor: CP.alpha(CP.red, 0.5)
                strokeWidth: 1; inset: 0.5
                cutTopLeft: 3; cutBottomRight: 3
            }
            Text {
                anchors.centerIn: parent
                text: "\u2715"
                font.pixelSize: 10
                color: Colours.accentDanger
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: PlaylistState.removeEntry(root.index)
            }
        }
    }

    // ── Control bar ────────────────────────────────────────────────
    Item {
        id: _controlBar
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: root._barH

        Rectangle {
            anchors.fill: parent
            color: CP.alpha(CP.void2, 0.92)
        }

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: CP.alpha(CP.yellow, 0.12)
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.right: _badges.left
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            text: (_resolvedTitle !== "" ? _resolvedTitle : root.path.split("/").pop().replace(/\.[^.]+$/, "")).toUpperCase()
            font.family: "Oxanium"
            font.pixelSize: 9
            font.letterSpacing: 1
            color: Colours.textMuted
            elide: Text.ElideRight
        }

        Row {
            id: _badges
            spacing: 3
            anchors.right: PlaylistState.intervalMode === "per_entry" ? _intervalBox.left : parent.right
            anchors.rightMargin: PlaylistState.intervalMode === "per_entry" ? 4 : 8
            anchors.verticalCenter: parent.verticalCenter
            opacity: _hover.hovered ? 1.0 : 0.35

            Behavior on opacity { NumberAnimation { duration: 150 } }

            // Source badge
            Item {
                width: _srcLbl.implicitWidth + 8
                height: 14
                visible: root.source !== ""
                CutShape {
                    anchors.fill: parent
                    fillColor: CP.alpha(root.source === "wpe" ? CP.yellow : CP.cyan, 0.12)
                    strokeColor: CP.alpha(root.source === "wpe" ? CP.yellow : CP.cyan, 0.55)
                    strokeWidth: 1; inset: 0.5
                    cutTopLeft: 2; cutBottomRight: 2
                }
                Text {
                    id: _srcLbl
                    anchors.centerIn: parent
                    text: root.source.toUpperCase()
                    font.family: "Oxanium"
                    font.pixelSize: 7
                    font.letterSpacing: 1
                    color: root.source === "wpe" ? Colours.accentPrimary : Colours.accentSecondary
                }
            }

            // Type badge
            Item {
                width: _typLbl.implicitWidth + 8
                height: 14
                visible: root.type !== ""
                CutShape {
                    anchors.fill: parent
                    fillColor: CP.alpha(CP.void2, 0.7)
                    strokeColor: CP.alpha(Colours.textMuted, 0.35)
                    strokeWidth: 1; inset: 0.5
                    cutTopLeft: 2; cutBottomRight: 2
                }
                Text {
                    id: _typLbl
                    anchors.centerIn: parent
                    text: root.type.toUpperCase()
                    font.family: "Oxanium"
                    font.pixelSize: 7
                    font.letterSpacing: 1
                    color: Colours.textMuted
                }
            }
        }

        Item {
            id: _intervalBox
            visible: PlaylistState.intervalMode === "per_entry"
            width: 48
            height: 20
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter

            readonly property bool _dirty: _intervalInput.text !== (root.entryInterval > 0 ? root.entryInterval.toString() : "")

            CutShape {
                anchors.fill: parent
                fillColor: CP.alpha(CP.cyan, 0.07)
                strokeColor: _intervalBox._dirty ? CP.alpha(CP.yellow, 0.7) : CP.alpha(CP.cyan, 0.25)
                strokeWidth: 1; inset: 0.5
                cutTopLeft: 3; cutBottomRight: 3
                Behavior on strokeColor { ColorAnimation { duration: 150 } }
            }
            TextInput {
                id: _intervalInput
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.leftMargin: 5
                anchors.right: _secLbl.left
                verticalAlignment: TextInput.AlignVCenter
                text: root.entryInterval > 0 ? root.entryInterval.toString() : ""
                font.family: "Oxanium"
                font.pixelSize: 9
                color: Colours.textPrimary
                validator: IntValidator { bottom: 1; top: 86400 }

                onAccepted: {
                    var v = parseInt(text)
                    if (!isNaN(v) && v > 0) PlaylistState.setEntryInterval(root.index, v)
                    else text = root.entryInterval > 0 ? root.entryInterval.toString() : ""
                    focus = false
                }
                Keys.onEscapePressed: {
                    text = root.entryInterval > 0 ? root.entryInterval.toString() : ""
                    focus = false
                }
            }
            Text {
                id: _secLbl
                anchors.right: parent.right
                anchors.rightMargin: 3
                anchors.verticalCenter: parent.verticalCenter
                text: _intervalBox._dirty ? "*s" : "s"
                font.pixelSize: 7
                color: _intervalBox._dirty ? Colours.accentPrimary : Colours.textMuted
            }
        }
    }
}
