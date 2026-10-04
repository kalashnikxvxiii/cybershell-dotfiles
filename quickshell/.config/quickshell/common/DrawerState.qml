import Quickshell

PersistentProperties {
    id: root

    property bool dashboardOpen: false
    property bool dockOpen: false           // hover on the dock strip, per screen

    function toggleDashboard() { dashboardOpen = !dashboardOpen }
    function closeAll() {
        dashboardOpen = false
    }
}