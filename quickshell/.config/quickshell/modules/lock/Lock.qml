// Lock.qml -- the session lock: one LockSurface per screen while LockState.locked
import Quickshell
import Quickshell.Wayland
import "../../common"

Scope {
    WlSessionLock {
        locked: LockState.locked

        WlSessionLockSurface {
            id: surface
            color: "black"
            LockSurface {
                anchors.fill: parent
                screen: surface.screen
            }
        }
    }
}
