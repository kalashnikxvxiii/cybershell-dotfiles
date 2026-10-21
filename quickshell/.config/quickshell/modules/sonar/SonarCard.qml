// SonarCard.qml — the Sonar panel's face: header, radar, contacts, actions.
//
// Split from the window that hosts it so the whole face can be built and
// looked at outside the desktop, the same way the network card is.
import QtQuick
import Quickshell
import Quickshell.Networking
import Quickshell.Bluetooth
import "../../common/Colors.js" as CP
import "../../common"
import "../../common/effects"

FocusScope {
    id: root

    // Open state is passed in rather than read from the singleton: the harness
    // drives it directly, and the window owns the slide.
    property bool shown: SonarState.open

    readonly property bool netView: SonarState.view === "net"
    readonly property color accent: netView ? Colours.accentSecondary : Colours.accentMem

    implicitWidth: 380
    implicitHeight: 528

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            SonarState.close()
            event.accepted = true
        } else if (event.key === Qt.Key_Tab) {
            root.switchView()
            event.accepted = true
        }
    }

    // ── Chrome ───────────────────────────────────────────────────
    CutShape {
        anchors.fill: parent
        fillColor: Colours.moduleBg
        cutBottomLeft: 32
    }

    ScanlineOverlay {
        anchors.fill: parent
        opacity: 0.06
    }

    CornerAccents {
        anchors.margins: 3
        accentColor: root.accent
        showTopLeft: true
        showBottomRight: true
        showTopRight: false
        showBottomLeft: false
    }

    CutShape {
        anchors.fill: parent
        strokeColor: CP.alpha(root.accent, 0.45)
        strokeWidth: 1
        inset: 0.5
        cutBottomLeft: 32
    }

    // ── Header ───────────────────────────────────────────────────
    Item {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 12
        height: 30

        Rectangle {
            id: headBar
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 5; height: 22
            color: root.accent
        }

        Column {
            anchors.left: headBar.right
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                text: "SONAR"
                font.family: "Oxanium"
                font.pixelSize: 15
                font.bold: true
                font.letterSpacing: 3
                color: Colours.textPrimary
                transform: Translate { id: titleShift }
            }
            Text {
                id: subLabel
                text: root.netView ? "NETWORK SWEEP" : "BLUETOOTH SWEEP"
                font.family: "Oxanium"
                font.pixelSize: 8
                font.letterSpacing: 2
                color: CP.alpha(root.accent, 0.8)
            }
        }

        // Two segments rather than one button naming its destination: a chip
        // reading "BLUETOOTH" while the network view was open got read as the
        // view you were in, not the one it would take you to.
        Row {
            id: viewSwitch
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            Repeater {
                model: [
                    { key: "net", label: "NET", tint: Colours.accentSecondary },
                    { key: "bt",  label: "BT",  tint: Colours.accentMem }
                ]

                Item {
                    id: seg
                    required property var modelData
                    required property int index
                    readonly property bool active: SonarState.view === seg.modelData.key
                    width: segLabel.implicitWidth + 20
                    height: 22

                    CutShape {
                        anchors.fill: parent
                        fillColor: seg.active ? CP.alpha(seg.modelData.tint, 0.22)
                                 : segMa.containsMouse ? CP.alpha(seg.modelData.tint, 0.1)
                                                       : "transparent"
                        strokeColor: CP.alpha(seg.modelData.tint, seg.active ? 0.85 : 0.3)
                        strokeWidth: 1
                        inset: 0.5
                        cutBottomLeft: seg.index === 0 ? 8 : 0
                        cutTopRight: seg.index === 1 ? 8 : 0
                    }

                    Text {
                        id: segLabel
                        anchors.centerIn: parent
                        text: seg.modelData.label
                        font.family: "Oxanium"
                        font.pixelSize: 9
                        font.bold: true
                        font.letterSpacing: 1.5
                        color: seg.active ? seg.modelData.tint
                                          : CP.alpha(seg.modelData.tint, 0.45)
                    }

                    MouseArea {
                        id: segMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (!seg.active) root.switchView()
                    }
                }
            }
        }
    }

    // ── Status strip ─────────────────────────────────────────────
    Item {
        id: statusRow
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.topMargin: 2
        height: 16

        Text {
            id: statusLine
            anchors.left: parent.left
            anchors.right: powerChip.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: root.netView ? root.netStatusText() : root.btStatusText()
            font.family: "Chakra Petch"
            font.pixelSize: 9
            color: Colours.textMuted
        }

        // The radio switch for whichever view is showing. A hardware kill
        // switch is reported, not overridden: the software flag cannot lift it.
        Item {
            id: powerChip
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: powerLabel.implicitWidth + 16
            height: 16

            // Only once a Wi-Fi device is actually known: the service reports
            // everything as false for the first second after the shell starts.
            readonly property bool blocked: root.netView && !!SonarState.wifiDevice
                                            && !Networking.wifiHardwareEnabled
            readonly property bool on: root.netView
                ? Networking.wifiEnabled
                : (!!SonarState.adapter && SonarState.adapter.enabled)
            readonly property color tint: blocked ? Colours.accentWarn
                                        : on ? Colours.accentOk
                                             : Colours.textMuted

            CutShape {
                anchors.fill: parent
                fillColor: powerMa.containsMouse && !powerChip.blocked
                           ? CP.alpha(powerChip.tint, 0.18) : "transparent"
                strokeColor: CP.alpha(powerChip.tint, 0.65)
                strokeWidth: 1
                inset: 0.5
                cutBottomLeft: 5
                cutTopRight: 5
            }

            Text {
                id: powerLabel
                anchors.centerIn: parent
                text: powerChip.blocked ? "RF BLOCKED"
                    : root.netView ? (powerChip.on ? "WIFI ON" : "WIFI OFF")
                                   : (powerChip.on ? "BT ON" : "BT OFF")
                font.family: "Oxanium"
                font.pixelSize: 8
                font.bold: true
                font.letterSpacing: 1.5
                color: powerChip.tint
            }

            MouseArea {
                id: powerMa
                anchors.fill: parent
                hoverEnabled: true
                enabled: !powerChip.blocked && (root.netView || !!SonarState.adapter)
                cursorShape: Qt.PointingHandCursor
                onClicked: root.netView ? SonarState.toggleWifi() : SonarState.toggleAdapter()
            }
        }
    }

    // A refused connection, kept on screen for a few seconds. Red, and where
    // the eye already is: right under the status it contradicts.
    Text {
        id: errorLine
        anchors.top: statusRow.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        elide: Text.ElideRight
        visible: opacity > 0
        opacity: SonarState.lastError !== "" ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 180 } }
        text: SonarState.lastError
        font.family: "Chakra Petch"
        font.pixelSize: 9
        color: Colours.accentDanger
    }

    // ── Radar ────────────────────────────────────────────────────
    SonarDisplay {
        id: display
        anchors.top: statusRow.bottom
        anchors.topMargin: 6
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - 24
        height: 280
        accent: root.netView ? CP.cyan : CP.magenta
        entries: root.entries
        revision: root.netView ? SonarState.netRev : SonarState.btRev
        sweeping: root.netView ? SonarState.scanning : SonarState.discovering
        active: root.shown
        selectedKey: SonarState.selectedKey
        onPicked: key => SonarState.selectedKey = (SonarState.selectedKey === key ? "" : key)
    }

    // ── Contacts ─────────────────────────────────────────────────
    Rectangle {
        id: listSep
        anchors.top: display.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        height: 1
        color: CP.alpha(root.accent, 0.25)
    }

    Flickable {
        id: listView
        anchors.top: listSep.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: actions.top
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.topMargin: 4
        // Clear of the card's bottom-left cut: rows drawn into the corner
        // spilled over the diagonal, which nothing may cross.
        anchors.bottomMargin: 10
        clip: true
        contentHeight: contacts.implicitHeight
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: contacts
            width: listView.width

            Repeater {
                model: root.entries

                SonarContact {
                    required property var modelData
                    width: contacts.width
                    label: modelData.label
                    meta: modelData.meta
                    accent: root.accent
                    strength: modelData.strength
                    connected: modelData.connected
                    busy: modelData.busy
                    selected: SonarState.selectedKey === modelData.key
                    hovered: display.hoveredKey === modelData.key
                    onClicked: SonarState.selectedKey =
                        (SonarState.selectedKey === modelData.key ? "" : modelData.key)
                    onEntered: display.hoveredKey = modelData.key
                    onExited: if (display.hoveredKey === modelData.key) display.hoveredKey = ""
                }
            }

            Text {
                width: contacts.width
                visible: root.entries.length === 0
                horizontalAlignment: Text.AlignHCenter
                topPadding: 12
                text: root.netView ? "NO CONTACTS — SWEEPING" : "NO DEVICES — SWEEPING"
                font.family: "Oxanium"
                font.pixelSize: 9
                font.letterSpacing: 2
                color: Colours.textMuted
            }
        }
    }

    // Scroll affordances: a fade where rows leave the view, and a 2px track
    // on the right while there is more than fits.
    Rectangle {
        anchors.left: listView.left
        anchors.right: listView.right
        anchors.bottom: listView.bottom
        height: 14
        visible: listView.contentHeight > listView.height
                 && listView.contentY < listView.contentHeight - listView.height - 1
        gradient: Gradient {
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 1; color: Colours.moduleBg }
        }
    }

    Rectangle {
        id: listTrack
        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.top: listView.top
        anchors.bottom: listView.bottom
        width: 2
        visible: listView.contentHeight > listView.height
        color: CP.alpha(root.accent, 0.12)

        Rectangle {
            width: parent.width
            height: Math.max(16, listTrack.height * listView.height / Math.max(1, listView.contentHeight))
            y: (listTrack.height - height) * (listView.contentY
                / Math.max(1, listView.contentHeight - listView.height))
            color: CP.alpha(root.accent, 0.7)
        }
    }

    // ── Actions ──────────────────────────────────────────────────
    Row {
        id: actions
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.bottomMargin: 12
        anchors.rightMargin: 12
        // Fixed height even when empty, so the list above keeps one resting
        // place instead of growing into the corner when nothing is selected.
        height: 20
        spacing: 8
        layoutDirection: Qt.RightToLeft

        Repeater {
            model: root.actionsFor(SonarState.selectedKey)

            Item {
                required property var modelData
                width: actionLabel.implicitWidth + 18
                height: 20

                CutShape {
                    anchors.fill: parent
                    fillColor: actionMa.containsMouse ? CP.alpha(modelData.danger ? CP.red : root.accent, 0.2)
                                                      : "transparent"
                    strokeColor: CP.alpha(modelData.danger ? CP.red : root.accent, 0.7)
                    strokeWidth: 1
                    inset: 0.5
                    cutBottomLeft: 6
                }

                Text {
                    id: actionLabel
                    anchors.centerIn: parent
                    text: modelData.label
                    font.family: "Oxanium"
                    font.pixelSize: 9
                    font.bold: true
                    font.letterSpacing: 1.5
                    color: modelData.danger ? CP.red : root.accent
                }

                MouseArea {
                    id: actionMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.runAction(modelData.id)
                }
            }
        }
    }

    // Password entry, shown only for a secured network we have never
    // joined: it takes the place of the action row's left side.
    Item {
        id: pskBox
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: 40
        anchors.bottomMargin: 12
        width: 170
        height: 20
        visible: root.needsPsk

        CutShape {
            anchors.fill: parent
            fillColor: CP.alpha(CP.void2, 0.6)
            strokeColor: CP.alpha(root.accent, 0.5)
            strokeWidth: 1
            inset: 0.5
            cutBottomLeft: 6
        }

        TextInput {
            id: pskField
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            verticalAlignment: TextInput.AlignVCenter
            echoMode: TextInput.Password
            font.family: "Chakra Petch"
            font.pixelSize: 10
            color: Colours.textPrimary
            selectByMouse: true
            onAccepted: root.runAction("connect")

            Text {
                anchors.fill: parent
                verticalAlignment: Text.AlignVCenter
                visible: pskField.text === "" && !pskField.activeFocus
                text: "PASSWORD"
                font.family: "Oxanium"
                font.pixelSize: 9
                font.letterSpacing: 1.5
                color: Colours.textMuted
            }
        }
    }

    // ── View plumbing ────────────────────────────────────────────────────
    function switchView() {
        viewGlitch.restart()
        SonarState.switchView()
    }

    GlitchAnim {
        id: viewGlitch
        shiftTarget: titleShift
        labelTarget: subLabel
        baseColor: root.accent
        c1: CP.magenta
        c3: CP.cyan
    }

    // ── Entries ──────────────────────────────────────────────────────────
    // Both views feed the same shape: the radar and the list never need to
    // know which service the contact came from.
    readonly property var entries: root.netView ? root._netEntries() : root._btEntries()

    function _secLabel(sec) {
        var s = WifiSecurityType.toString(sec)
        return s ? s.toUpperCase() : "?"
    }

    function _netEntries() {
        // Depend on the revision so the list rebuilds while scanning.
        var rev = SonarState.netRev
        var out = []
        var wired = SonarState.wiredDevice
        if (wired && wired.connected) {
            // The cable sits at the centre of the display: it is the contact
            // that needs no hunting.
            out.push({
                key: "wired:" + wired.name,
                label: wired.name.toUpperCase(),
                meta: wired.linkSpeed ? (wired.linkSpeed + " MBIT" ) : "LINK",
                ring: 0.1,
                strength: -1,
                connected: true,
                busy: false,
                kind: "wired"
            })
        }
        var nets = SonarState.wifiNetworks()
        for (var i = 0; i < nets.length; i++) {
            var n = nets[i]
            out.push({
                key: "wifi:" + n.name,
                label: n.name || "(hidden)",
                meta: Math.round(n.signalStrength * 100) + "%  " + root._secLabel(n.security),
                // Strong networks sit near the centre, weak ones out at the rim.
                ring: 0.18 + (1 - Math.max(0, Math.min(1, n.signalStrength))) * 0.8,
                strength: n.signalStrength,
                connected: n.connected,
                busy: n.stateChanging,
                kind: "wifi"
            })
        }
        return out
    }

    function _btEntries() {
        var rev = SonarState.btRev
        var out = []
        var devs = SonarState.btDevices()
        for (var i = 0; i < devs.length; i++) {
            var d = devs[i]
            out.push({
                key: "bt:" + d.address,
                label: (d.deviceName || d.name || d.address).toUpperCase(),
                meta: d.connected ? (d.batteryAvailable ? Math.round(d.battery * 100) + "%  LINKED" : "LINKED")
                    : d.paired    ? "PAIRED"
                                  : "IN RANGE",
                // No RSSI in the service, so range stands for how close the
                // device is to being usable: linked at the centre, unknown out.
                ring: d.connected ? 0.2 : d.paired ? 0.55 : 0.85,
                strength: -1,
                connected: d.connected,
                busy: d.pairing || d.state === BluetoothDeviceState.Connecting
                                || d.state === BluetoothDeviceState.Disconnecting,
                kind: "bt"
            })
        }
        return out
    }

    function _selected() {
        var key = SonarState.selectedKey
        if (!key) return null
        if (key.indexOf("wifi:") === 0) {
            var nets = SonarState.wifiNetworks()
            for (var i = 0; i < nets.length; i++)
                if ("wifi:" + nets[i].name === key) return nets[i]
        } else if (key.indexOf("bt:") === 0) {
            var devs = SonarState.btDevices()
            for (var j = 0; j < devs.length; j++)
                if ("bt:" + devs[j].address === key) return devs[j]
        } else if (key.indexOf("wired:") === 0) {
            return SonarState.wiredDevice
        }
        return null
    }

    readonly property bool needsPsk: {
        var key = SonarState.selectedKey
        if (key.indexOf("wifi:") !== 0) return false
        var n = root._selected()
        return !!n && !n.connected && !n.known && n.security !== WifiSecurityType.Open
    }

    function actionsFor(key) {
        var o = root._selected()
        if (!o) return []
        if (key.indexOf("wired:") === 0)
            return o.connected ? [{ id: "disconnect", label: "DISCONNECT", danger: true }] : []
        if (key.indexOf("wifi:") === 0) {
            if (o.connected) return [{ id: "disconnect", label: "DISCONNECT", danger: true }]
            var acts = [{ id: "connect", label: "CONNECT", danger: false }]
            if (o.known) acts.push({ id: "forget", label: "FORGET", danger: true })
            return acts
        }
        // Bluetooth.
        if (o.connected) return [{ id: "disconnect", label: "DISCONNECT", danger: true }]
        var bacts = [{ id: "connect", label: o.paired ? "CONNECT" : "PAIR", danger: false }]
        if (o.paired) bacts.push({ id: "forget", label: "FORGET", danger: true })
        return bacts
    }

    function runAction(id) {
        var o = root._selected()
        if (!o) return
        var key = SonarState.selectedKey
        if (id === "disconnect") {
            o.disconnect()
        } else if (id === "forget") {
            o.forget()
            SonarState.selectedKey = ""
        } else if (id === "connect") {
            if (key.indexOf("bt:") === 0) {
                if (o.paired) o.connect()
                else o.pair()
            } else if (root.needsPsk) {
                o.connectWithPsk(pskField.text)
                pskField.text = ""
            } else {
                o.connect()
            }
        }
    }

    function netStatusText() {
        var wired = SonarState.wiredDevice
        var active = SonarState.activeNetwork()
        var parts = []
        parts.push(wired && wired.connected ? "ETH " + wired.name + " LINKED" : "ETH DOWN")
        parts.push(Networking.wifiEnabled
                   ? (active ? "WIFI " + active.name : "WIFI IDLE")
                   : "WIFI OFF")
        parts.push(SonarState.scanning ? "SWEEPING" : "SWEEP HELD")
        return parts.join("   ·   ")
    }

    function btStatusText() {
        var a = SonarState.adapter
        if (!a) return "NO ADAPTER"
        var parts = [a.name.toUpperCase()]
        parts.push(a.enabled ? "ADAPTER ON" : "ADAPTER OFF")
        parts.push(a.discovering ? "SWEEPING" : "SWEEP HELD")
        return parts.join("   ·   ")
    }
}
