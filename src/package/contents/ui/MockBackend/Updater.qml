import QtQuick 2.3

Item {
    id: updater
    property string name: "MockUpdater"

    signal handleSetValueResult(var arg, string stdout)

    function update(sensor, args) {
        var res = {}
        res[sensor] = args.join(" ")

        var stdout = JSON.stringify(res)
        handleSetValueResult(sensor, stdout)

    }
}
