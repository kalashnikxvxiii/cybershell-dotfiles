// CutShape.qml — Shape riutilizzabile con angoli tagliati o arrotondati configurabili
// Rimpiazza Shape + ShapePath + PathLine/PathArc ovunque servono shaped polygons.
//
// Ogni angolo accetta UN solo tipo (cut OPPURE radius, la priorità è cut > radius > square).
//
// Proprietà geometria:
//   cutTopLeft / cutTopRight / cutBottomRight / cutBottomLeft    (default 0, taglio diagonale)
//   radiusTopLeft / radiusTopRight / radiusBottomRight / radiusBottomLeft  (default 0, arco)
//   inset: spostamento verso l'interno del tracciato (0 per fill/mask, strokeWidth/2 per bordo)
//
// Proprietà stile:
//   fillColor   (default "transparent")
//   strokeColor (default "transparent")
//   strokeWidth (default 1)
// 
//
// Lati selettivi (default true):
//      showTop / showRight / showBottom / showLeft
// Esempi d'uso:
//
//   // Dashboard panel (cut TR + BL, 32px)
//   CutShape { anchors.fill: parent; fillColor: Colours.moduleBg
//               cutTopRight: 32; cutBottomLeft: 32 }
//
//   // Sezione left (arc TL+BL r=4, cut BR=8)
//   CutShape { anchors.fill: parent; fillColor: CP.moduleBg; strokeColor: CP.alpha(CP.cyan, 0.35)
//               strokeWidth: 1; inset: 0.5; radiusTopLeft: 4; radiusBottomLeft: 4; cutBottomRight: 8 }
//
//   // Workspace button (cut TR+BL, 4px, fill dinamico)
//   CutShape { anchors.fill: parent; fillColor: ...; strokeColor: ...
//               strokeWidth: 1; inset: 0.5; cutTopRight: 4; cutBottomLeft: 4 }

import QtQuick
import QtQuick.Shapes

