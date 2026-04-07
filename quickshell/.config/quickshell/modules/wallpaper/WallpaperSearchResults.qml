import "../../common/Colors.js" as CP
import "../../common/effects"
import "../../common"
import QtQuick.Effects
import QtQuick

Item {
    id: searchResultsPanel

    required property var resultsModel
    required property int selectedSearchIdx
    required property bool downloading
    required property real downloadProgress
    required property string downloadingUrl
    required property var localBasenames

    signal resultSelected(int index, string thumbPath, string fullUrl)

    visible: resultsModel ? resultsModel.count > 0 : false

    layer.enabled: true
    layer.effect: MultiEffect {
        maskEnabled: true
        maskSource: searchPanelMask
        maskThresholdMin: 0.5
    }

    CutShape {
        anchors.fill: parent
        fillColor: CP.moduleBg
        strokeColor: CP.alpha(CP.cyan, 0.2)
        strokeWidth: 1
        inset: 0.5
        cutTopLeft: 24
        cutBottomRight: 24
    }

    Text {
        anchors.top: parent.top
        anchors.topMargin: 4
        anchors.left: parent.left
        anchors.leftMargin: 10
        text: "SEARCH RESULTS"
        font.family: "Oxanium"
        font.pixelSize: 9
        font.letterSpacing: 2
        color: Colours.textMuted
    }

    ListView {
        id: searchGrid
        anchors.fill: parent
        anchors.topMargin: 20
        anchors.bottomMargin: 8
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        orientation: ListView.Horizontal
        spacing: 6
        clip: true
        interactive: true
        focus: false
        keyNavigationEnabled: false
        boundsBehavior: Flickable.StopAtBounds

        model: searchResultsPanel.resultsModel

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            z: -1
            onWheel: wheel => {
                searchGrid.flick(wheel.angleDelta.y * 8, 0)
            }
        }

        delegate: Item {
            width: 100
            height: searchGrid.height
            required property string fname
            required property string thumbPath
            required property string fullUrl
            required property int index
            required property string source

            // Masked content (image clipped to cut shape)
            Item {
                id: resultContent
                anchors.fill: parent

                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: resultCardMask
                    maskThresholdMin: 0.5
                }

                Image {
                    anchors.fill: parent
                    source: thumbPath ? "file://" + thumbPath : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }

            // Source badge
            CutShape {
                id: sourceBadge
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: 2
                width: badgeText.implicitWidth + 8
                height: 22
                fillColor: CP.alpha("#000000", 0.6)
                cutBottomLeft: typeBadge.visible ? 0 : 4

                Text {
                    id: badgeText
                    anchors.centerIn: parent
                    text: {
                        switch (parent.parent.source) {
                            case "r":  return "\uf281"
                            case "rg": return "\uf281"
                            case "a":  return "A"
                            case "ag": return "AG"
                            default:   return parent.parent.source.toUpperCase()
                        }
                    }
                    font.family: parent.parent.source === "r" || parent.parent.source === "rg"
                        ? "JetBrainsMono Nerd Font" : "Oxanium"
                    font.pixelSize: 12
                    font.letterSpacing: parent.parent.source === "r" || parent.parent.source === "rg" ? 0 : 1
                    color: {
                        switch (parent.parent.source) {
                            case "wh": return CP.cyan
                            case "a":  return CP.yellow
                            case "ag": return CP.yellow
                            case "r":  return CP.magenta
                            case "rg": return CP.magenta
                            default:   return CP.cyan
                        }
                    }
                }
            }

            // Type badge (gif/img)
            CutShape {
                id: typeBadge
                anchors.top: sourceBadge.bottom
                anchors.right: parent.right
                width: sourceBadge.implicitWidth
                height: 14
                fillColor: CP.alpha("#000000", 0.6)
                cutBottomLeft: 4
                z: 5
                visible: parent.fullUrl.toLowerCase().endsWith(".gif")

                Text {
                    id: typeText
                    anchors.centerIn: parent
                    text: "GIF"
                    font.family: "Oxanium"
                    font.pixelSize: 9
                    font.letterSpacing: 1
                    color: Colours.accentOk
                }
            }

            // Downloaded indicator
            CutShape {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                width: 24
                height: 20
                fillColor: CP.alpha("#000000", 0.6)
                cutTopRight: 8
                visible: {
                    var bn = parent.fullUrl.substring(parent.fullUrl.lastIndexOf("/") + 1)
                    return searchResultsPanel.localBasenames[bn] === true
                }

                Text {
                    anchors.centerIn: parent
                    text: "\u2713"
                    font.family: "Oxanium"
                    font.pixelSize: 18
                    color: Colours.accentOk
                }
            }

            // ── Download overlay ───────────────────────────────────────────
            Item {
                anchors.fill: parent
                visible: searchResultsPanel.downloading && searchResultsPanel.downloadingUrl === parent.fullUrl
                z: 6

                // Darken
                Rectangle {
                    anchors.fill: parent
                    color: CP.alpha("#000000", 0.5)
                    opacity: searchResultsPanel.downloading && searchResultsPanel.downloadingUrl === parent.fullUrl ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                }

                // Scanlines
                ScanlineOverlay { opacity: 0.12 }

                // Download icon
                Text {
                    anchors.centerIn: parent
                    text: "\uf019"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 16
                    color: CP.cyan
                    PulseAnim on opacity { running: true; minOpacity: 0.3; duration: 400 }
                }

                // Progress Bar
                Item {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 3

                    Rectangle {
                        anchors.fill: parent
                        color: CP.alpha(CP.cyan, 0.15)
                    }

                    Rectangle {
                        id: smallProgressBar
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: parent.width * searchResultsPanel.downloadProgress
                        color: CP.cyan

                        SequentialAnimation on color {
                            loops: Animation.Infinite
                            running: searchResultsPanel.downloading
                            ColorAnimation { to: CP.cyan; duration: 500 }
                            ColorAnimation { to: CP.magenta; duration: 60 }
                            ColorAnimation { to: CP.yellow; duration: 60 }
                            ColorAnimation { to: CP.cyan; duration: 60 }
                        }
                    }
                }
            }

            // Border (outside mask, not clipped)
            CutShape {
                anchors.fill: parent
                fillColor: "transparent"
                strokeColor: searchResultsPanel.selectedSearchIdx === parent.index
                            ? Colours.accentSecondary
                            : CP.alpha(CP.cyan, 0.15)
                strokeWidth: searchResultsPanel.selectedSearchIdx === parent.index ? 2 : 1
                inset: 0.5
                cutTopLeft: 12
                cutBottomRight: 12
            }

            // Mask shape
            CutShape {
                id: resultCardMask
                anchors.fill: parent
                layer.enabled: true
                visible: false
                fillColor: "white"
                cutTopLeft: 12
                cutBottomRight: 12
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    searchResultsPanel.resultSelected(index, thumbPath, fullUrl)
                }
            }
        }
    }

    CutShape {
        id: searchPanelMask
        anchors.fill: parent
        layer.enabled: true
        visible: false
        fillColor: "white"
        cutTopLeft: 24
        cutBottomRight: 24
    }

    function positionAtIndex(idx) {
        searchGrid.positionViewAtIndex(idx, ListView.Center)
    }
}
