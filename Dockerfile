FROM openjdk:8-jdk
LABEL maintainer="lukas@capturemedia.ch"


ARG DOCKER_VERSION="17.03.2-ce"
ARG AGENT_VERSION=3.23
ARG AGENT_WORKDIR=/var/jenkins_home

ENV HOME /var/jenkins_home
RUN curl --create-dirs -sSLo /usr/share/jenkins/slave.jar https://repo.jenkins-ci.org/public/org/jenkins-ci/main/remoting/${AGENT_VERSION}/remoting-${AGENT_VERSION}.jar \
  && chmod 755 /usr/share/jenkins \
  && chmod 644 /usr/share/jenkins/slave.jar

COPY jenkins-slave /usr/local/bin/jenkins-slave


RUN mkdir -p ${HOME}/.jenkins && mkdir -p ${AGENT_WORKDIR} \
  && wget https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKER_VERSION}.tgz -O /tmp/docker.tar.gz \
  && tar xfv /tmp/docker.tar.gz -C /tmp \
  && mv /tmp/docker/docker /usr/bin/docker \
  && chmod +x /usr/bin/docker /usr/local/bin/jenkins-slave \
  && rm -rf /tmp/docker /tmp/docker.tar.gz \
  && apt-get update \
  && apt-get install -y jq make git python3-pip \
  && pip3 install --upgrade pip \
  && pip3 install awscli boto3

WORKDIR /var/jenkins_home
VOLUME /var/run/docker.sock


ENTRYPOINT ["jenkins-slave"]
