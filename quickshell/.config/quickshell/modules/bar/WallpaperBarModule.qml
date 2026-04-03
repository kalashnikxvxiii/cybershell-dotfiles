import QtQuick
import "../../common/Colors.js" as CP
import "../../common"

CyberpunkModule {
    id: root

    text: "\u25A3"      // ▣ wallpaper glyph
    accent: WallpaperState.pickerOpen ? CP.yellow : CP.cyan
    onLeftClick: function() {
        WallpaperState.togglePicker(BarConfig.primaryMonitorName)
    }
}