import QtQuick
import QtQuick.Effects
import "../../common"


Item {
    id: root

    required property var  action
    required property bool selected

    signal triggered()

    property bool _hovered:   false
    property bool _glitching: false   // toggled by GlitchAnim.aberrationTarget

    width:  200
    height: 220

    // ── Color logic ─────────────────────────────────────────
    readonly property color borderCol:
        (action.isDanger && (_hovered || selected)) ? Colours.accentDanger
        : _hovered                                  ? Colours.accentPrimary
        : selected                                  ? Colours.accentMem
                                                    : Colours.accentSecondary

    readonly property color textCol:
        (action.isDanger && (_hovered || selected)) ? Colours.accentDanger
                                                    : Colours.accentPrimary

    // ── Trigger glitch on hover OR keyboard-select change ───
    onSelectedChanged: if (root.selected) glitcher.restart()

    // ── Background: CutShape con notch diagonale ────────────
    CutShape {
        id: bg
        anchors.fill: parent
        cutTopRight:   12
        cutBottomLeft: 12

        fillColor: (root._hovered || root.selected)
                   ? Qt.rgba(root.borderCol.r, root.borderCol.g, root.borderCol.b, 0.10)
                   : Qt.rgba(0, 6/255, 14/255, 0.55)
        strokeColor: root.borderCol
        strokeWidth: (root._hovered || root.selected) ? 2 : 1
        inset:       (root._hovered || root.selected) ? 1 : 0.5

        // Neon glow multi-layer via MultiEffect
        layer.enabled: root._hovered || root.selected
        layer.effect: MultiEffect {
            shadowEnabled:          true
            shadowColor:            root.borderCol
            shadowBlur:             0.6
            shadowVerticalOffset:   0
            shadowHorizontalOffset: 0
            shadowScale:            1.02
            shadowOpacity:          0.85
        }

        Behavior on strokeColor { ColorAnimation { duration: 150 } }
        Behavior on fillColor   { ColorAnimation { duration: 150 } }
    }

    // ── Icon (colored dynamically via MultiEffect) ──────────
    Image {
        id: iconImg
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top:              parent.top
        anchors.topMargin:        36
        source:  "file:///usr/share/wlogout/icons/" + root.action.id + ".png"
        width:   84
        height:  84
        smooth:  true
        visible: false   // solo source per MultiEffect
    }

    MultiEffect {
        anchors.fill:      iconImg
        source:            iconImg
        colorization:      1.0
        colorizationColor: root.textCol
        Behavior on colorizationColor { ColorAnimation { duration: 150 } }
    }

    // ── Label (con GlitchAnim + Translate) ──────────────────
    Item {
        id: labelWrap
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom:           parent.bottom
        anchors.bottomMargin:     22
        width:  labelText.width
        height: labelText.height

        transform: Translate {
            id: labelShift
            x: 0
        }

        Text {
            id: labelText
            text:  root.action.label
            color: root.textCol
            font.family:        "JetBrainsMono Nerd Font"
            font.pixelSize:     13
            font.weight:        Font.Bold
            font.letterSpacing: 3

            Behavior on color { ColorAnimation { duration: 150 } }
        }
    }

    // ── GlitchAnim (declarative, triggered da restart()) ────
    GlitchAnim {
        id: glitcher
        labelTarget:      labelText
        shiftTarget:      labelShift
        aberrationTarget: root
        baseColor:        root.textCol
        c1: root.action.isDanger ? Colours.accentDanger : Colours.accentMem
        c2: Colours.accentPrimary
        intensity: 0.8
    }

    // ── Shortcut hint (angolo alto-destra) ──────────────────
    Text {
        anchors.top:     parent.top
        anchors.right:   parent.right
        anchors.margins: 14
        text:  "[" + root.action.shortcut + "]"
        color: Qt.rgba(Colours.accentSecondary.r, Colours.accentSecondary.g, Colours.accentSecondary.b, 0.65)
        font.family:    "JetBrainsMono Nerd Font"
        font.pixelSize: 11
        font.weight:    Font.Bold
    }

    // ── Mouse ───────────────────────────────────────────────
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: {
            root._hovered = true
            glitcher.restart()
        }
        onExited:  root._hovered = false
        onClicked: root.triggered()
    }
}
