import QtQuick
import QtQuick.Effects
import "../../common/Colors.js" as CP
import "../../common/BarConfig.js" as BC
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
            active: BC.isPrimary(root.barScreen)
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

    }
}