Shape {
    id: root

    // Stile
    property color fillColor: "transparent"
    property color strokeColor: "transparent"
    property real strokeWidth: 1
    property real inset: 0

    // Taglio diagonale per angolo (px) — ha priorità su radius
    property real cutTopLeft: 0
    property real cutTopRight: 0
    property real cutBottomRight: 0
    property real cutBottomLeft: 0

    // Arrotondamento per angolo (px) — usato solo se cut dell'angolo è 0
    property real radiusTopLeft: 0
    property real radiusTopRight: 0
    property real radiusBottomRight: 0
    property real radiusBottomLeft: 0

    // Selezione dei lati visibili
    property bool showTop: true
    property bool showRight: true
    property bool showBottom: true
    property bool showLeft: true

    // Path chiuso per il fill
    readonly property string _fillPath: {
        const i   = root.inset
        const w   = root.width  - i
        const h   = root.height - i
        const cTL = root.cutTopLeft
        const cTR = root.cutTopRight
        const cBR = root.cutBottomRight
        const cBL = root.cutBottomLeft
        const rTL = cTL > 0 ? 0 : root.radiusTopLeft
        const rTR = cTR > 0 ? 0 : root.radiusTopRight
        const rBR = cBR > 0 ? 0 : root.radiusBottomRight
        const rBL = cBL > 0 ? 0 : root.radiusBottomLeft

        // Start: top edge, dopo il corner TL
        let d = ""
        if      (cTL > 0) d += `M ${i+cTL} ${i} `
        else if (rTL > 0) d += `M ${i+rTL} ${i} `
        else              d += `M ${i} ${i} `

        // Top edge → corner TR
        if      (cTR > 0) d += `L ${w-cTR} ${i} L ${w} ${i+cTR} `
        else if (rTR > 0) d += `L ${w-rTR} ${i} A ${rTR} ${rTR} 0 0 1 ${w} ${i+rTR} `
        else              d += `L ${w} ${i} `

        // Right edge → corner BR
        if      (cBR > 0) d += `L ${w} ${h-cBR} L ${w-cBR} ${h} `
        else if (rBR > 0) d += `L ${w} ${h-rBR} A ${rBR} ${rBR} 0 0 1 ${w-rBR} ${h} `
        else              d += `L ${w} ${h} `

        // Bottom edge → corner BL
        if      (cBL > 0) d += `L ${i+cBL} ${h} L ${i} ${h-cBL} `
        else if (rBL > 0) d += `L ${i+rBL} ${h} A ${rBL} ${rBL} 0 0 1 ${i} ${h-rBL} `
        else              d += `L ${i} ${h} `

        // Left edge → corner TL (chiude)
        if      (cTL > 0) d += `L ${i} ${i+cTL} L ${i+cTL} ${i} Z`
        else if (rTL > 0) d += `L ${i} ${i+rTL} A ${rTL} ${rTL} 0 0 1 ${i+rTL} ${i} Z`
        else              d += `L ${i} ${i} Z`

        return d
    }

    // Path aperto per lo stroke (usa M per sollevare la penna sui lati nascosti)
    readonly property string _strokePath: {
        const i = root.inset
        const w = root.width - i
        const h = root.height - i
        const cTL = root.cutTopLeft; const cTR = root.cutTopRight
        const cBR = root.cutBottomRight; const cBL = root.cutBottomLeft
        const rTL = cTL > 0? 0 : root.radiusTopLeft
        const rTR = cTR > 0 ? 0 : root.radiusTopRight
        const rBR = cBR > 0 ? 0 : root.radiusBottomRight
        const rBL = cBL > 0 ? 0 : root.radiusBottomLeft

        // Punti di ingresso di ogni lato (exit del corner precedente)
        const tlEx = cTL > 0 ? `${i+cTL} ${i}` : rTL > 0 ? `${i+rTL} ${i}` : `${i} ${i}`
        const trEx = cTR > 0 ? `${w} ${i+cTR}` : rTR > 0 ? `${w} ${i+rTR}` : `${w} ${i}`
        const brEx = cBR > 0 ? `${w-cBR} ${h}` : rBR > 0 ? `${w-rBR} ${h}` : `${w} ${h}`
        const blEx = cBL > 0 ? `${i} ${h-cBL}` : rBL > 0 ? `${i} ${h-rBL}` : `${i} ${h}`

        let d = ""
        let penDown = false

        if (root.showTop) {
            d += `M ${tlEx} `
            if      (cTR > 0) d += `L ${w-cTR} ${i} L ${w} ${i+cTR} `
            else if (rTR > 0) d += `L ${w-rTR} ${i} A ${rTR} ${rTR} 0 0 1 ${w} ${i+rTR} `
            else    d += `L ${w} ${i} `
            penDown = true
        }
        if (root.showRight) {
            if (!penDown) d += `M ${trEx} `
            if      (cBR  > 0)  d += `L ${w} ${h-cBR} L ${w-cBR} ${h} `
            else if (rBR > 0)   d += `L ${w} ${h-rBR} A ${rBR} ${rBR} 0 0 1 ${w-rBR} ${h} `
            else                d += `L ${w} ${h} `
            penDown = true
        } else { penDown = false }
        if (root.showBottom) {
            if (!penDown) d += `M ${brEx} `
            if      (cBL > 0)   d += `L ${i+cBL} ${h} L ${i} ${h-cBL} `
            else if (rBL > 0)   d += `L ${i+rBL} ${h} A ${rBL} ${rBL} 0 0 1 ${i} ${h-rBL} `
            else                d += `L ${i} ${h} `
            penDown = true
        } else { penDown = false }
        if (root.showLeft) {
            if (!penDown) d += `M ${blEx} `
            if      (cTL > 0)   d += `L ${i} ${i+cTL} L ${i+cTL} ${i} `
            else if (rTL > 0)   d += `L ${i} ${i+rTL} ${rTL} 0 0 1 ${i+rTL} ${i} `
            else                d += `L ${i} ${i} `
        }

        return d || "M 0 0"
    }

    // Fill (path chiuso)
    ShapePath {
        fillColor: root.fillColor
        strokeColor: "transparent"
        strokeWidth: 0
        PathSvg { path: root._fillPath }
    }

    // Stroke (path aperto, lati selettivi)
    ShapePath {
        fillColor: "transparent"
        strokeColor: root.strokeColor
        strokeWidth: root.strokeWidth
        PathSvg { path: root._strokePath }
    }

    //     PathSvg {
    //         path: {
    //             const i   = root.inset
    //             const w   = root.width  - i
    //             const h   = root.height - i
    //             const cTL = root.cutTopLeft
    //             const cTR = root.cutTopRight
    //             const cBR = root.cutBottomRight
    //             const cBL = root.cutBottomLeft
    //             const rTL = cTL > 0 ? 0 : root.radiusTopLeft
    //             const rTR = cTR > 0 ? 0 : root.radiusTopRight
    //             const rBR = cBR > 0 ? 0 : root.radiusBottomRight
    //             const rBL = cBL > 0 ? 0 : root.radiusBottomLeft

    //             // Start: top edge, dopo il corner TL
    //             let d = ""
    //             if      (cTL > 0) d += `M ${i+cTL} ${i} `
    //             else if (rTL > 0) d += `M ${i+rTL} ${i} `
    //             else              d += `M ${i} ${i} `

    //             // Top edge → corner TR
    //             if      (cTR > 0) d += `L ${w-cTR} ${i} L ${w} ${i+cTR} `
    //             else if (rTR > 0) d += `L ${w-rTR} ${i} A ${rTR} ${rTR} 0 0 1 ${w} ${i+rTR} `
    //             else              d += `L ${w} ${i} `

    //             // Right edge → corner BR
    //             if      (cBR > 0) d += `L ${w} ${h-cBR} L ${w-cBR} ${h} `
    //             else if (rBR > 0) d += `L ${w} ${h-rBR} A ${rBR} ${rBR} 0 0 1 ${w-rBR} ${h} `
    //             else              d += `L ${w} ${h} `

    //             // Bottom edge → corner BL
    //             if      (cBL > 0) d += `L ${i+cBL} ${h} L ${i} ${h-cBL} `
    //             else if (rBL > 0) d += `L ${i+rBL} ${h} A ${rBL} ${rBL} 0 0 1 ${i} ${h-rBL} `
    //             else              d += `L ${i} ${h} `

    //             // Left edge → corner TL (chiude)
    //             if      (cTL > 0) d += `L ${i} ${i+cTL} L ${i+cTL} ${i} Z`
    //             else if (rTL > 0) d += `L ${i} ${i+rTL} A ${rTL} ${rTL} 0 0 1 ${i+rTL} ${i} Z`
    //             else              d += `L ${i} ${i} Z`

    //             return d
    //         }
    //     }
    }

