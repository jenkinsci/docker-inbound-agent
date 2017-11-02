# Jenkins Master



build:
	docker build --no-cache \
	-t prominentedgestatengine/jenkins:jnlp-slave .

push:
	docker push prominentedgestatengine/jenkins:jnlp-slave
