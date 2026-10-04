// SonarState.qml — state and data for the Sonar panel (network + bluetooth).
//
// Reads Quickshell's native services rather than polling CLI tools. One trap,
// verified on 0.3.1: their models stay EMPTY unless something instantiates the
// objects. `Networking.devices.values` read from a plain binding came back
// empty even seconds after start; with an Instantiator over the same model the
// devices appeared at once. Hence the trackers below, which exist only to keep
// the objects alive.
//
// Scanning is tied to the panel: Wi-Fi scanning and bluetooth discovery run
// while their view is on screen and stop when it closes.
pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Hyprland
import QtQuick

Singleton {
    id: root

    // ── Panel state ──────────────────────────────────────────────────────
    property bool   open: false
    // Monitor the panel belongs to, chosen when it is opened.
    property string screenName: ""
    property string view: "net"          // "net" | "bt"
    // Key of the entry the panel is showing details for: an SSID or a
    // bluetooth address.
    property string selectedKey: ""

    function openView(v, screen) {
        root.selectedKey = ""
        root.lastError = ""
        root.view = v
        root.screenName = screen ? screen : root._focusedScreen()
        root.open = true
    }

    // Opened without a screen (from a bar module), the panel belongs on the
    // monitor the user is looking at.
    function _focusedScreen() {
        var m = Hyprland.focusedMonitor
        return m ? m.name : root.screenName
    }

    // Reached from the keybind through scripts/sonar-toggle.sh: same view on
    // the same screen closes, anything else moves or switches the panel.
    function toggleFrom(screen, v) {
        if (root.open && root.view === v && root.screenName === screen) root.close()
        else root.openView(v, screen)
    }

    // Clicking the bar module that is already showing closes the panel.
    function toggleView(v) {
        if (root.open && root.view === v) root.close()
        else root.openView(v, "")
    }

    function close() {
        root.open = false
        root.selectedKey = ""
        root.lastError = ""
    }

    // ── Failures ─────────────────────────────────────────────────────────
    // NetworkManager reports a refused connection through a signal on the
    // network itself, and then goes quiet: without this the panel would just
    // sit there looking like nothing had happened.
    property string lastError: ""

    function reportFailure(name, reason) {
        // The service already words the reason as a sentence; only the network
        // name is shouted, the way every other label in the shell is.
        root.lastError = (name || "NETWORK").toUpperCase() + " — "
            + (ConnectionFailReason.toString(reason) || "Connection failed")
        _errorClear.restart()
    }

    readonly property Timer _errorClear: Timer {
        interval: 6000
        onTriggered: root.lastError = ""
    }

    // ── Radios ───────────────────────────────────────────────────────────
    function toggleWifi() {
        if (!Networking.wifiHardwareEnabled) return
        Networking.wifiEnabled = !Networking.wifiEnabled
    }

    function toggleAdapter() {
        if (root.adapter) root.adapter.enabled = !root.adapter.enabled
    }

    function switchView() { root.openView(root.view === "net" ? "bt" : "net") }

    // ── Revisions ────────────────────────────────────────────────────────
    // The service objects notify per-property; these counters give the canvas
    // and the lists a single thing to watch when the set of entries changes.
    property int netRev: 0
    property int btRev: 0

    // ── Network ──────────────────────────────────────────────────────────
    readonly property bool scanning: root.open && root.view === "net"

    property var wifiDevice: null
    property var wiredDevice: null

    function _rescanDevices() {
        var wifi = null, wired = null
        var devs = Networking.devices.values
        for (var i = 0; i < devs.length; i++) {
            var d = devs[i]
            if (d.type === DeviceType.Wifi && !wifi) wifi = d
            else if (d.type === DeviceType.Wired && (!wired || d.connected)) wired = d
        }
        root.wifiDevice = wifi
        root.wiredDevice = wired
        root.netRev++
    }

    // Wi-Fi scanning only while the network view is on screen: a scan wakes the
    // radio and costs power, and nothing would read the result anyway.
    onScanningChanged: if (root.wifiDevice) root.wifiDevice.scannerEnabled = root.scanning
    onWifiDeviceChanged: {
        if (root.wifiDevice) root.wifiDevice.scannerEnabled = root.scanning
        else root.activeSsid = ""
    }

    readonly property Connections _wifiWatch: Connections {
        target: root.wifiDevice
        function onConnectedChanged() {
            if (root.wifiDevice && !root.wifiDevice.connected) root.activeSsid = ""
        }
    }

    // Networks seen by the Wi-Fi device, strongest first. Rebuilt on every
    // revision rather than bound, so consumers can hold it steady while they
    // draw a frame.
    function wifiNetworks() {
        if (!root.wifiDevice || !root.wifiDevice.networks) return []
        var out = root.wifiDevice.networks.values.slice()
        out.sort(function (a, b) { return (b.signalStrength || 0) - (a.signalStrength || 0) })
        return out
    }

    // Remembered, because the network list is only populated while scanning:
    // with the scanner off the connected SSID would otherwise vanish from the
    // bar the moment the panel closes.
    property string activeSsid: ""

    function activeNetwork() {
        var nets = root.wifiNetworks()
        for (var i = 0; i < nets.length; i++) if (nets[i].connected) return nets[i]
        return null
    }

    // ── Bluetooth ────────────────────────────────────────────────────────
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool discovering: root.open && root.view === "bt"

    onDiscoveringChanged: root._syncDiscovery()
    onAdapterChanged: root._syncDiscovery()
    function _syncDiscovery() {
        var a = root.adapter
        if (!a) return
        // Only once the adapter is actually up: BlueZ answers "Resource Not
        // Ready" to StartDiscovery while it is still coming back on, and the
        // keeper below would repeat that every second.
        if (!a.enabled || a.state !== BluetoothAdapterState.Enabled) return
        if (a.discovering !== root.discovering) a.discovering = root.discovering
    }

    readonly property Connections _adapterWatch: Connections {
        target: root.adapter
        function onEnabledChanged() { root._syncDiscovery() }
        function onStateChanged() { root._syncDiscovery() }
        // Deliberately not watching discoveringChanged: reacting to it turned
        // a refused stop into a loop, each failure flipping the property back
        // and asking for another stop.
    }

    // The scan is re-asserted while a view is open, instead of being set once.
    // Switching an adapter back on does not restart discovery by itself, and
    // BlueZ refuses StartDiscovery while the adapter is still coming up, so a
    // single attempt at the moment of the change is lost. Same for Wi-Fi.
    readonly property Timer _scanKeeper: Timer {
        interval: 1000
        repeat: true
        running: root.open
        triggeredOnStart: true
        onTriggered: {
            // Only ever re-asserts the ON direction. Stopping is done once,
            // when the view changes: repeating it made BlueZ answer "No
            // discovery started" every second once it had already stopped.
            if (root.scanning && root.wifiDevice && !root.wifiDevice.scannerEnabled)
                root.wifiDevice.scannerEnabled = true
            if (root.discovering) root._syncDiscovery()
        }
    }

    // The device the bar module reports: the first one actually linked.
    function connectedBtDevice() {
        // Reading the revision makes callers re-evaluate when a device links
        // or drops, which the plain model read would not notice.
        var rev = root.btRev
        var devs = Bluetooth.devices.values
        for (var i = 0; i < devs.length; i++) if (devs[i].connected) return devs[i]
        return null
    }

    // Connected first, then paired, then whatever else discovery turns up.
    function btDevices() {
        var out = Bluetooth.devices.values.slice()
        out.sort(function (a, b) {
            var ra = (a.connected ? 0 : a.paired ? 1 : 2)
            var rb = (b.connected ? 0 : b.paired ? 1 : 2)
            if (ra !== rb) return ra - rb
            return (a.deviceName || "").localeCompare(b.deviceName || "")
        })
        return out
    }

    // ── Trackers ─────────────────────────────────────────────────────────
    // Instantiating the models is what makes the services publish them. The
    // delegates hold no UI and cost nothing beyond the objects themselves.
    readonly property Instantiator _devTracker: Instantiator {
        model: Networking.devices
        delegate: QtObject { required property var modelData }
        onObjectAdded: root._rescanDevices()
        onObjectRemoved: root._rescanDevices()
    }

    readonly property Instantiator _netTracker: Instantiator {
        model: root.wifiDevice ? root.wifiDevice.networks : null
        delegate: QtObject {
            required property var modelData
            // Signal strength moves constantly while scanning; the revision is
            // what the radar redraws on.
            readonly property real strength: modelData.signalStrength
            onStrengthChanged: root.netRev++

            readonly property bool joined: modelData.connected
            onJoinedChanged: if (joined) root.activeSsid = modelData.name

            readonly property Connections _failure: Connections {
                target: modelData
                function onConnectionFailed(reason) {
                    root.reportFailure(modelData.name, reason)
                }
            }

            Component.onCompleted: if (modelData.connected) root.activeSsid = modelData.name
        }
        onObjectAdded: root.netRev++
        onObjectRemoved: root.netRev++
    }

    readonly property Instantiator _btTracker: Instantiator {
        model: Bluetooth.devices
        delegate: QtObject {
            required property var modelData
            readonly property int state: modelData.state
            onStateChanged: root.btRev++
        }
        onObjectAdded: root.btRev++
        onObjectRemoved: root.btRev++
    }

    // ── Keybind channel ──────────────────────────────────────────────────
    // "<screen>|<view>|<nanoseconds>", written by scripts/sonar-toggle.sh.
    property string _lastToggle: ""
    // The file outlives the shell: read at startup, a toggle written by the
    // previous instance would open the panel on its own. Same guard as
    // SnipState: anything stamped before this shell started is ignored.
    readonly property real _startupMs: Date.now()
    readonly property FileView _toggleReader: FileView {
        path: "/tmp/qs-sonar-toggle"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            var content = text().trim()
            if (content === "" || content === root._lastToggle) return
            root._lastToggle = content
            var parts = content.split("|")
            var stampMs = parseFloat(parts[parts.length - 1]) / 1e6
            if (!isFinite(stampMs) || stampMs < root._startupMs) return
            root.toggleFrom(parts[0] || "", parts[1] === "bt" ? "bt" : "net")
        }
    }
}
