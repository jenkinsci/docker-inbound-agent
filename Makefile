ROOT:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
IMAGE_NAME:=jenkins/jnlp-slave

build:
	docker build -t ${IMAGE_NAME} .
