#!/usr/bin/env bats

DOCKERFILE=Dockerfile
JDK=8
SLAVE_IMAGE=jenkins-jnlp-slave
SLAVE_CONTAINER=bats-jenkins-jnlp-slave
NETCAT_HELPER_CONTAINER=netcat-helper

if [[ -z "${FLAVOR}" ]]
then
  FLAVOR="debian"
elif [[ "${FLAVOR}" = "jdk11" ]]
then
  DOCKERFILE+="-jdk11"
  JDK=11
  SLAVE_IMAGE+=":jdk11"
  SLAVE_CONTAINER+="-jdk11"
else
  DOCKERFILE+="-alpine"
  SLAVE_IMAGE+=":alpine"
  SLAVE_CONTAINER+="-alpine"
fi

load test_helpers

clean_test_container

buildNetcatImage

function teardown () {
  clean_test_container
}

@test "[${FLAVOR}] build image" {
  cd "${BATS_TEST_DIRNAME}"/.. || false
  docker build -t "${SLAVE_IMAGE}" -f "${DOCKERFILE}" .
}

@test "[${FLAVOR}] image has installed jenkins-agent in PATH" {
  docker run -d -it --name "${SLAVE_CONTAINER}" -P "${SLAVE_IMAGE}" /bin/bash

  is_slave_container_running

  run docker exec "${SLAVE_CONTAINER}" which jenkins-slave
  [ "/usr/local/bin/jenkins-slave" = "${lines[0]}" ]

  run docker exec "${SLAVE_CONTAINER}" which jenkins-agent
  [ "/usr/local/bin/jenkins-agent" = "${lines[0]}" ]
}

@test "[${FLAVOR}] image starts jenkins-agent correctly" {
  docker run -d -it --name netcat-helper netcat-helper:latest /bin/sh

  docker run -d --link netcat-helper --name "${SLAVE_CONTAINER}" "${SLAVE_IMAGE}" -url http://netcat-helper:5000 aaa bbb

  run docker exec netcat-helper /bin/sh -c "timeout 10s nc -l 5000"

  # The GET request ends with a '\r'
  [ $'GET /tcpSlaveAgentListener/ HTTP/1.1\r' = "${lines[0]}" ]
}

@test "[${FLAVOR}] use build args correctly" {
  cd "${BATS_TEST_DIRNAME}"/.. || false

	local ARG_TEST_VERSION
  local TEST_VERSION="3.36"
	local TEST_USER="root"

	if [[ "${FLAVOR}" = "debian" ]]
  then
    ARG_TEST_VERSION="${TEST_VERSION}-1"
  elif [[ "${FLAVOR}" = "jdk11" ]]
  then
    ARG_TEST_VERSION="${TEST_VERSION}-1-jdk11"
  else
    ARG_TEST_VERSION="${TEST_VERSION}-1-alpine"
  fi

  docker build \
    --build-arg "version=${ARG_TEST_VERSION}" \
    --build-arg "user=${TEST_USER}" \
    -t "${SLAVE_IMAGE}" \
    -f "${DOCKERFILE}" .

  docker run -d -it --name "${SLAVE_CONTAINER}" -P "${SLAVE_IMAGE}" /bin/sh

  is_slave_container_running

  run docker exec "${SLAVE_CONTAINER}" sh -c "java -cp /usr/share/jenkins/agent.jar hudson.remoting.jnlp.Main -version"
  [ "${TEST_VERSION}" = "${lines[0]}" ]

  run docker exec "${SLAVE_CONTAINER}" sh -c "id -u -n ${TEST_USER}"
  [ "${TEST_USER}" = "${lines[0]}" ]
}
