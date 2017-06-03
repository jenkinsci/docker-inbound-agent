APP      := jenkins-ci-slave
VERSION  := 1.0

REGISTRY := 423681189101.dkr.ecr.us-east-1.amazonaws.com

env := base


.PHONY: docs test

help:
	@echo "  ecr_login       login to AWS ECR"
	@echo "  docker_build    rebuild the docker container"
	@echo "  docker_publish  push to docker container to ECR"

ecr_login:
	@$(shell aws ecr get-login)

docker_build:
	docker build --rm -t $(REGISTRY)/$(APP)-$(env):$(VERSION) -t $(REGISTRY)/$(APP)-$(env):latest .

docker_build_circle:
	docker build --rm -t $(REGISTRY)/$(APP)-$(env):$(CIRCLE_SHA1) -t $(REGISTRY)/$(APP)-$(env):latest  --build-arg app_id=$(APP_ID) --build-arg flask_config=production .

docker_publish:
	docker push $(REGISTRY)/$(APP)-$(env):$(VERSION)

docker_publish_latest:
	docker push $(REGISTRY)/$(APP)-$(env):latest
