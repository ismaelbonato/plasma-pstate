/*
    SPDX-FileCopyrightText: 2018 John Salatas <jsalatas@ictpro.gr>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick 2.3
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.1

import "./" as Pstate
import '../code/utils.js' as Utils

ColumnLayout {
    id: group

    property alias text: group_title.text
    property var items: []
    property var props
    
    objectName: "Group"

    onPropsChanged: {
        text = props['text']
        items = props['items']
        visible = props['visible'] === undefined ||
                  plasmoid.configuration[props['visible']] === true
    }

    Component {
        id: slider
        Pstate.Slider {
            Layout.topMargin: 5
            Layout.bottomMargin: 5
            Layout.minimumWidth: units.gridUnit * 1
        }
    }

    Component {
        id: switchbutton
        Pstate.Switch {
            Layout.topMargin: 5
            Layout.bottomMargin: 5
        }
    }

    Component {
        id: combobox
        Pstate.ComboBox {
            Layout.leftMargin: units.gridUnit
            Layout.topMargin: 0
            Layout.bottomMargin: 0
        }
    }

    function createItem(sensorItem) {
        sensorItem['isGrouped'] = true

        switch (sensorItem['type']) {
            case 'slider': {
                slider.createObject(group, {'props': sensorItem})
                break
            }
            case 'switch': {
                switchbutton.createObject(group, {'props': sensorItem})
                break
            }
            case 'combobox': {
                combobox.createObject(group, {'props': sensorItem})
                break
            }
            default: console.log("header: unkonwn type: " + sensorItem['type'])
        }
    }

    onItemsChanged: {
        for(var i = 0; i < items.length; i++) {
            var sensorItem = items[i]

            if(!Utils.sensor_has_value(sensorItem)) {
                continue
            }

            createItem(sensorItem)

            if (sensorItem.sensor) {
                main.sensorsMgr.addActiveSensor(sensorItem.sensor)
            }
        }
    }

    Label {
        id: group_title
        font.pointSize: theme.smallestFont.pointSize * 1.25
        color: theme.textColor
        visible: text != ''
    }
}
