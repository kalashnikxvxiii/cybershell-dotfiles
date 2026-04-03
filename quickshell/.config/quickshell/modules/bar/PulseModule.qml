// PulseModule.qml — volume via Quickshell.Services.Pipewire

import Quickshell.Services.Pipewire
import Quickshell.Io
import QtQuick
import "../../common/Colors.js" as CP

CyberpunkModule {
    id: root

    // PwObjectTracker è necessario per rendere accessibili le proprietà audio
    PwObjectTracker {
        objects: [Pipewire.preferredDefaultAudioSink]
    }

    property var  sink:  Pipewire.preferredDefaultAudioSink
    property bool muted: sink && sink.audio ? sink.audio.muted : false
    property int  vol:   sink && sink.audio ? Math.round(sink.audio.volume * 100) : 0

    accent: muted ? Qt.rgba(0.5, 0.5, 0.5, 1.0) : CP.yellow
    text: {
        if (muted) return "MUTE"
        var icon = vol === 0 ? "󰸈" : vol < 50 ? "󰖀" : ""
        return icon + " " + vol + "%"
    }

    onLeftClick:  function() { _pav.running = true }
    onRightClick: function() {
        if (sink && sink.audio) sink.audio.muted = !sink.audio.muted
    }
    onScroll: function(delta) {
        if (!sink || !sink.audio) return
        var step = 0.05
        sink.audio.volume = Math.max(0, Math.min(1.5, sink.audio.volume + (delta > 0 ? step : -step)))
    }

    Process { id: _pav; command: ["pavucontrol"]; running: false }
}
