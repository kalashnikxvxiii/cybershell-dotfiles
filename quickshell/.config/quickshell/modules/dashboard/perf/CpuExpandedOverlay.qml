// CpuExpandedOverlay.qml — Expanded overlay with per-core CPU sparklines
// Extracted from PerfMetrics.qml: 4-column grid with SparklineItem for each core

import QtQuick
import QtQuick.Layouts
import CyberGraphics
import "../../../common"

Item {
    id: root
    clip: true

    // ── Required properties ──
    required property real    expandProgress
    required property bool    animTriggered
    required property bool    expanded
    required property color   cpuColor
    required property color   tempColor
    required property real    cpuPerc
    required property var     corePercs
    required property var     coreHistories

    signal closeRequested()

    CutShape {
        anchors.fill: parent
        fillColor: Colours.moduleBg
        cutBottomLeft: 10
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 6
        opacity: root.expandProgress

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "CPU CORES"
                font.family: "Oxanium"
                font.pixelSize: 11
                font.letterSpacing: 2
                color: root.cpuColor
            }
            Item { Layout.fillWidth: true }
            Text {
                text: root.cpuPerc.toFixed(1) + "%"
                font.family: "Chakra Petch"
                font.pixelSize: 10
                color: root.tempColor
            }
            Text {
                text: "[ESC]"
                font.family: "Oxanium"
                font.pixelSize: 8
                color: Colours.textMuted
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.closeRequested()
                }
            }
        }

        // Grid core sparklines
        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 4
            columnSpacing: 4
            rowSpacing: 4

            Repeater {
                model: root.corePercs.length

                Item {
                    id: coreWrapper
                    required property int index

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 36

                    SparklineItem {
                        anchors.fill: parent

                        cutBottomLeft: 12
                        strokeWidth: 1
                        strokeColor: Colours.neonBorder(0.3)

                        values: {
                            void root.cpuPerc    // trigger rebind every 2s
                            if (!root.expanded) return []
                            return root.coreHistories[index] || []
                        }
                        lineColor: root.cpuColor
                        fillOpacity: 0.7
                        lineWidth: 1.5
                        label: "C" + index
                        valueText: (root.corePercs[index] || 0).toFixed(0) + "%"
                        valueColor: (root.corePercs[index] || 0) > 90 ? Colours.accentDanger
                                : (root.corePercs[index] || 0) > 75 ? Colours.accentWarn
                                : root.cpuColor
                        labelColor: Colours.textMuted
                        bgColor: Qt.rgba(0, 0, 0, 0.3)
                    }

                    property bool _animDone: false

                    opacity: _animDone ? 1 : 0
                    scale: _animDone ? 1.0 : 0.2

                    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.InQuad } }
                    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }

                    Timer {
                        interval: index * 100
                        running: root.animTriggered
                        repeat: false
                        onTriggered: coreWrapper._animDone = true
                    }

                    Connections {
                        target: root
                        function onAnimTriggeredChanged() {
                            if (!root.animTriggered) coreWrapper._animDone = false
                        }
                    }
                }
            }
        }
    }

    CutShape {
        anchors.fill: parent
        strokeWidth: 1
        strokeColor: Colours.neonBorder(0.3)
        inset: 0.5
        cutBottomLeft: 24
    }
}
