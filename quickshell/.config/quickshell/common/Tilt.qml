// Tilt.qml -- a whole Item tilted in perspective, like a HUD printed on a visor.
// Everything inside keeps working: bindings, mouse areas, CutShape, Text.
//      transform: Tilt { w: width; h: height; yaw: -24; pitch: -6; roll: 1.6 }
import QtQuick

Matrix4x4 {
    property real w: 0
    property real h: 0
    property real yaw: 0
    property real pitch: 0
    property real roll: 0
    property real focal: 1200

    function _mul(a, b) {
        const r = []
        for (let i = 0; i < 4; i++)
            for (let j = 0; j < 4; j++) {
                let s = 0
                for (let k = 0; k < 4; k++) s += a[i * 4 + k] * b[k * 4 + j]
                r.push(s)
            }
        return r
    }

    matrix: {
        const d = Math.PI / 180
        const cy = Math.cos(yaw * d), sy = Math.sin(yaw * d)
        const cp = Math.cos(pitch * d), sp = Math.sin(pitch * d)
        const cr = Math.cos(roll * d), sr = Math.sin(roll * d)
        const toOrigin = [1,0,0,-w/2, 0,1,0,-h/2, 0,0,1,0, 0,0,0,1]
        const ry = [cy,0,sy,0, 0,1,0,0, -sy,0,cy,0, 0,0,0,1]
        const rx = [1,0,0,0, 0,cp,-sp,0, 0,sp,cp,0, 0,0,0,1]
        const rz = [cr,-sr,0,0, sr,cr,0,0, 0,0,1,0, 0,0,0,1]
        const persp = [1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,-1/focal,1]
        const back = [1,0,0,w/2, 0,1,0,h/2, 0,0,1,0, 0,0,0,1]
        let m = _mul(back, _mul(persp, _mul(rz, _mul(rx, _mul(ry, toOrigin)))))
        // Flatten z (w keeps the perspective): otherwise whatever rotates out of the
        // renderer's depth range gets clipped away, and half the panel disappears
        return Qt.matrix4x4(m[0],m[1],m[2],m[3], m[4],m[5],m[6],m[7], 0,0,0,0, m[12],m[13],m[14],m[15])
    }
}
