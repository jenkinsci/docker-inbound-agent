# Jenkins Master



build:
	docker build --no-cache \
	-t srflaxu40/jenkins:jnlp-slave .

push:
	docker push srflaxu40/jenkins:jnlp-slave
