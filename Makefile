ROOT:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

IMAGE_NAME:=jenkins4eval/jnlp-slave
IMAGE_ALPINE:=${IMAGE_NAME}:alpine
IMAGE_ALPINE_JDK11:=${IMAGE_NAME}:alpine-jdk11
IMAGE_DEBIAN:=${IMAGE_NAME}:test
IMAGE_DEBIAN_DIND:=${IMAGE_NAME}:test-dind
IMAGE_JDK11:=${IMAGE_NAME}:jdk11

build: build-alpine build-debian build-debian-dind build-jdk11 build-jdk11-alpine

build-alpine:
	cp -f jenkins-agent 8/alpine/
	docker build -t ${IMAGE_ALPINE} 8/alpine

build-debian:
	cp -f jenkins-agent 8/debian/
	docker build -t ${IMAGE_DEBIAN} 8/debian

build-debian-dind:
	cp -f jenkins-agent 8/debian-dind/
	docker build -t ${IMAGE_DEBIAN_DIND} 8/debian-dind

build-jdk11:
	cp -f jenkins-agent 11/debian/
	docker build -t ${IMAGE_JDK11} 11/debian

build-jdk11-alpine:
	cp -f jenkins-agent 11/alpine/
	docker build -t ${IMAGE_ALPINE} 11/alpine


bats:
# The lastest version is v1.1.0
	@if [ ! -d bats-core ]; then git clone https://github.com/bats-core/bats-core.git; fi
	@git -C bats-core reset --hard c706d1470dd1376687776bbe985ac22d09780327

.PHONY: test test-alpine test-debian test-jdk11 test-jdk11-alpine
test: test-alpine test-debian test-jdk11 test-jdk11-alpine

test-alpine: bats
	@FOLDER="8/alpine" bats-core/bin/bats tests/tests.bats

test-debian: bats
	@FOLDER="8/debian" bats-core/bin/bats tests/tests.bats

test-jdk11: bats
	@FOLDER="11/debian" bats-core/bin/bats tests/tests.bats

test-jdk11-alpine: bats
	@FOLDER="11/alpine" bats-core/bin/bats tests/tests.bats
