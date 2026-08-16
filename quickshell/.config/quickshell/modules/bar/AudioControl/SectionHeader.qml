// SectionHeader.qml — Canonical "5px accent bar + title + status" section header
// Follows the PlaylistPanel / TransitionEditor pattern from quickshell-design-patterns.md §4.
//
// Use:
//   AC.SectionHeader { width: parent.width; label: "DEFAULT"; trail: "ROUTED"; accent: Colours.accentPrimary }
import "../../../common/Colors.js" as CP
import "../../../common"
import QtQuick

Item {
    id: root

    // ── API ──────────────────────────────────────────────────────
    property string label:   ""
    property string trail:   ""                  // optional sub-label after the bullet
    property color  accent:  Colours.accentPrimary
    property bool   divider: true                // 1px horizontal line below at 25% accent

    implicitHeight: 36

    // ── 5px left accent bar (canonical: always 5, never varies) ──
    Rectangle {
        id: accentBar
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: 3
        anchors.bottomMargin: 3
        width: 5
        color: root.accent
    }

    // ── Title + trail status (Column) ───────────────────────────
    Column {
        anchors.left: accentBar.right
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Text {
            text: root.label
            font.family: "Oxanium"
            font.pixelSize: 16
            font.letterSpacing: 3
            font.bold: true
            color: root.accent
        }
        Text {
            visible: root.trail !== ""
            text: "· " + root.trail
            font.family: "Oxanium"
            font.pixelSize: 12
            font.letterSpacing: 2
            color: CP.alpha(root.accent, 0.65)
        }
    }

    // ── 1px divider line below header (canonical optional) ──────
    Rectangle {
        visible: root.divider
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: CP.alpha(root.accent, 0.25)
    }
}
