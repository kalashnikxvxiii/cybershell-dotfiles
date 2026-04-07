import QtQuick
import QtQuick.Effects
import "../../common/Colors.js" as CP
import "."
import "../../common"

Item {
    id: root
    property var barScreen
    property Item volumeAnchor
    property Item powerAnchor
    property var parentWindow
    signal volumeToggleRequested()
    signal powerToggleRequested()

    implicitHeight: 24
    implicitWidth: innerRow.implicitWidth

    Item {
        id: bgItem
        anchors.fill: parent

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor:            CP.cyan
            shadowBlur:             0.75
            shadowOpacity:          0.40
            shadowHorizontalOffset: 0
            shadowVerticalOffset:   0
        }
        CutShape {
            anchors.fill: parent
            fillColor: CP.moduleBg
            strokeColor: CP.alpha(CP.cyan, 0.35)
            strokeWidth: 1
            inset: 0.5
            radiusTopRight: 4
            radiusBottomRight: 4
            cutBottomLeft: 8
        }
    }

    Row {
        id: innerRow
        height: parent.height
        spacing: 0

        // ── DP-1 modules ─────────────────────────────────────
        Loader {
            active: BarConfig.isPrimary(root.barScreen)
            height: innerRow.height

            sourceComponent: Component {
                Row {
                    height: parent.height
                    spacing: 0

                    Item {
                        width: 0
                        Component.onCompleted: root.volumeAnchor = this
                    }

                    WallpaperBarModule {
                        height: parent.height; showBackground: false
                    }

                    PulseModule {
                        height: parent.height; showBackground: false
                        onLeftClick: function() { root.volumeToggleRequested() }
                    }

                    Clock {
                        id: clockItem
                        height: innerRow.height
                    }

                    Item {
                        width: trayCtl.expandedContentWidth
                        height: parent.height
                        Behavior on width {
                            Anim {}
                        }
                    }

                    Tray {
                        id: trayCtl
                        height: parent.height
                        showBackground: false
                        parentWindow: root.parentWindow
                    }
                }
            }
        }

        // ── Secondary monitor modules ────────────────────────
        Loader {
        // Secondary monitor only
            active: !BarConfig.isPrimary(root.barScreen)
            height: innerRow.height

            sourceComponent: Component {
                Row {
                    height: parent.height
                    spacing: 0

                    Submap { height: parent.height; showBackground: false }
                    KeyboardModule { height: parent.height; showBackground: false }
                    BluetoothModule { height: parent.height; showBackground: false }
                    CpuModule { height: parent.height; showBackground: false }
                    MemoryModule { height: parent.height; showBackground: false }
                    LoadModule { height: parent.height; showBackground: false }
                    TemperatureModule { height: parent.height; showBackground: false }
                    DiskModule { height: parent.height; showBackground: false }
                    GpuModule { height: parent.height; showBackground: false }
                    NetworkModule { height: parent.height; showBackground: false }

                    Item {
                        width: 0; height: parent.height
                        Component.onCompleted: root.powerAnchor = this
                    }

                    ExitModule {
                        height: parent.height
                        onLeftClick: function() { root.powerToggleRequested() }
                    }
                }
            }
        }
    }
}
