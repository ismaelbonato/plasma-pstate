#!/bin/bash

SYSFSCPU="/sys/devices/system/cpu"
CPU_SMT="${SYSFSCPU}/smt"

have_smt() {
    [ -f "${CPU_SMT}/active" ]
}

is_smt_on() {
    have_smt && [ "$(cat ${CPU_SMT}/active)" = "1" ]
}

have_itmt() {
    [ -d "${SYSFSCPU}/cpu0/itmt" ]
}

get_n_possible_cores() {
    find "${SYSFSCPU}" -type d -name "cpu[0-9]*" | wc -l
}

get_n_physical_cores() {
    if have_smt; then
        echo "$(($(get_n_possible_cores) / 2))"
    else
        get_n_possible_cores
    fi
}

get_n_cores_online() {
    # shellcheck disable=SC2207
    cpu_online=($(grep . "${SYSFSCPU}"/cpu{0..4096}/online 2> /dev/null))

    cpu_paths=("${cpu_online[@]%%/online:*}")
    cpu_paths=("${SYSFSCPU}/cpu0" "${cpu_paths[@]}")

    cpu_sibling_paths=("${cpu_paths[@]/%//topology/thread_siblings_list}")

    n_online=0
    cpu_checked=""

    for siblings_list in "${cpu_sibling_paths[@]}"
    do
        [ -f "${siblings_list}" ] || continue

        cpu_num=${siblings_list##"${SYSFSCPU}/cpu"}
        cpu_num=${cpu_num%%/topology/thread_siblings_list}

        [[ $cpu_checked == *",${cpu_num},"* ]] && continue

        # List of sibling CPU IDs
        IFS=',' read -ra siblings <<< "$(cat "$siblings_list" 2> /dev/null)"

        sibling_online_paths=( "${siblings[@]/#/${SYSFSCPU}/cpu}" )
        sibling_online_paths=( "${sibling_online_paths[@]/%//online}" )

        # Number of online siblings
        n=0
        for sibling in "${siblings[@]}"
        do
            if [[ "${cpu_online[*]}" =~ ${SYSFSCPU}/cpu${sibling}/online:1 ]]; then
                n=$((n+1))
            fi
        done

        if [ "$cpu_num" -eq "0" ]; then
            # Core 0 doesn't have a sysfs online file
            n_siblings=$(( ${#siblings[@]} - 1 ))
        else
            n_siblings=${#siblings[@]}
        fi

        if [ "$n" -eq "$n_siblings" ]; then
            n_online=$((n_online+1))
        fi

        # Add CPU ID to list of checked CPUs
        printf -v cpu_id "%s," "${siblings[@]}"
        cpu_checked="${cpu_checked}${cpu_id}"
    done

    echo "${n_online}"
}

# Get array of cpu core numbers
# 1: Name of variable to store results
# 2: array of sysfs cpu paths
get_core_numbers() {
    cpu_paths=("${@:2}")
    CPU_PRIORITIES=("${cpu_paths[@]##"${SYSFSCPU}/cpu"}")
    mapfile -t "$1" < <( echo "${CPU_PRIORITIES[*]}" | tr " " "\n" | sort -nr )
}

# Get array of cpu core priorities
# 1: Name of variable to store results
# 2: array of sysfs cpu paths
get_core_priorities() {
    cpu_paths=("${@:2}")
    cpu_paths=("${cpu_paths[@]/%//itmt/priority}")
    mapfile -t "$1" < <(cat "${cpu_paths[@]}")
}

sort_core_priorities() {
    cpu_priorities=("${@:2}")
    mapfile -t "$1" < <( echo "${cpu_priorities[*]}" | tr " " "\n" | sort -n )
}

rsort_core_priorities() {
    cpu_priorities=("${@:2}")
    mapfile -t "$1" < <( echo "${cpu_priorities[*]}" | tr " " "\n" | sort -nr )
}


set_cores_online() {
    cores_arg=$(( $1 - 1 ))
    [ -z ${cores_arg} ] && { printf "provide arg\n"; exit 0; }

    last_core=$(($(get_n_physical_cores)-1))

    if [ ${cores_arg} -lt 0 ] || [ ${cores_arg} -gt ${last_core} ]; then
        return 0
    fi

    mapfile -t cpu_online < \
        <(eval grep . "${SYSFSCPU}/cpu{0..${last_core}}/online" 2> /dev/null)

    read -r -a cpu_online_paths <<< "${cpu_online[@]/*online:0/}"
    read -r -a cpu_online_paths <<< "${cpu_online_paths[@]%%/online:*}"

    n_online=${#cpu_online_paths[@]}

    delta=$((cores_arg - n_online))
    if [ ${delta} -gt 0 ]; then
        # Turn on some cores
        online_val="1"
        other_val="0"
    elif [ ${delta} -lt 0 ]; then
        # Turn off some cores
        delta=$((-1*delta))
        online_val="0"
        other_val="1"
    else
        return 0
    fi

    read -r -a toggle_cpu_paths <<< \
        "${cpu_online[@]/${SYSFSCPU}\/cpu*\/online:${online_val}/}"
    read -r -a toggle_cpu_paths <<< \
        "${toggle_cpu_paths[@]%%\/online:${other_val}}"

    core_priorities=()
    if have_itmt; then
        get_core_priorities "core_priorities" "${toggle_cpu_paths[@]}"
    else
        get_core_numbers "core_priorities" "${toggle_cpu_paths[@]}"
    fi

    if [ "${online_val}" == "1" ]; then
        rsort_core_priorities "sorted_priorities" "${core_priorities[@]}"
    else
        sort_core_priorities "sorted_priorities" "${core_priorities[@]}"
    fi

    sorted_prio_list=("${sorted_priorities[@]:0:${delta}}")
    printf -v sorted_prio_list ",%s" "${sorted_prio_list[@]}"
    sorted_prio_list="${sorted_prio_list},"

    n_cores=${#toggle_cpu_paths[@]}

    for (( i = 0; i < "${n_cores}"; i++ )); do
        prio="${core_priorities[$i]}"

        # Stop when list is empty
        if [[ ${sorted_prio_list} == "," ]]; then
            break
        fi

        if [[ "${sorted_prio_list}" != *"${prio}"* ]]; then
            continue
        fi

        # Toggle core online/offline
        echo "${online_val}" | tee "${toggle_cpu_paths[$i]}/online" > /dev/null

        # Toggle sibling core
        if is_smt_on; then
            core_id=${toggle_cpu_paths[$i]##${SYSFSCPU}/cpu}
            sibling_core=$(( core_id + last_core + 1 ))
            sibling_core="${SYSFSCPU}/cpu${sibling_core}"
            echo "${online_val}" | tee "${sibling_core}/online" > /dev/null
        fi

        # Remove item from list
        sorted_prio_list=${sorted_prio_list/,${prio},/,}
    done
}
