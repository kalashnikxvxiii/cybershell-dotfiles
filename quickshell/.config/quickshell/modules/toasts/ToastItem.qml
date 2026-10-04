// ToastItem.qml -- one toast card.
//
// The type is the whole visual language: it picks the accent, the glyph and the
// lifetime. Right edge is cut (the cards enter from there), left edge stays
// square so the 5px accent stripe reads as a status bar.
//
// The drain line along the bottom is the remaining lifetime -- raw state, not an
// icon, and it makes an Error card visibly outlive a Success one.
pragma ComponentBehavior: Bound

import QtQuick
import "../../common"
import "../../common/effects"

Item {
    id: root

    required property Toast modelData
    // Fired by the stack once the card has finished sliding in.
    readonly property alias enterAnim: enterAnim

    readonly property color accent: modelData.type === Toast.Success ? Colours.accentOk
        : modelData.type === Toast.Warning ? Colours.accentWarn
        : modelData.type === Toast.Error   ? Colours.accentDanger
        :                                    Colours.accentSecondary

    // Nerd Font glyphs. Unknown names fall back to the type's own glyph, so a
    // caller can pass whatever it likes without breaking the card.
    readonly property string glyph: {
        switch (root.modelData.resolvedIcon) {
        case "palette":   return ""
        case "image":
        case "wallpaper": return ""
        case "audio":
        case "eq":        return ""
        case "process":   return ""
        case "text":
        case "ocr":       return ""
        case "save":      return ""
        case "playlist":  return ""
        case "ok":        return ""
        case "warn":      return ""
        case "error":     return ""
        default:          return ""
        }
    }

    anchors.left: parent.left
    anchors.right: parent.right
    implicitHeight: Math.max(54, textCol.implicitHeight + 22)

    transform: [
        Translate { id: entryShift },
        Translate { id: glitchShift }
    ]

    // ── Layer 1: background ───────────────────────────────────────────────
    CutShape {
        anchors.fill: parent
        fillColor: Colours.moduleBg
        cutTopLeft: 14
    }

    // ── Layer 2: content ─────────────────────────────────────────────────
    Rectangle {
        id: stripe
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 5
        color: root.accent
    }

    Text {
        id: glyphText
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        text: root.glyph
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 15
        color: root.accent
    }

    Column {
        id: textCol
        anchors.left: glyphText.right
        anchors.leftMargin: 10
        anchors.right: stripe.left
        anchors.rightMargin: 13
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3

        Text {
            id: titleText
            width: parent.width
            text: root.modelData.title.toUpperCase()
            font.family: "Oxanium"
            font.pixelSize: 11
            font.bold: true
            font.letterSpacing: 2
            color: root.accent
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            text: root.modelData.message
            visible: text !== ""
            font.family: "Oxanium"
            font.pixelSize: 10
            font.letterSpacing: 1
            color: Colours.textSecondary
            wrapMode: Text.WordWrap
            maximumLineCount: 3
            elide: Text.ElideRight
        }
    }

    // Remaining lifetime. Frozen on close so it never jumps back to full.
    Item {
        anchors.left: parent.left
        anchors.right: stripe.left
        anchors.bottom: parent.bottom
        height: 4

        Rectangle {
            id: drain
            property real frac: 1
            width: parent.width * frac
            height: parent.height
            color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.35)

            NumberAnimation on frac {
                to: 0
                duration: root.modelData.resolvedTimeout
                easing.type: Easing.Linear
                running: !root.modelData.closed
            }
        }
    }

    // ── Layer 3: decoration ──────────────────────────────────────────────
    Item {
        anchors.fill: parent
        clip: true
        opacity: 0.06
        ScanlineOverlay {}
    }

    CutShape {
        anchors.fill: parent
        strokeColor: Colours.panelBorder(root.accent)
        strokeWidth: 1
        inset: 0.5
        cutTopLeft: 14
    }

    // ── Entry: stepped slide from the right, no easing curve ─────────────
    SequentialAnimation {
        id: enterAnim
        ScriptAction { script: { root.opacity = 0; entryShift.x = 26 } }
        PauseAnimation { duration: 30 }
        ScriptAction { script: { root.opacity = 1; entryShift.x = 8 } }
        PauseAnimation { duration: 42 }
        ScriptAction { script: { root.opacity = 0.55; entryShift.x = 2 } }
        PauseAnimation { duration: 42 }
        ScriptAction { script: { root.opacity = 1; entryShift.x = 0 } }
        // Sparingly: only the cards that mean something went wrong glitch.
        ScriptAction {
            script: if (root.modelData.type === Toast.Warning || root.modelData.type === Toast.Error)
                glitch.restart()
        }
    }

    GlitchAnim {
        id: glitch
        labelTarget: titleText
        shiftTarget: glitchShift
        baseColor: root.accent
        shortMode: true
        x1: 3
        x2: -3
        finalPause: 174
    }
}
