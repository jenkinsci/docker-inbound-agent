#!/usr/bin/env bash

set -eu

# check dependencies
(
    type docker &>/dev/null || ( echo "docker is not available"; exit 1 )
)>&2

function printMessage {
  echo "# ${@}" >&3
}

# Assert that $1 is the output of a command $2
function assert {
    local expected_output
    local actual_output
    expected_output="${1}"
    shift
    actual_output=$("${@}")
    if ! [[ "${actual_output}" = "${expected_output}" ]]; then
        printMessage "Expected: '${expected_output}', actual: '${actual_output}'"
        false
    fi
}

# Retry a command $1 times until it succeeds. Wait $2 seconds between retries.
function retry {
    local attempts
    local delay
    local i
    attempts="${1}"
    shift
    delay="${1}"
    shift

    for ((i=0; i < attempts; i++)); do
        run "${@}"
        if [[ "${status}" -eq 0 ]]; then
            return 0
        fi
        sleep "${delay}"
    done

    printMessage "Command '${*}' failed $attempts times. Status: ${status}. Output: ${output}"

    false
}

function clean_test_container {
	docker kill "${SLAVE_CONTAINER}" "${NETCAT_HELPER_CONTAINER}" &>/dev/null || :
	docker rm -fv "${SLAVE_CONTAINER}" "${NETCAT_HELPER_CONTAINER}" &>/dev/null || :
}

function is_slave_container_running {
	sleep 1
	retry 3 1 assert "true" docker inspect -f '{{.State.Running}}' "${SLAVE_CONTAINER}"
}

function buildNetcatImage() {
  if ! docker inspect --type=image netcat-helper:latest &>/dev/null; then
    docker build -t netcat-helper:latest tests/netcat-helper/ &>/dev/null
  fi
}
