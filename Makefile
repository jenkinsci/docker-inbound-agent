ROOT:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
IMAGE_NAME:=jenkins4eval/jnlp-slave:test

build:
	docker build -t ${IMAGE_NAME} .
