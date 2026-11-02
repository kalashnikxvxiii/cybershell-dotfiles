// HudOverlay.qml -- the HUD printed on the desktop, one surface per screen.
// Its own namespace, so a Hyprland layer rule can keep it above linux-wallpaperengine,
// which shares the Bottom layer and would otherwise cover whatever mapped before it.
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../common"

Scope {
    id: root

    required property var screen

    PanelWindow {
        id: hud
        screen: root.screen

        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        visible: HudState.enabled
        WlrLayershell.layer: HudState.onTop ? WlrLayer.Top : WlrLayer.Bottom
        WlrLayershell.namespace: "qs-hud"

        // Only the buttons take the pointer
        mask: Region {
            Region { item: HudState.show.status ? status.sonar : null }
            Region { item: HudState.show.dock ? corner.row : null }
            Region { item: HudState.show.launcher ? launcher : null }
            Region { item: HudState.show.updates ? updates : null }
        }

        HudVitals {
            visible: HudState.show.vitals
            x: 4
            y: 42
            screen: root.screen
        }

        HudStatus {
            id: status
            visible: HudState.show.status
            screen: root.screen
            growth: sonarCard.growth
            growWidth: sonarCard.growWidth
            growHeight: sonarCard.growHeight
        }

        HudUpdates {
            id: updates
            visible: HudState.show.updates
            x: 20
            y: parent.height * 0.4
        }

        HudCornerDock {
            id: corner
            visible: HudState.show.dock
            screen: root.screen
        }

        // Launcher hint, bottom right
        Item {
            id: launcher
            visible: HudState.show.launcher
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 24
            width: 200
            height: 24
            transform: Tilt { w: launcher.width; h: launcher.height; yaw: -14; pitch: -1; roll: 2.5; focal: 1180 }

            layer.enabled: true
            layer.smooth: true
            layer.textureSize: Qt.size(width * 2, height * 2)
            layer.effect: DarkHalo {}

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 2
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Apps Launcher"
                    color: launcherGlitch.running ? launcherTint.color : HudState.danger
                    transform: Translate { id: launcherShift }
                    font { family: HudState.font; pixelSize: 15; bold: true }
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: chip.implicitWidth + 10
                    height: 18
                    color: HudState.track(HudState.tech)
                    border.color: HudState.tech
                    Text {
                        id: chip
                        anchors.centerIn: parent
                        text: "SUPER SPACE"
                        color: HudState.paper
                        font { family: HudState.font; pixelSize: 11; bold: true }
                    }
                }
            }
            // GlitchAnim writes colors imperatively: into this holder, not into a binding
            QtObject {
                id: launcherTint
                property color color: HudState.danger
            }
            GlitchAnim {
                id: launcherGlitch
                labelTarget: launcherTint
                shiftTarget: launcherShift
                baseColor: HudState.danger
            }
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: LauncherState.toggleMenu()
                onContainsMouseChanged: if (containsMouse) launcherGlitch.restart()
            }
        }
    }

    HudSonarCard {
        id: sonarCard
        screen: root.screen
    }

    HudNowPlaying {
        screen: root.screen
    }

    HudWorkspaceGlitch {
        screen: root.screen
    }

    HudVolumeOsd {
        screen: root.screen
    }
}
