// HudUpdates.qml -- the update banners, left side. The first banner in the list is the big one;
// a second sits under it, small and cyan. Dismiss the big one and the other takes its place and
// its size, keeping its color. Left click upgrades, right click dismisses.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell
import "../../common"

Item {
    id: root

    readonly property var banners: {
        const out = []
        if (UpdateState.credText !== "")
            out.push({ kind: "cred", title: "PKG INSTALLED!", detail: UpdateState.credText, tone: HudState.ok })
        if (UpdateState.showShell)
            out.push({ kind: "shell", title: "SHELL UPDATE AVAILABLE!", detail: "NEW GIGS AVAILABLE: " + UpdateState.shellCount, tone: HudState.ok })
        if (UpdateState.showSystem)
            out.push({ kind: "system", title: (UpdateState.hasCachy ? "CACHY" : "ARCH") + " UPDATE AVAILABLE!", detail: "NEW GIGS AVAILABLE: " + UpdateState.systemCount, tone: UpdateState.devMachine ? HudState.ok : HudState.tech })
        return out
    }
    // Outside the dotfiles: these two images are CyberArch's, whose repo has no license
    readonly property string assets: "file://" + Quickshell.env("HOME") + "/.local/share/qs-hud-assets/"

    width: 490
    height: banners.length === 0 ? 0 : 250

    transform: Tilt { w: root.width; h: 210; yaw: 16; pitch: 2; roll: 0.5; focal: 2100 }

    // Flat at twice the size, then tilted as one texture (see HudPlate)
    layer.enabled: banners.length > 0
    layer.smooth: true
    layer.textureSize: Qt.size(root.width * 2, root.height * 2)
    layer.effect: DarkHalo {}

    // 24px of margin around the banners, for the ghosts and the halo
    Column {
        x: 24
        y: 24
        spacing: 14

        Repeater {
            model: root.banners

            Banner {
                required property var modelData
                required property int index
                kind: modelData.kind
                title: modelData.title
                detail: modelData.detail
                tone: modelData.tone
                big: index === 0
            }
        }
    }

    // The emblem and the bar, without their writing: what the ghosts repeat
    component Plate: Item {
        id: plate
        property bool big: true
        property color tone
        property color fill: tone

        Item {
            visible: plate.big
            y: 1
            width: 54
            height: 54

            // The drawn emblem stands in where the image isn't installed
            Image {
                id: emblem
                anchors.fill: parent
                source: root.assets + "circle.png"
                sourceSize: Qt.size(108, 108)
                smooth: true
                layer.enabled: true
                layer.effect: MultiEffect {
                    colorization: 1
                    colorizationColor: plate.tone
                    brightness: 0.45
                }
            }
            CornerAccents {
                visible: emblem.status !== Image.Ready
                anchors.fill: parent
                accentColor: plate.tone
                size: 10
            }
            Rectangle {
                visible: emblem.status !== Image.Ready
                anchors.centerIn: parent
                width: 36
                height: 36
                radius: 18
                color: "transparent"
                border.color: plate.tone
                border.width: 2
            }
            Text {
                visible: emblem.status !== Image.Ready
                anchors.centerIn: parent
                text: "\uf005"
                color: plate.tone
                font { family: HudState.icons; pixelSize: 17 }
            }
        }
        CutShape {
            x: 62
            y: plate.big ? 6 : 0
            width: plate.big ? 360 : 300
            height: plate.big ? 44 : 26
            cutTopRight: plate.big ? 8 : 5
            cutBottomRight: plate.big ? 18 : 10
            fillColor: plate.fill
        }
    }

    component Banner: Item {
        id: banner
        property string kind
        property string title
        property string detail
        property color tone
        property bool big: true

        // One ghost's step, in the tilted plane: along the line that leaves the desktop's
        // center and passes through the banner (as in HudCornerDock)
        property point step: Qt.point(0, 0)

        function aim() {
            const desktop = root.parent
            const cx = banner.width / 2, cy = banner.height / 2
            const c = banner.mapToItem(desktop, cx, cy)
            const dx = c.x - desktop.width / 2, dy = c.y - desktop.height / 2
            const len = Math.hypot(dx, dy) || 1
            const end = banner.mapFromItem(desktop, c.x + dx / len * 8, c.y + dy / len * 8)
            banner.step = Qt.point(end.x - cx, end.y - cy)
        }

        width: 430
        height: big ? 78 : 46

        Component.onCompleted: Qt.callLater(banner.aim)
        onBigChanged: Qt.callLater(banner.aim)
        Connections {
            target: root.parent
            function onWidthChanged() { banner.aim() }
            function onHeightChanged() { banner.aim() }
        }

        // Ghosts, fainter the further out
        Repeater {
            model: 2
            Plate {
                required property int index
                x: banner.step.x * (index + 1)
                y: banner.step.y * (index + 1)
                z: -index - 1
                opacity: 0.4 - index * 0.2
                big: banner.big
                tone: banner.tone
                fill: "transparent"

                CutShape {
                    x: 62
                    y: banner.big ? 6 : 0
                    width: banner.big ? 360 : 300
                    height: banner.big ? 44 : 26
                    cutTopRight: banner.big ? 8 : 5
                    cutBottomRight: banner.big ? 18 : 10
                    inset: 0.5
                    strokeColor: banner.tone
                }
            }
        }

        // GlitchAnim writes colors imperatively: into this holder, not into a binding
        QtObject {
            id: tint
            property color color: banner.tone
        }
        GlitchAnim {
            id: glitch
            labelTarget: tint
            shiftTarget: titleShift
            baseColor: banner.tone
        }

        Plate {
            big: banner.big
            tone: glitch.running ? tint.color : banner.tone
        }

        Text {
            x: 74
            y: banner.big ? 6 : 0
            height: banner.big ? 44 : 26
            verticalAlignment: Text.AlignVCenter
            text: "▲"
            color: "#00060e"
            font { family: HudState.font; pixelSize: banner.big ? 13 : 9 }
        }
        Text {
            x: banner.big ? 94 : 88
            y: banner.big ? 6 : 0
            height: banner.big ? 44 : 26
            verticalAlignment: Text.AlignVCenter
            text: banner.title
            color: "#00060e"
            transform: Translate { id: titleShift }
            font { family: HudState.font; pixelSize: banner.big ? 16 : 11; bold: true }
        }
        // The stamp at the far end, where its image is installed
        Image {
            visible: banner.big && status === Image.Ready
            x: 352
            y: 8
            width: 56
            height: 40
            source: root.assets + "updt.png"
            sourceSize: Qt.size(112, 80)
            fillMode: Image.PreserveAspectFit
            smooth: true
        }

        Row {
            x: 66
            y: banner.big ? 55 : 31
            spacing: 6
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "◢"
                color: banner.tone
                font { family: HudState.font; pixelSize: banner.big ? 12 : 8 }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: banner.detail
                color: banner.tone
                font { family: HudState.font; pixelSize: banner.big ? 12 : 9 }
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onContainsMouseChanged: if (containsMouse) glitch.restart()
            onClicked: e => {
                if (banner.kind === "cred")
                    return
                if (e.button === Qt.RightButton)
                    UpdateState.dismiss(banner.kind)
                else
                    UpdateState.upgrade(banner.kind)
            }
        }
    }
}
