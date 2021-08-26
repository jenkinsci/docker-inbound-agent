ROOT:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

IMAGE_NAME:=jenkins4eval/inbound-agent
IMAGE_ALPINE:=${IMAGE_NAME}:alpine
IMAGE_ALPINE_JDK11:=${IMAGE_NAME}:alpine-jdk11
IMAGE_DEBIAN:=${IMAGE_NAME}:test
IMAGE_JDK11:=${IMAGE_NAME}:jdk11

## For Docker <=20.04
export DOCKER_BUILDKIT=1
## For Docker <=20.04
export DOCKER_CLI_EXPERIMENTAL=enabled
## Required to have docker build output always printed on stdout
export BUILDKIT_PROGRESS=plain

current_arch := $(shell uname -m)
export ARCH ?= $(shell case $(current_arch) in (x86_64) echo "amd64" ;; (i386) echo "386";; (aarch64|arm64) echo "arm64" ;; (armv6*) echo "arm/v6";; (armv7*) echo "arm/v7";; (ppc64*|s390*|riscv*) echo $(current_arch);; (*) echo "UNKNOWN-CPU";; esac)

# Set to the path of a specific test suite to restrict execution only to this
# default is "all test suites in the "tests/" directory
TEST_SUITES ?= $(CURDIR)/tests

##### Macros
## Check the presence of a CLI in the current PATH
check_cli = type "$(1)" >/dev/null 2>&1 || { echo "Error: command '$(1)' required but not found. Exiting." ; exit 1 ; }
## Check if a given image exists in the current manifest docker-bake.hcl
check_image = make --silent list | grep -w '$(1)' >/dev/null 2>&1 || { echo "Error: the image '$(1)' does not exist in manifest for the platform 'linux/$(ARCH)'. Please check the output of 'make list'. Exiting." ; exit 1 ; }
## Base "docker buildx base" command to be reused everywhere
bake_base_cli := docker buildx bake -f docker-bake.hcl --load

.PHONY: build test test-alpine test-debian test-jdk11 test-jdk11-alpine

check-reqs:
## Build requirements
	@$(call check_cli,bash)
	@$(call check_cli,git)
	@$(call check_cli,docker)
	@docker info | grep 'buildx:' >/dev/null 2>&1 || { echo "Error: Docker BuildX plugin required but not found. Exiting." ; exit 1 ; }
## Test requirements
	@$(call check_cli,curl)
	@$(call check_cli,jq)

build: check-reqs
	@set -x; $(bake_base_cli) --set '*.platform=linux/$(ARCH)' $(shell make --silent list)

build-%:
	@$(call check_image,$*)
	@set -x; $(bake_base_cli) --set '*.platform=linux/$(ARCH)' '$*'

show:
	@$(bake_base_cli) linux --print

list: check-reqs
	@set -x; make --silent show | jq -r '.target | path(.. | select(.platforms[] | contains("linux/$(ARCH)"))?) | add'


bats:
# The lastest version is v1.1.0
	@if [ ! -d bats-core ]; then git clone https://github.com/bats-core/bats-core.git; fi
	@git -C bats-core reset --hard c706d1470dd1376687776bbe985ac22d09780327

.PHONY: test test-alpine test-debian test-jdk11 test-jdk11-alpine
test: test-alpine test-debian test-jdk11 test-jdk11-alpine

test-alpine: bats
	cp -f jenkins-agent 8/alpine/
	@FOLDER="8/alpine" bats-core/bin/bats tests/tests.bats
	rm -f 8/alpine/jenkins-agent

test-debian: bats
	cp -f jenkins-agent 8/debian/
	@FOLDER="8/debian" bats-core/bin/bats tests/tests.bats
	rm -f 8/debian/jenkins-agent

test-jdk11: bats
	cp -f jenkins-agent 11/debian/
	@FOLDER="11/debian" bats-core/bin/bats tests/tests.bats
	rm -f 11/debian/jenkins-agent

test-jdk11-alpine: bats
	cp -f jenkins-agent 11/alpine/
	@FOLDER="11/alpine" bats-core/bin/bats tests/tests.bats
	rm -f 11/alpine/jenkins-agent
