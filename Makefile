# Jenkins Master



build:
	docker build \
	-t prominentedgestatengine/jenkins:gdal-latest .

push:
	docker push prominentedgestatengine/jenkins:gdal-latest
