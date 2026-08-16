import QtQuick
import "../../common"


Column {
    id: root
    width:   380
    spacing: 20

    Repeater {
        model: LogoutWidgetState.enabledOrdered

        delegate: Loader {
            required property var modelData
            required property int index

            source: {
                var reg = LogoutWidgetState.availableWidgets.find(w => w.id === modelData.id)
                return reg ? reg.componentPath : ""
            }
        }
    }
}
