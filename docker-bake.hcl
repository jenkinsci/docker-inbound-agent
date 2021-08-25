group "linux" {
  targets = [
    "alpine_jdk8",
    "alpine_jdk11",
    "debian_jdk8",
    "debian_jdk11",
  ]
}

group "linux-arm64" {
  targets = [
    "debian_jdk11",
  ]
}

group "linux-s390x" {
  targets = []
}

group "linux-ppc64le" {
  targets = []
}

# update this to use a newer build number for jenkins/docker image
variable "AGENT_IMAGE_BUILD_NUMBER" {
  default = "1"
}

variable "REGISTRY" {
  default = "docker.io"
}

variable "JENKINS_REPO" {
  default = "jenkins/inbound-agent"
}

variable "REMOTING_VERSION" {
  default = "4.10"
}

variable "BUILD_NUMBER" {
  default = "6"
}

variable "ON_TAG" {
  default = "false"
}

target "alpine_jdk8" {
  dockerfile = "8/alpine/Dockerfile"
  context = "."
  args = {
    version = "${REMOTING_VERSION}-${AGENT_IMAGE_BUILD_NUMBER}-alpine-jdk8"
  }
  tags = [
    equal(ON_TAG, "true") ? "${REGISTRY}/${JENKINS_REPO}:${REMOTING_VERSION}-${BUILD_NUMBER}-alpine-jdk8": "",
    "${REGISTRY}/${JENKINS_REPO}:alpine-jdk8",
    "${REGISTRY}/${JENKINS_REPO}:latest-alpine-jdk8",
  ]
  platforms = ["linux/amd64"]
}

target "alpine_jdk11" {
  dockerfile = "11/alpine/Dockerfile"
  context = "."
  args = {
    version = "${REMOTING_VERSION}-${AGENT_IMAGE_BUILD_NUMBER}-alpine-jdk11"
  }
  tags = [
    equal(ON_TAG, "true") ? "${REGISTRY}/${JENKINS_REPO}:${REMOTING_VERSION}-${BUILD_NUMBER}-alpine": "",
    equal(ON_TAG, "true") ? "${REGISTRY}/${JENKINS_REPO}:${REMOTING_VERSION}-${BUILD_NUMBER}-alpine-jdk11": "",
    "${REGISTRY}/${JENKINS_REPO}:alpine",
    "${REGISTRY}/${JENKINS_REPO}:alpine-jdk11",
    "${REGISTRY}/${JENKINS_REPO}:latest-alpine",
    "${REGISTRY}/${JENKINS_REPO}:latest-alpine-jdk11",
  ]
  platforms = ["linux/amd64"]
}

target "debian_jdk8" {
  dockerfile = "8/debian/Dockerfile"
  context = "."
  args = {
    version = "${REMOTING_VERSION}-${AGENT_IMAGE_BUILD_NUMBER}-jdk8"
  }
  tags = [
    equal(ON_TAG, "true") ? "${REGISTRY}/${JENKINS_REPO}:${REMOTING_VERSION}-${BUILD_NUMBER}-jdk8": "",
    "${REGISTRY}/${JENKINS_REPO}:jdk8",
    "${REGISTRY}/${JENKINS_REPO}:latest-jdk8",
  ]
  platforms = ["linux/amd64"]
}

target "debian_jdk11" {
  dockerfile = "11/debian/Dockerfile"
  context = "."
  args = {
    version = "${REMOTING_VERSION}-${AGENT_IMAGE_BUILD_NUMBER}-jdk11"
  }
  tags = [
    equal(ON_TAG, "true") ? "${REGISTRY}/${JENKINS_REPO}:${REMOTING_VERSION}-${BUILD_NUMBER}": "",
    equal(ON_TAG, "true") ? "${REGISTRY}/${JENKINS_REPO}:${REMOTING_VERSION}-${BUILD_NUMBER}-jdk11": "",
    "${REGISTRY}/${JENKINS_REPO}:jdk11",
    "${REGISTRY}/${JENKINS_REPO}:latest",
    "${REGISTRY}/${JENKINS_REPO}:latest-jdk11",
  ]
  platforms = ["linux/amd64", "linux/arm64"]
}
