#!/usr/bin/env bats

AGENT_CONTAINER=bats-jenkins-jnlp-agent
NETCAT_HELPER_CONTAINER=netcat-helper

load test_helpers

buildNetcatImage

SUT_IMAGE=$(get_sut_image)

@test "[${SUT_IMAGE}] image has installed jenkins-agent in PATH" {
  cid=$(docker run -d -it -P "${SUT_IMAGE}" /bin/bash)

  is_agent_container_running $cid

  run docker exec "${cid}" which jenkins-agent
  [ "/usr/local/bin/jenkins-agent" = "${lines[0]}" ]

  run docker exec "${cid}" which jenkins-agent
  [ "/usr/local/bin/jenkins-agent" = "${lines[0]}" ]

  cleanup $cid
}

@test "[${SUT_IMAGE}] image starts jenkins-agent correctly (slow test)" {
  #  Spin off a helper image which contains netcat
  netcat_cid=$(docker run -d -it --name netcat-helper netcat-helper:latest /bin/sh)

  # Run jenkins agent which tries to connect to the netcat-helper container at port 5000
  cid=$(docker run -d --link netcat-helper "${SUT_IMAGE}" -url http://netcat-helper:5000 aaa bbb)

  # Launch the netcat utility, listening at port 5000 for 30 sec
  # bats will capture the output from netcat and compare the first line
  # of the header of the first HTTP request with the expected one
  run docker exec netcat-helper /bin/sh -c "timeout 30s nc -l 5000"

  # The GET request ends with a '\r'
  [ $'GET /tcpSlaveAgentListener/ HTTP/1.1\r' = "${lines[0]}" ]

  cleanup $netcat_cid
  cleanup $cid
}

@test "[${SUT_IMAGE}] use build args correctly" {
  cd "${BATS_TEST_DIRNAME}"/.. || false

  local ARG_TEST_VERSION
  local TEST_VERSION="3063.v26e24490f041"
  local DOCKER_AGENT_VERSION_SUFFIX="1"
  local TEST_USER="root"
  local ARG_TEST_VERSION="${TEST_VERSION}-${DOCKER_AGENT_VERSION_SUFFIX}"

  local FOLDER=$(get_dockerfile_directory)

  local sut_image="${SUT_IMAGE}-tests-${BATS_TEST_NUMBER}"

  docker buildx bake \
    --set "${IMAGE}".args.version="${ARG_TEST_VERSION}" \
    --set "${IMAGE}".args.user="${TEST_USER}" \
    --set "${IMAGE}".platform="linux/${ARCH}" \
    --set "${IMAGE}".tags="${sut_image}" \
    --load \
      "${IMAGE}"

  cid=$(docker run -d -it --name "${AGENT_CONTAINER}" -P "${sut_image}" /bin/sh)

  is_agent_container_running $cid

  run docker exec "${cid}" sh -c "java -cp /usr/share/jenkins/agent.jar hudson.remoting.jnlp.Main -version"
  [ "${TEST_VERSION}" = "${lines[0]}" ]

  run docker exec "${AGENT_CONTAINER}" sh -c "id -u -n ${TEST_USER}"
  [ "${TEST_USER}" = "${lines[0]}" ]

  cleanup $cid
}
