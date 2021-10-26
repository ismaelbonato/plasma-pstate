#!/bin/bash

CPUFREQ_EPP="${CPUFREQ}/energy_performance_preference"


CPUFREQ_SCALING_MIN_FREQ=${CPUFREQ}/scaling_min_freq
CPUFREQ_SCALING_MAX_FREQ=${CPUFREQ}/scaling_max_freq

INTEL_PSTATE=/sys/devices/system/cpu/intel_pstate
AMD_CPB=/sys/devices/system/cpu/cpufreq/policy0/cpb
CPU_BOOST=/sys/devices/system/cpu/cpufreq/boost

if [ -f $CPU_BOOST ]; then
    CPU_TURBO=$CPU_BOOST
    CPU_TURBO_ON="1"
    CPU_TURBO_OFF="0"
elif [ -f $INTEL_PSTATE/no_turbo ]; then
    CPU_TURBO=$INTEL_PSTATE/no_turbo
    CPU_TURBO_ON="0"
    CPU_TURBO_OFF="1"
elif [ -f $AMD_CPB ]; then
    CPU_TURBO=$AMD_CPB
    CPU_TURBO_ON="1"
    CPU_TURBO_OFF="0"
fi


check_cpu_governor () {
    [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]
}

read_cpu_governor () {
    cpu_governor=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)
}

set_cpu_governor () {
    gov=$1
    if [ -n "$gov" ]; then
        for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
            printf '%s\n' "$gov" > "$cpu" 2> /dev/null
        done
    fi
    read_cpu_governor
    json="{"
    json="${json}\"cpu_governor\":\"${cpu_governor}\""
    json="${json}}"
    echo "$json"
}

check_energy_perf() {
    [ -f "${CPUFREQ_EPP}" ]
}

read_energy_perf () {
    energy_perf=$(cat "${CPUFREQ_EPP}" 2>/dev/null)
    if [ -z "$energy_perf" ]; then
        energy_perf=$(x86_energy_perf_policy -r 2>/dev/null | grep -v 'HWP_' | \
        sed -r 's/://;
                s/(0x0000000000000000|EPB 0)/performance/;
                s/(0x0000000000000004|EPB 4)/balance_performance/;
                s/(0x0000000000000006|EPB 6)/default/;
                s/(0x0000000000000008|EPB 8)/balance_power/;
                s/(0x000000000000000f|EPB 15)/power/' | \
        awk '{ printf "%s\n", $2; }' | head -n 1)
    fi
}

set_energy_perf () {
    energyperf=$1
    if [ -n "$energyperf" ]; then
        if [ -f "${CPUFREQ_EPP}" ]; then
            for cpu in ${CPUFREQ_EPP}; do
                printf '%s\n' "$energyperf" > "$cpu" 2> /dev/null
            done
        else
            pnum=$(echo "$energyperf" | sed -r 's/^performance$/0/;
                                s/^balance_performance$/4/;
                                s/^(default|normal)$/6/;
                                s/^balance_power?$/8/;
                                s/^power(save)?$/15/')

            x86_energy_perf_policy "$pnum" > /dev/null 2>&1
        fi
    fi
    read_energy_perf
    json="{"
    json="${json}\"energy_perf\":\"${energy_perf}\""
    json="${json}}"
    echo "$json"
}

check_cpufreq_scaling_min_freq() {
    [ -n "${CPUFREQ_SCALING_AVAIL_FREQ}" ] && [ -f "$CPUFREQ_SCALING_AVAIL_FREQ" ]
}

read_cpufreq_scaling_min_freq () {
    cpufreq_scaling_min_freq=$(cat "${CPUFREQ_SCALING_MIN_FREQ}")
}

set_cpufreq_scaling_min_freq() {
    printf "%s" "${1}" > "${CPUFREQ_SCALING_MIN_FREQ}" 2> /dev/null
    read_cpufreq_scaling_min_freq
    json="{"
    json="${json}\"cpufreq_scaling_min_freq\":\"${cpufreq_scaling_min_freq}\""
    json="${json}}"
    echo "$json"
}

check_cpufreq_scaling_max_freq() {
    [ -n "${CPUFREQ_SCALING_AVAIL_FREQ}" ] && [ -f "$CPUFREQ_SCALING_AVAIL_FREQ" ]
}

read_cpufreq_scaling_max_freq () {
    cpufreq_scaling_max_freq=$(cat "${CPUFREQ_SCALING_MAX_FREQ}")
}

set_cpufreq_scaling_max_freq() {
    printf "%s" "${1}" > "${CPUFREQ_SCALING_MAX_FREQ}" 2> /dev/null
    read_cpufreq_scaling_max_freq
    json="{"
    json="${json}\"cpufreq_scaling_max_freq\":\"${cpufreq_scaling_max_freq}\""
    json="${json}}"
    echo "$json"
}

check_cpu_turbo () {
    [ -n "$CPU_TURBO" ] && [ -f $CPU_TURBO ]
}

read_cpu_turbo () {
    cpu_turbo=$(cat $CPU_TURBO)
    if [ "$cpu_turbo" = "$CPU_TURBO_OFF" ]; then
        cpu_turbo="false"
    else
        cpu_turbo="true"
    fi
}

append_cpu_turbo() {
    check_cpu_turbo || return 1
    read_cpu_turbo
    append_json "\"cpu_turbo\":\"${cpu_turbo}\""
}

set_cpu_turbo () {
    turbo=$1
    if [ -n "$turbo" ]; then
        if [ "$turbo" = "true" ]; then
            printf "%s" "$CPU_TURBO_ON\n" > $CPU_TURBO 2> /dev/null
        else
            printf "%s" "$CPU_TURBO_OFF\n" > $CPU_TURBO 2> /dev/null
        fi
    fi
    read_cpu_turbo
    json="{"
    json="${json}\"cpu_turbo\":\"${cpu_turbo}\""
    json="${json}}"
    echo "$json"
}
