ROOT:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
IMAGE_NAME:=jenkins4eval/jnlp-slave

build:
	docker build -t ${IMAGE_NAME}:latest .
	docker build -t ${IMAGE_NAME}:alpine -f Dockerfile-alpine .
	docker build -t ${IMAGE_NAME}:jdk11  -f Dockerfile-jdk11  .

.PHONY: tests
tests:
	@bats tests/tests.bats
	@FLAVOR=alpine bats tests/tests.bats
	@FLAVOR=jdk11 bats tests/tests.bats
