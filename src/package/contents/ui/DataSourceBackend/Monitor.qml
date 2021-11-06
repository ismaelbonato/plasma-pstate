import QtQuick 2.3
import org.kde.plasma.core 2.0 as PlasmaCore

import '../../code/utils.js' as Utils
import '../../code/datasource.js' as Ds


PlasmaCore.DataSource {
    id: monitorDS
    engine: 'executable'

    property string name: "LocalMonitor"

    property string commandSource: getCommand()

    /* required */ property var set_prefs

    signal handleReadResult(var args, string stdout)

    function getCommand(sensors) {
        var cmd = plasmoid.configuration.useSudoForReading ? 'pkexec ' : ''
        cmd += set_prefs
        if (!sensors || sensors.length === 0) {
            cmd += ' -read-all'
        } else {
            cmd += ' -read-some ' + sensors.join(" ")
        }
        return cmd
    }

    function activeSensorsChanged() {
        var sensors = main.sensorsMgr.activeSensors
        sensors = Ds.filterReadableSensors(sensors)
        commandSource = getCommand(sensors)
    }

    onNewData: {
        if (data['exit code'] > 0) {
            print('monitorDS error: ' + data.stderr)
        } else {
            var args = sourceName.split(' ')
            args = args.slice(args.indexOf(set_prefs) + 1)

            handleReadResult(args, data.stdout)
        }
    }

    Component.onCompleted: {
        connectSource(commandSource);
    }
    interval: pollingInterval

    function restart() {
        stop()
        start()
    }

    function stop() {
        while(connectedSources.length) {
            disconnectSource(connectedSources[0]);
        }
    }

    function start() {
        connectSource(commandSource);
    }
}
