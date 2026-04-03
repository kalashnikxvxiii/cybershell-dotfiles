import Quickshell

PersistentProperties {
    id: root

    property bool dashboardOpen: false

    function toggleDashboard() { dashboardOpen = !dashboardOpen }
    function closeAll() {
        dashboardOpen = false
    }
}