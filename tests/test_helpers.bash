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

function get_sut_image {
    test -n "${IMAGE:?"[sut_image] Please set the variable 'IMAGE' to the name of the image to test in 'docker-bake.hcl'."}"
    ## Retrieve the SUT image name from buildx
    # Option --print for 'docker buildx bake' prints the JSON configuration on the stdout
    # Option --silent for 'make' suppresses the echoing of command so the output is valid JSON
    # The image name is the 1st of the "tags" array, on the first "image" found
    make --silent show | jq -r ".target.${IMAGE}.tags[0]"
}

function get_dockerfile_directory() {
    test -n "${IMAGE:?"[sut_image] Please set the variable 'IMAGE' to the name of the image to test in 'docker-bake.hcl'."}"

    DOCKERFILE=$(make --silent show | jq -r ".target.${IMAGE}.dockerfile")
    echo "${DOCKERFILE%"/Dockerfile"}"
}

function clean_test_container {
	docker kill "${AGENT_CONTAINER}" "${NETCAT_HELPER_CONTAINER}" &>/dev/null || :
	docker rm -fv "${AGENT_CONTAINER}" "${NETCAT_HELPER_CONTAINER}" &>/dev/null || :
}

function is_agent_container_running {
  local cid="${1}"
	sleep 1
	retry 3 1 assert "true" docker inspect -f '{{.State.Running}}' "${cid}"
}

function buildNetcatImage() {
  if ! docker inspect --type=image netcat-helper:latest &>/dev/null; then
    docker build -t netcat-helper:latest tests/netcat-helper/ &>/dev/null
  fi
}

function cleanup {
    docker kill "$1" &>/dev/null ||:
    docker rm -fv "$1" &>/dev/null ||:
}
