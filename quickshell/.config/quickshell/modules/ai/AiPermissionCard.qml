// AiPermissionCard.qml — renders a can_use_tool control request as a decision.
//
// The CLI blocks the turn until a control_response goes back, so this card is
// the whole authorization gate: nothing the model does to the system happens
// without a click here.
import QtQuick
import "../../common"
import "../../common/Colors.js" as CP

Item {
    id: root

    // The pendingPermission object from AiSession, or null.
    property var request: null

    signal allow(bool always)
    signal refuse()

    readonly property bool pending: root.request !== null

    // Pretty-printed tool input, capped: a Write can carry a whole file.
    readonly property string inputText: {
        if (!root.pending) return ""
        const s = JSON.stringify(root.request.input, null, 2)
        return s.length > 900 ? s.slice(0, 900) + "\n… (" + (s.length - 900) + " more)" : s
    }

    implicitHeight: root.pending ? content.implicitHeight + 24 : 0
    height: implicitHeight
    visible: height > 0
    clip: true

    Behavior on implicitHeight { Anim { duration: 200 } }

    CutShape {
        anchors.fill: parent
        fillColor: CP.alpha(CP.yellow, 0.07)
        strokeColor: CP.yellow
        strokeWidth: 1.5
        inset: 0.75
        cutTopLeft: 6
        cutBottomRight: 6
    }

    // Waiting on a human: pulse, per the design system's pending convention.
    SequentialAnimation on opacity {
        running: root.pending
        loops: Animation.Infinite
        NumberAnimation { from: 1.0; to: 0.78; duration: 700 }
        NumberAnimation { from: 0.78; to: 1.0; duration: 700 }
    }

    Column {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 6

        Text {
            text: "◢ AUTHORIZATION REQUIRED"
            font.family: "Oxanium"
            font.pixelSize: 10
            font.letterSpacing: 2
            font.bold: true
            color: CP.yellow
        }

        Text {
            width: content.width
            text: root.pending
                ? String(root.request.display_name).toUpperCase()
                  + (root.request.description !== "" ? "  ·  " + root.request.description : "")
                : ""
            elide: Text.ElideRight
            font.family: "Oxanium"
            font.pixelSize: 11
            color: "#e8e4c0"
        }

        Text {
            width: content.width
            text: root.inputText
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 9
            color: CP.alpha("#cfe6e2", 0.85)
        }

        Row {
            spacing: 6

            AiHeaderButton {
                label: "AUTHORIZE"
                accent: CP.neon
                onTriggered: root.allow(false)
            }

            AiHeaderButton {
                label: "ALWAYS"
                accent: CP.yellow
                // Only offered when the CLI itself suggests a broader scope.
                visible: root.pending && (root.request.suggestions?.length ?? 0) > 0
                onTriggered: root.allow(true)
            }

            AiHeaderButton {
                label: "DENY"
                accent: CP.red
                onTriggered: root.refuse()
            }
        }
    }
}
