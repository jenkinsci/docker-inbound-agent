group "linux" {
  targets = [
    "alpine_jdk8",
    "debian_jdk8",
  ]
}

group "linux-arm64" {
  targets = [
  ]
}

group "linux-s390x" {
  targets = []
}

group "linux-ppc64le" {
  targets = []
}

#### This is the current (e.g. jenkins/inbound-agent) version (including build number suffix). Overridden by release builds from GIT_TAG.
variable "IMAGE_TAG" {
  default = "4.13.3-1"
}

#### This is for the "parent" image version to use (jenkins/agent:<PARENT_IMAGE_AGENT_VERSION>-<base-os>)
variable "PARENT_IMAGE_AGENT_VERSION" {
  default = "4.13.3-6"
}

variable "REGISTRY" {
  default = "docker.io"
}

variable "JENKINS_REPO" {
  default = "jenkins/inbound-agent"
}

variable "ON_TAG" {
  default = "false"
}

target "alpine_jdk8" {
  dockerfile = "8/alpine/Dockerfile"
  context = "."
  args = {
    version = "${PARENT_IMAGE_AGENT_VERSION}-alpine-jdk8"
  }
  tags = [
    equal(ON_TAG, "true") ? "${REGISTRY}/${JENKINS_REPO}:${IMAGE_TAG}-alpine-jdk8": "",
    "${REGISTRY}/${JENKINS_REPO}:alpine-jdk8",
    "${REGISTRY}/${JENKINS_REPO}:latest-alpine-jdk8",
  ]
  platforms = ["linux/amd64"]
}

target "debian_jdk8" {
  dockerfile = "8/debian/Dockerfile"
  context = "."
  args = {
    version = "${PARENT_IMAGE_AGENT_VERSION}-jdk8"
  }
  tags = [
    equal(ON_TAG, "true") ? "${REGISTRY}/${JENKINS_REPO}:${IMAGE_TAG}-jdk8": "",
    "${REGISTRY}/${JENKINS_REPO}:jdk8",
    "${REGISTRY}/${JENKINS_REPO}:latest-jdk8",
  ]
  platforms = ["linux/amd64"]
}
