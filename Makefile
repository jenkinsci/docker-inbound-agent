ROOT:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

IMAGE_NAME:=jenkins4eval/jnlp-slave
IMAGE_ALPINE:=${IMAGE_NAME}:alpine
IMAGE_DEBIAN:=${IMAGE_NAME}:test
IMAGE_JDK11:=${IMAGE_NAME}:jdk11

build: build-alpine build-debian build-jdk11

build-alpine:
	docker build -t ${IMAGE_ALPINE} --file Dockerfile-alpine .

build-debian:
	docker build -t ${IMAGE_DEBIAN} --file Dockerfile .

build-jdk11:
	docker build -t ${IMAGE_JDK11} --file Dockerfile-jdk11 .

.PHONY: test
test: test-alpine test-debian test-jdk11

.PHONY: test-alpine
test-alpine:
	@FLAVOR=alpine bats tests/tests.bats

.PHONY: test-debian
test-debian:
	@bats tests/tests.bats

.PHONY: test-jdk11
test-jdk11:
	@FLAVOR=jdk11 bats tests/tests.bats
