import QtQuick 2.3
import org.kde.plasma.core 2.0 as PlasmaCore

import '../../code/utils.js' as Utils
import '../../code/datasource.js' as Ds


Item {
    id: mockMonitor
    property string name: "MockMonitor"

    signal handleReadResult(var args, string stdout)
    signal handleReadAvailResult(string stdout)

    readonly property var sensors: {
        "cpu_min_perf": "17",
        "cpu_max_perf": "100",
        "cpu_turbo": "true",
        "gpu_min_freq": "350",
        "gpu_max_freq": "1150",
        "gpu_min_limit": "350",
        "gpu_max_limit": "1150",
        "gpu_boost_freq": "1150",
        "gpu_cur_freq": "350",
        "cpu_governor": "powersave",
        "energy_perf": "balance_performance",
        "thermal_mode": "balanced",
        "lg_battery_charge_limit": "true",
        "lg_fan_mode": "false",
        "lg_usb_charge": "false",
        "powermizer": "0",
        "nvidia_runtime_status": "suspended",
        "intel_tcc_cur_state": "0",
        "intel_tcc_max_state": "63",
        "intel_rapl_short": "78",
        "intel_rapl_long": "45",
        "dell_fan_mode": "0",
        "dell_fan_pwm/pwm1": "0",
        "dell_fan_pwm/pwm2": "0",
        "dell_fan_pwm": "pwm1 pwm2",
        "cpufreq_scaling_min_freq": "800000",
        "cpufreq_scaling_max_freq": "2600000",
    }

    readonly property var sensorsAvailable: {
        "cpu_governor": "performance powersave",
        "cpu_scaling_available_frequencies": "2600000 1300000 800000"
    }


    //
    // proxy the inner timer object
    //
    function start() { timer.start() }
    function stop() { timer.stop() }
    function restart() { timer.restart() }

    property alias interval: timer.interval
    property alias running: timer.running
    property alias repeat: timer.repeat
    property alias triggeredOnStart: timer.triggeredOnStart

    function init() {
        var stdout = JSON.stringify(sensorsAvailable)
        handleReadAvailResult(stdout)
        start()
    }

    Timer {
        id: timer
        interval: 2000
        repeat: true
        running: false
        triggeredOnStart: true
        onTriggered: {
            var args = ["-read-all"]
            var stdout = JSON.stringify(sensors)
            handleReadResult(args, stdout)
        }
    }
}
