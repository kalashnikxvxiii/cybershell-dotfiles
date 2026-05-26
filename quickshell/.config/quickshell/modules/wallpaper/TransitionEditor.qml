import "../../common/Colors.js" as CP
import "../../common"
import "../../common/effects"
import "BezierPresets.js" as Presets
import QtQuick
import QtQuick.Effects

Item {
    id: root
    anchors.fill: parent
    visible: TransitionConfig.editorOpen
    z: 1000

    Rectangle {
        anchors.fill: parent
        color: CP.alpha(CP.void2, 0.78)
        MouseArea { anchors.fill: parent; onClicked: TransitionConfig.editorOpen = false }
    }

    CutShape {
        id: dialog
        anchors.centerIn: parent
        width: 960
        height: 600
        fillColor: CP.alpha(CP.void2, 0.96)
        strokeColor: CP.alpha(CP.yellow, 0.45)
        strokeWidth: 2
        inset: 0.5
        cutTopLeft: 16
        cutBottomRight: 16

        MouseArea { anchors.fill: parent; onClicked: {} }

        ScanlineOverlay { anchors.fill: parent; opacity: 0.05; lineSpacing: 3 }
        CornerAccents {
            anchors.fill: parent; anchors.margins: 8
            accentColor: CP.yellow; size: 14; thickness: 1
            showTopLeft: false
            showBottomRight: false
        }

        // ── Header ──
        Item {
            id: header
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 52

            ChromaticText {
                id: titleText
                anchors.left: parent.left
                anchors.leftMargin: 28
                anchors.verticalCenter: parent.verticalCenter
                text: "TRANSITION EDITOR"
                font.family: "Oxanium"
                font.pixelSize: 16
                font.letterSpacing: 3
                font.bold: true
                color: Colours.accentPrimary
                offsetX: 1.5
                restOpacity: 0.2
                glitching: _titleGlitching
                property bool _titleGlitching: false
            }

            Timer {
                id: titleGlitchTrigger
                interval: 4000 + Math.random() * 5000       // 4-9s gap
                running: TransitionConfig.editorOpen
                repeat: true
                onTriggered: {
                    titleText._titleGlitching = true
                    titleGlitchOff.restart()
                    titleGlitchTrigger.interval = 4000 + Math.random() * 5000
                }
            }

            Timer {
                id: titleGlitchOff
                interval: 120 + Math.random() * 100
                repeat: false
                onTriggered: titleText._titleGlitching = false
            }

            Row {
                anchors.right: closeBtn.left
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                Text { text: "▮▮▮"; color: CP.alpha(CP.yellow, 0.4); font.pixelSize: 7; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "ID:" + TransitionConfig.transitionType.toUpperCase(); color: Colours.textMuted; font.family: "Oxanium"; font.pixelSize: 9; font.letterSpacing: 1.5; anchors.verticalCenter: parent.verticalCenter }
            }

            Item {
                id: closeBtn
                width: 22; height: 22
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                CutShape {
                    anchors.fill: parent
                    fillColor: closeMa.containsMouse ? CP.alpha(CP.red, 0.20) : CP.alpha(CP.red, 0.08)
                    strokeColor: CP.alpha(CP.red, 0.55)
                    strokeWidth: 1; inset: 0.5; cutBottomLeft: 4
                    Behavior on fillColor { ColorAnimation { duration: 120 } }
                }
                Text { anchors.centerIn: parent; text: "\u2715"; font.pixelSize: 12; color: Colours.accentDanger }
                MouseArea {
                    id: closeMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: TransitionConfig.editorOpen = false
                }
            }
        }

        Rectangle {
            id: headerSep
            anchors.top: header.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: CP.alpha(CP.yellow, 0.25)
        }

        // ── Body 3 colonne ──
        Item {
            id: body
            anchors.top: headerSep.bottom
            anchors.bottom: statusBar.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 18
            anchors.bottomMargin: 8

            Row {
                anchors.fill: parent
                spacing: 12

                // ── COL 1 — TYPE + TIMING (stacked, scrollable se overflow) ──
                Item {
                    width: 300
                    height: parent.height

                    CutShape {
                        anchors.fill: parent
                        fillColor: CP.alpha(CP.void2, 0.45)
                        strokeColor: CP.alpha(CP.yellow, 0.20)
                        strokeWidth: 1; inset: 0.5; cutTopLeft: 12
                    }

                    Flickable {
                        id: col1Scroll
                        anchors.fill: parent
                        anchors.margins: 14
                        clip: true
                        contentHeight: col1Content.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds

                        Column {
                            id: col1Content
                            width: col1Scroll.width
                            spacing: 14

                            // TYPE header
                            Row {
                                spacing: 6
                                Text { text: "▸"; color: Colours.accentPrimary; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: "TYPE"; font.family: "Oxanium"; font.pixelSize: 11; font.letterSpacing: 3; font.bold: true; color: Colours.accentPrimary; anchors.verticalCenter: parent.verticalCenter }
                            }
                            TypeSelector {
                                width: parent.width
                                selectedType: TransitionConfig.transitionType
                                onTypeSelected: function(t) { TransitionConfig.transitionType = t }
                            }

                            // Separator
                            Rectangle { width: parent.width; height: 1; color: CP.alpha(CP.yellow, 0.18) }

                            // TIMING header
                            Row {
                                spacing: 6
                                Text { text: "▸"; color: Colours.accentSecondary; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: "TIMING"; font.family: "Oxanium"; font.pixelSize: 11; font.letterSpacing: 3; font.bold: true; color: Colours.accentSecondary; anchors.verticalCenter: parent.verticalCenter }
                            }
                            NumericField {
                                width: parent.width
                                label: "Duration"; suffix: "s"
                                value: TransitionConfig.transitionDuration
                                minValue: 0; maxValue: 60; decimals: 2; isInt: false
                                onValueEdited: function(v) { TransitionConfig.transitionDuration = v }
                            }
                            NumericField {
                                width: parent.width
                                label: "FPS"
                                value: TransitionConfig.transitionFps
                                minValue: 1; maxValue: 240; isInt: true
                                onValueEdited: function(v) { TransitionConfig.transitionFps = v }
                            }
                            NumericField {
                                width: parent.width
                                label: "Step"
                                value: TransitionConfig.transitionStep
                                minValue: 1; maxValue: 255; isInt: true
                                onValueEdited: function(v) { TransitionConfig.transitionStep = v }
                            }

                            // ── ANGLE (wipe, wave) ──
                            Rectangle {
                                visible: angleSec.visible
                                width: parent.width; height: 1
                                color: CP.alpha(CP.yellow, 0.15)
                            }
                            Column {
                                id: angleSec
                                width: parent.width
                                spacing: 8
                                visible: TransitionConfig.transitionType === "wipe"
                                    || TransitionConfig.transitionType === "wave"

                                Row {
                                    spacing: 6
                                    Text { text: "▸"; color: Colours.accentPrimary; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: "ANGLE"; font.family: "Oxanium"; font.pixelSize: 10; font.letterSpacing: 2.5; font.bold: true; color: Colours.accentPrimary; anchors.verticalCenter: parent.verticalCenter }
                                }
                                Slider {
                                    width: parent.width
                                    label: ""
                                    suffix: "°"
                                    value: TransitionConfig.transitionAngle
                                    minValue: 0; maxValue: 359; isInt: true
                                    onValueEdited: function(v) { TransitionConfig.transitionAngle = v }
                                }
                                AngleIndicator {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    angle: TransitionConfig.transitionAngle
                                }
                            }

                            // ── POSITION (grow, outer) ──
                            Rectangle {
                                visible: posSec.visible
                                width: parent.width; height: 1
                                color: CP.alpha(CP.magenta, 0.15)
                            }
                            Column {
                                id: posSec
                                width: parent.width
                                spacing: 8
                                visible: TransitionConfig.transitionType === "grow"
                                    || TransitionConfig.transitionType === "outer"

                                Row {
                                    spacing: 6
                                    Text { text: "▸"; color: Colours.accentMem; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: "POSITION"; font.family: "Oxanium"; font.pixelSize: 10; font.letterSpacing: 2.5; font.bold: true; color: Colours.accentMem; anchors.verticalCenter: parent.verticalCenter }
                                }
                                PositionPicker {
                                    width: parent.width
                                    height: 130
                                    pos: TransitionConfig.transitionPos
                                    onPosEdited: function(s) { TransitionConfig.transitionPos = s }
                                }
                            }

                            // ── WAVE (wave) ──
                            Rectangle {
                                visible: waveSec.visible
                                width: parent.width; height: 1
                                color: CP.alpha(CP.neon, 0.15)
                            }
                            Column {
                                id: waveSec
                                width: parent.width
                                spacing: 8
                                visible: TransitionConfig.transitionType === "wave"

                                property real _amp: 20
                                property real _per: 20

                                function _refresh() {
                                    var p = TransitionConfig.transitionWave.split(",")
                                    _amp = p.length === 2 ? (parseFloat(p[0]) || 20) : 20
                                    _per = p.length === 2 ? (parseFloat(p[1]) || 20) : 20
                                }
                                Connections {
                                    target: TransitionConfig
                                    function onTransitionWaveChanged() { waveSec._refresh() }
                                }
                                Component.onCompleted: _refresh()

                                Row {
                                    spacing: 6
                                    Text { text: "▸"; color: Colours.accentOk; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: "WAVE"; font.family: "Oxanium"; font.pixelSize: 10; font.letterSpacing: 2.5; font.bold: true; color: Colours.accentOk; anchors.verticalCenter: parent.verticalCenter }
                                }
                                NumericField {
                                    width: parent.width
                                    label: "Amplitude"
                                    value: waveSec._amp
                                    minValue: 0; maxValue: 200; decimals: 1; isInt: false
                                    onValueEdited: function(v) {
                                        TransitionConfig.transitionWave = v.toFixed(1) + "," + waveSec._per.toFixed(1)
                                    }
                                }
                                NumericField {
                                    width: parent.width
                                    label: "Period"
                                    value: waveSec._per
                                    minValue: 1; maxValue: 500; decimals: 1; isInt: false
                                    onValueEdited: function(v) {
                                        TransitionConfig.transitionWave = waveSec._amp.toFixed(1) + "," + v.toFixed(1)
                                    }
                                }
                            }
                        }
                    }

                    // Subtle scrollbar (visible only when overflow)
                    Rectangle {
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                        anchors.margins: 4
                        width: 2
                        color: CP.alpha(CP.yellow, 0.10)
                        visible: col1Scroll.contentHeight > col1Scroll.height

                        Rectangle {
                            width: parent.width
                            y: col1Scroll.contentHeight > 0
                                ? (col1Scroll.contentY / col1Scroll.contentHeight) * parent.height
                                : 0
                            height: col1Scroll.contentHeight > 0
                                ? Math.max(20, (col1Scroll.height / col1Scroll.contentHeight) * parent.height)
                                : parent.height
                            color: CP.alpha(CP.yellow, 0.55)
                            Behavior on y { NumberAnimation { duration: 80 } }
                        }
                    }
                }

                // ── COL 2 — CURVE + PRESETS ──
                Item {
                    width: 300
                    height: parent.height

                    CutShape {
                        anchors.fill: parent
                        fillColor: CP.alpha(CP.void2, 0.45)
                        strokeColor: CP.alpha(CP.yellow, 0.20)
                        strokeWidth: 1; inset: 0.5
                    }

                    Item {
                        id: curveHeader
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.topMargin: 14
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        height: 22

                        Row {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6

                            Text { text: "▸"; color: Colours.accentPrimary; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "CURVE"; font.family: "Oxanium"; font.pixelSize: 11; font.letterSpacing: 3; font.bold: true; color: Colours.accentPrimary; anchors.verticalCenter: parent.verticalCenter }
                            Text {
                                text: "/ FADE ONLY"
                                font.family: "Oxanium"; font.pixelSize: 8; font.letterSpacing: 1.5
                                color: CP.alpha(CP.yellow, 0.4)
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6

                            // SHIFT hint
                            Row {
                                spacing: 3
                                anchors.verticalCenter: parent.verticalCenter

                                CutShape {
                                    width: 32; height: 18
                                    fillColor: CP.alpha(CP.void2, 0.6)
                                    strokeColor: CP.alpha(CP.yellow, 0.4)
                                    strokeWidth: 1; inset: 0.5
                                    cutBottomRight: 3
                                    anchors.verticalCenter: parent.verticalCenter

                                    Text { anchors.centerIn: parent; text: "SHIFT"; font.family: "Oxanium"; font.pixelSize: 8; font.letterSpacing: 0.5; font.bold: true; color: Colours.accentPrimary }
                                }

                                Text {
                                    text: "SNAP"
                                    font.family: "Oxanium"
                                    font.pixelSize: 9
                                    font.letterSpacing: 1.2
                                    color: Colours.textMuted
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            // Mirror
                            Item {
                                width: 22; height: 18

                                CutShape {
                                    anchors.fill: parent
                                    fillColor: mirrorMa.containsMouse ? CP.alpha(CP.magenta, 0.25) : CP.alpha(CP.magenta, 0.08)
                                    strokeColor: CP.alpha(CP.magenta, 0.55)
                                    strokeWidth: 1; inset: 0.5; cutBottomRight: 3
                                    Behavior on fillColor { ColorAnimation { duration: 120 } }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: "⇋"
                                    font.pixelSize: 12
                                    color: Colours.accentMem
                                }

                                MouseArea {
                                    id: mirrorMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: TransitionConfig.mirrorBezier()
                                }
                            }

                            // Reset
                            Item {
                                width: 22; height: 18

                                CutShape {
                                    anchors.fill: parent
                                    fillColor: resetMa.containsMouse ? CP.alpha(CP.cyan, 0.25) : CP.alpha(CP.cyan, 0.08)
                                    strokeColor: CP.alpha(CP.cyan, 0.55)
                                    strokeWidth: 1; inset: 0.5; cutBottomRight: 3
                                    Behavior on fillColor { ColorAnimation { duration: 120 } }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: "↺"
                                    font.pixelSize: 12
                                    color: Colours.accentSecondary
                                }

                                MouseArea {
                                    id: resetMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: TransitionConfig.resetBezier()
                                }
                            }
                        }
                    }

                    Item {
                        id: bezierWrap
                        anchors.top: curveHeader.bottom
                        anchors.topMargin: 10
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 240
                        BezierCanvas {
                            width: 240; height: 240
                            anchors.horizontalCenter: parent.horizontalCenter
                            bezier: TransitionConfig.transitionBezier
                            onBezierEdited: function(s) { TransitionConfig.transitionBezier = s }
                        }
                    }
                    Item {
                        id: presetsHeader
                        anchors.top: bezierWrap.bottom
                        anchors.topMargin: 10
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        height: 24

                        property bool _saving: false
                        readonly property bool _matchesAnyPreset: {
                            var b = TransitionConfig.transitionBezier
                            if (Presets.matchesAnyBuiltin(b)) return true
                            var up = TransitionConfig.userPresets
                            for (var i = 0; i < up.length; i++) {
                                if (Presets.tolerantMatch(b, up[i])) return true
                            }
                            return false
                        }

                        // Default: header + +SAVE button
                        Row {
                            visible: !presetsHeader._saving
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6

                            Text { text: "▸"; color: Colours.accentSecondary; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "PRESETS"; font.family: "Oxanium"; font.pixelSize: 10; font.letterSpacing: 2.5; font.bold: true; color: Colours.accentSecondary; anchors.verticalCenter: parent.verticalCenter }
                            Text {
                                text: presetsScroll.contentHeight > presetsScroll.height ? "/ SCROLL ↓" : ""
                                font.family: "Oxanium"; font.pixelSize: 7; font.letterSpacing: 1.5
                                color: CP.alpha(CP.cyan, 0.5)
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Item {
                            id: saveBtn
                            visible: !presetsHeader._saving && !presetsHeader._matchesAnyPreset
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 70; height: 20

                            CutShape {
                                anchors.fill: parent
                                fillColor: saveBtnMa.containsMouse ? CP.alpha(CP.neon, 0.22) : CP.alpha(CP.neon, 0.10)
                                strokeColor: CP.alpha(CP.neon, 0.6)
                                strokeWidth: 1; inset: 0.5
                                cutTopLeft: 3
                                Behavior on fillColor { ColorAnimation { duration: 120 } }
                            }
                            Row {
                                anchors.centerIn: parent
                                spacing: 3
                                Text { text: "+"; font.family: "Oxanium"; font.pixelSize: 11; font.bold: true; color: Colours.accentOk; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: "SAVE"; font.family: "Oxanium"; font.pixelSize: 8; font.letterSpacing: 1.5; font.bold: true; color: Colours.accentOk; anchors.verticalCenter: parent.verticalCenter }
                            }
                            MouseArea {
                                id: saveBtnMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    presetsHeader._saving = true
                                    nameInput.text = ""
                                    nameInput.forceActiveFocus()
                                }
                            }
                        }

                        // Editing: name input + confirm + cancel
                        Item {
                            visible: presetsHeader._saving
                            anchors.fill: parent

                            CutShape {
                                id: inputBg
                                anchors.left: parent.left
                                anchors.right: confirmBtn.left
                                anchors.rightMargin: 4
                                height: 22
                                anchors.verticalCenter: parent.verticalCenter
                                fillColor: CP.alpha(CP.void2, 0.7)
                                strokeColor: CP.alpha(CP.neon, 0.7)
                                strokeWidth: 1; inset: 0.5
                                cutTopLeft: 2; cutBottomRight: 2
                            }
                            TextInput {
                                id: nameInput
                                anchors.left: inputBg.left
                                anchors.right: inputBg.right
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                anchors.verticalCenter: inputBg.verticalCenter
                                verticalAlignment: TextInput.AlignVCenter
                                font.family: "Oxanium"
                                font.pixelSize: 9
                                font.letterSpacing: 0.5
                                color: Colours.textPrimary
                                selectByMouse: true
                                maximumLength: 24

                                onAccepted: {
                                    if (text.trim() !== "") TransitionConfig.saveCurrentAsPreset(text.trim())
                                    text = ""
                                    presetsHeader._saving = false
                                }
                                Keys.onEscapePressed: function(event) {
                                    text = ""
                                    presetsHeader._saving = false
                                    event.accepted = true
                                }
                            }

                            Item {
                                id: confirmBtn
                                width: 22; height: 22
                                anchors.right: cancelBtn.left
                                anchors.rightMargin: 4
                                anchors.verticalCenter: parent.verticalCenter

                                CutShape {
                                    anchors.fill: parent
                                    fillColor: confirmMa.containsMouse ? CP.alpha(CP.neon, 0.3) : CP.alpha(CP.neon, 0.15)
                                    strokeColor: CP.alpha(CP.neon, 0.7)
                                    strokeWidth: 1; inset: 0.5
                                    cutTopLeft: 2; cutBottomRight: 2
                                    Behavior on fillColor { ColorAnimation { duration: 120 } }
                                }
                                Text {
                                    anchors.centerIn: parent
                                    text: "✓"
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: Colours.accentOk
                                }
                                MouseArea {
                                    id: confirmMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (nameInput.text.trim() !== "") TransitionConfig.saveCurrentAsPreset(nameInput.text.trim())
                                        nameInput.text = ""
                                        presetsHeader._saving = false
                                    }
                                }
                            }

                            Item {
                                id: cancelBtn
                                width: 22; height: 22
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter

                                CutShape {
                                    anchors.fill: parent
                                    fillColor: cancelMa.containsMouse ? CP.alpha(CP.red, 0.3) : CP.alpha(CP.red, 0.10)
                                    strokeColor: CP.alpha(CP.red, 0.6)
                                    strokeWidth: 1; inset: 0.5
                                    cutTopLeft: 2; cutBottomRight: 2
                                    Behavior on fillColor { ColorAnimation { duration: 120 } }
                                }
                                Text {
                                    anchors.centerIn: parent
                                    text: "✕"
                                    font.pixelSize: 10
                                    color: Colours.accentDanger
                                }
                                MouseArea {
                                    id: cancelMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        nameInput.text = ""
                                        presetsHeader._saving = false
                                    }
                                }
                            }
                        }
                    }

                    Flickable {
                        id: presetsScroll
                        anchors.top: presetsHeader.bottom
                        anchors.topMargin: 8
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: 14
                        anchors.rightMargin: 20
                        anchors.bottomMargin: 14
                        clip: true
                        contentHeight: presetGrid.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds
                        flickDeceleration: 8000

                        PresetGrid {
                            id: presetGrid
                            width: presetsScroll.width
                            currentBezier: TransitionConfig.transitionBezier
                            onPresetSelected: function(s) { TransitionConfig.transitionBezier = s }
                        }
                    }
                    Rectangle {
                        anchors.top: presetsScroll.top
                        anchors.left: presetsScroll.left
                        anchors.right: presetsScroll.right
                        height: 14
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: CP.alpha(CP.void2, 0.92) }
                            GradientStop { position: 1.0; color: CP.alpha(CP.void2, 0.0) }
                        }
                        opacity: presetsScroll.contentY > 4 ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }
                    Rectangle {
                        anchors.bottom: presetsScroll.bottom
                        anchors.left: presetsScroll.left
                        anchors.right: presetsScroll.right
                        height: 14
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: CP.alpha(CP.void2, 0.0) }
                            GradientStop { position: 1.0; color: CP.alpha(CP.void2, 0.92) }
                        }
                        opacity: (presetsScroll.contentHeight - presetsScroll.height - presetsScroll.contentY) > 4 ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }
                    Item {
                        anchors.top: presetsScroll.top
                        anchors.bottom: presetsScroll.bottom
                        anchors.right: parent.right
                        anchors.rightMargin: 6
                        width: 3
                        visible: presetsScroll.contentHeight > presetsScroll.height
                        Rectangle { anchors.fill: parent; color: CP.alpha(CP.yellow, 0.10) }
                        Rectangle {
                            width: parent.width
                            y: presetsScroll.contentHeight > 0
                                ? (presetsScroll.contentY / presetsScroll.contentHeight) * parent.height
                                : 0
                            height: presetsScroll.contentHeight > 0
                                ? Math.max(20, (presetsScroll.height / presetsScroll.contentHeight) * parent.height)
                                : parent.height
                            color: CP.alpha(CP.yellow, 0.55)
                            Behavior on y { NumberAnimation { duration: 80 } }
                        }
                    }
                }

                // ── COL 3 — PREVIEW ──
                Item {
                    width: 300
                    height: parent.height

                    CutShape {
                        anchors.fill: parent
                        fillColor: CP.alpha(CP.void2, 0.45)
                        strokeColor: CP.alpha(CP.neon, 0.25)
                        strokeWidth: 1; inset: 0.5
                    }

                    PreviewPane {
                        anchors.fill: parent
                        anchors.margins: 14
                    }
                }
            }
        }

        // ── Toast feedback ──────
        Item {
            id: toast
            anchors.bottom: statusBar.top
            anchors.bottomMargin: 12
            anchors.horizontalCenter: parent.horizontalCenter
            width: toastBg.width
            height: 24
            opacity: 0
            z: 100

            property string message:    ""
            property color accent:      CP.neon

            CutShape {
                id: toastBg
                height: parent.height
                width: toastText.implicitWidth + 32
                anchors.centerIn: parent
                fillColor: CP.alpha(toast.accent, 0.20)
                strokeColor: toast.accent
                strokeWidth: 1.5
                inset: 0.5
                cutTopLeft: 4
                cutBottomRight: 4
            }
            Text {
                id: toastText
                anchors.centerIn: parent
                text: toast.message
                font.family: "Oxanium"
                font.pixelSize: 9
                font.letterSpacing: 2
                font.bold: true
                color: toast.accent
            }

            function show(msg, color) {
                message = msg
                accent = color
                toastAnim.restart()
            }

            SequentialAnimation {
                id: toastAnim
                NumberAnimation { target: toast; property: "opacity"; from: 0; to: 1; duration: 120 }
                PauseAnimation { duration: 900 }
                NumberAnimation { target: toast; property: "opacity"; from: 1; to: 0; duration: 280 }
            }
        }

        Connections {
            target: TransitionConfig
            function onSaved()      { toast.show("⬢ SAVED", CP.neon) }
            function onReverted()   { toast.show("↺ REVERTED", CP.cyan) }
        }

        // ── Status bar ──
        Item {
            id: statusBar
            anchors.bottom: footerSep.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            anchors.bottomMargin: 8
            height: 28
            CutShape {
                anchors.fill: parent
                fillColor: CP.alpha(CP.void2, 0.55)
                strokeColor: CP.alpha(CP.neon, 0.25)
                strokeWidth: 1; inset: 0.5; cutBottomRight: 12
            }
            Row {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                // Dirty state LED + label
                Rectangle {
                    width: 8; height: 8
                    color: TransitionConfig.isDirty ? CP.amber : CP.neon
                    anchors.verticalCenter: parent.verticalCenter
                    SequentialAnimation on opacity {
                        running: TransitionConfig.isDirty
                        loops: Animation.Infinite
                        NumberAnimation { from: 1.0; to: 0.4; duration: 600 }
                        NumberAnimation { from: 0.4; to: 1.0; duration: 600 }
                    }
                }

                Text {
                    text: TransitionConfig.isDirty ? "UNSAVED" : "SYNCED"
                    font.family: "Oxanium"
                    font.pixelSize: 8
                    font.letterSpacing: 2
                    font.bold: true
                    color: TransitionConfig.isDirty ? Colours.accentWarn : Colours.accentOk
                    anchors.verticalCenter: parent.verticalCenter
                }
                Rectangle { width: 1; height: 12; color: CP.alpha(CP.yellow, 0.3); anchors.verticalCenter: parent.verticalCenter }

                Text { text: "⬢"; color: CP.neon; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "ACTIVE"; font.family: "Oxanium"; font.pixelSize: 8; font.letterSpacing: 2; color: Colours.textMuted; anchors.verticalCenter: parent.verticalCenter }
                Rectangle { width: 1; height: 12; color: CP.alpha(CP.yellow, 0.3); anchors.verticalCenter: parent.verticalCenter }
                Text { text: TransitionConfig.transitionType.toUpperCase(); font.family: "Oxanium"; font.pixelSize: 9; font.letterSpacing: 1.5; font.bold: true; color: Colours.accentPrimary; anchors.verticalCenter: parent.verticalCenter }
                Rectangle { width: 1; height: 12; color: CP.alpha(CP.yellow, 0.3); anchors.verticalCenter: parent.verticalCenter }
                Text { text: TransitionConfig.transitionDuration.toFixed(2) + "s"; font.family: "Oxanium"; font.pixelSize: 9; color: Colours.textPrimary; anchors.verticalCenter: parent.verticalCenter }
                Rectangle { width: 1; height: 12; color: CP.alpha(CP.yellow, 0.3); anchors.verticalCenter: parent.verticalCenter }
                Text { text: TransitionConfig.transitionFps + "FPS"; font.family: "Oxanium"; font.pixelSize: 9; color: Colours.textPrimary; anchors.verticalCenter: parent.verticalCenter }
                Rectangle { width: 1; height: 12; color: CP.alpha(CP.yellow, 0.3); anchors.verticalCenter: parent.verticalCenter }
                Text { text: "STEP " + TransitionConfig.transitionStep; font.family: "Oxanium"; font.pixelSize: 9; color: Colours.textPrimary; anchors.verticalCenter: parent.verticalCenter }
                Rectangle { width: 1; height: 12; color: CP.alpha(CP.yellow, 0.3); anchors.verticalCenter: parent.verticalCenter }
                Text { text: "BEZIER " + TransitionConfig.transitionBezier; font.family: "Oxanium"; font.pixelSize: 8; color: Colours.textMuted; anchors.verticalCenter: parent.verticalCenter }
            }
        }

        Rectangle {
            id: footerSep
            anchors.bottom: footer.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: CP.alpha(CP.yellow, 0.25)
        }

        // ── Footer ──
        Item {
            id: footer
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 52

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 24
                anchors.verticalCenter: parent.verticalCenter
                spacing: 16
                Row {
                    spacing: 5
                    CutShape {
                        width: 22; height: 16
                        fillColor: CP.alpha(CP.void2, 0.6)
                        strokeColor: CP.alpha(CP.yellow, 0.45)
                        strokeWidth: 1; inset: 0.5; cutBottomRight: 3
                        anchors.verticalCenter: parent.verticalCenter
                        Text { anchors.centerIn: parent; text: "A"; font.family: "Oxanium"; font.pixelSize: 9; font.bold: true; color: Colours.accentPrimary }
                    }
                    Text { text: "TOGGLE"; font.family: "Oxanium"; font.pixelSize: 8; font.letterSpacing: 1.5; color: Colours.textMuted; anchors.verticalCenter: parent.verticalCenter }
                }
                Row {
                    spacing: 5
                    CutShape {
                        width: 26; height: 16
                        fillColor: CP.alpha(CP.void2, 0.6)
                        strokeColor: CP.alpha(CP.red, 0.45)
                        strokeWidth: 1; inset: 0.5; cutBottomRight: 3
                        anchors.verticalCenter: parent.verticalCenter
                        Text { anchors.centerIn: parent; text: "ESC"; font.family: "Oxanium"; font.pixelSize: 7; font.bold: true; color: Colours.accentDanger }
                    }
                    Text { text: "CLOSE"; font.family: "Oxanium"; font.pixelSize: 8; font.letterSpacing: 1.5; color: Colours.textMuted; anchors.verticalCenter: parent.verticalCenter }
                }
                Row {
                    spacing: 5
                    CutShape {
                        width: 38; height: 16
                        fillColor: CP.alpha(CP.void2, 0.6)
                        strokeColor: CP.alpha(CP.yellow, 0.45)
                        strokeWidth: 1; inset: 0.5; cutBottomRight: 3
                        anchors.verticalCenter: parent.verticalCenter
                        Text { anchors.centerIn: parent; text: "⌃S"; font.family: "Oxanium"; font.pixelSize: 8; font.bold: true; color: Colours.accentPrimary }
                    }
                    Text { text: "SAVE"; font.family: "Oxanium"; font.pixelSize: 8; font.letterSpacing: 1.5; color: Colours.textMuted; anchors.verticalCenter: parent.verticalCenter }
                }
                Row {
                    spacing: 5
                    CutShape {
                        width: 38; height: 16
                        fillColor: CP.alpha(CP.void2, 0.6)
                        strokeColor: CP.alpha(CP.cyan, 0.45)
                        strokeWidth: 1; inset: 0.5; cutBottomRight: 3
                        anchors.verticalCenter: parent.verticalCenter
                        Text { anchors.centerIn: parent; text: "⌃Z"; font.family: "Oxanium"; font.pixelSize: 8; font.bold: true; color: Colours.accentSecondary }
                    }
                    Text { text: "REVERT"; font.family: "Oxanium"; font.pixelSize: 8; font.letterSpacing: 1.5; color: Colours.textMuted; anchors.verticalCenter: parent.verticalCenter }
                }
                Row {
                    spacing: 5
                    CutShape {
                        width: 22; height: 16
                        fillColor: CP.alpha(CP.void2, 0.6)
                        strokeColor: CP.alpha(CP.neon, 0.45)
                        strokeWidth: 1; inset: 0.5; cutBottomRight: 3
                        anchors.verticalCenter: parent.verticalCenter
                        Text { anchors.centerIn: parent; text: "R"; font.family: "Oxanium"; font.pixelSize: 9; font.bold: true; color: Colours.accentOk }
                    }
                    Text { text: "REPLAY"; font.family: "Oxanium"; font.pixelSize: 8; font.letterSpacing: 1.5; color: Colours.textMuted; anchors.verticalCenter: parent.verticalCenter }
                }
                Row {
                    spacing: 5
                    CutShape {
                        width: 46; height: 16
                        fillColor: CP.alpha(CP.void2, 0.6)
                        strokeColor: CP.alpha(CP.yellow, 0.45)
                        strokeWidth: 1; inset: 0.5; cutBottomRight: 3
                        anchors.verticalCenter: parent.verticalCenter
                        Text { anchors.centerIn: parent; text: "←→"; font.family: "Oxanium"; font.pixelSize: 9; font.bold: true; color: Colours.accentPrimary }
                    }
                    Text { text: "TYPE"; font.family: "Oxanium"; font.pixelSize: 8; font.letterSpacing: 1.5; color: Colours.textMuted; anchors.verticalCenter: parent.verticalCenter }
                }
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 24
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                Item {
                    id: revertButton
                    width: 102; height: 30

                    property bool _flash: false

                    CutShape {
                        anchors.fill: parent
                        fillColor: revertButton._flash
                        ? CP.alpha(CP.cyan, 0.6)
                        : (revertMa.containsMouse ? CP.alpha(CP.cyan, 0.20) : CP.alpha(CP.cyan, 0.08))
                        strokeColor: CP.alpha(CP.cyan, 0.6)
                        strokeWidth: 1; inset: 0.5; cutTopLeft: 4; cutBottomRight: 4
                        Behavior on fillColor { ColorAnimation { duration: 80 } }
                    }
                    Row {
                        anchors.centerIn: parent
                        spacing: 5
                        Text { text: "↺"; font.pixelSize: 12; color: Colours.accentSecondary; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "REVERT"; font.family: "Oxanium"; font.pixelSize: 10; font.letterSpacing: 2; color: Colours.accentSecondary; anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea { id: revertMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: TransitionConfig.revert() }

                    SequentialAnimation {
                        id: revertFlash
                        running: false
                        PropertyAction { target: revertButton; property: "_flash"; value: true }
                        PauseAnimation { duration: 100 }
                        PropertyAction { target: revertButton; property: "_flash"; value: false }
                        PauseAnimation { duration: 60 }
                        PropertyAction { target: revertButton; property: "_flash"; value: true }
                        PauseAnimation { duration: 80 }
                        PropertyAction { target: revertButton; property: "_flash"; value: false }
                    }

                    Connections {
                        target: TransitionConfig
                        function onReverted() { revertFlash.restart() }
                    }
                }

                Item {
                    id: saveButton
                    width: 102; height: 30

                    property bool _flash: false

                    CutShape {
                        anchors.fill: parent
                        fillColor: saveButton._flash
                                ? CP.alpha(CP.yellow, 0.95)
                                : (saveMa.containsMouse ? CP.alpha(CP.yellow, 0.38) : CP.alpha(CP.yellow, 0.24))
                        strokeColor: CP.alpha(CP.yellow, 0.95)
                        strokeWidth: 1.5; inset: 0.5; cutTopLeft: 4; cutBottomRight: 4
                        Behavior on fillColor { ColorAnimation { duration: 80 } }
                        layer.enabled: saveMa.containsMouse || saveButton._flash
                        layer.effect: MultiEffect {
                            shadowEnabled: true; shadowBlur: 1.0
                            shadowColor: CP.yellow; shadowOpacity: 0.5
                            shadowHorizontalOffset: 0; shadowVerticalOffset: 0
                        }
                    }
                    Row {
                        anchors.centerIn: parent
                        spacing: 5
                        Text { text: "⬢"; font.pixelSize: 11; color: Colours.accentPrimary; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "SAVE"; font.family: "Oxanium"; font.pixelSize: 10; font.letterSpacing: 2; font.bold: true; color: Colours.accentPrimary; anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea { id: saveMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: TransitionConfig.save() }

                    SequentialAnimation {
                        id: saveFlash
                        running: false
                        PropertyAction { target: saveButton; property: "_flash"; value: true }
                        PauseAnimation { duration: 100 }
                        PropertyAction { target: saveButton; property: "_flash"; value: false }
                        PauseAnimation { duration: 60 }
                        PropertyAction { target: saveButton; property: "_flash"; value: true }
                        PauseAnimation { duration: 80 }
                        PropertyAction { target: saveButton; property: "_flash"; value: false }
                    }

                    Connections {
                        target: TransitionConfig
                        function onSaved() { saveFlash.restart() }
                    }
                }
            }
        }
    }
}
