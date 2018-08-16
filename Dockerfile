# The MIT License
#
#  Copyright (c) 2015-2017, CloudBees, Inc.
#
#  Permission is hereby granted, free of charge, to any person obtaining a copy
#  of this software and associated documentation files (the "Software"), to deal
#  in the Software without restriction, including without limitation the rights
#  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#  copies of the Software, and to permit persons to whom the Software is
#  furnished to do so, subject to the following conditions:
#
#  The above copyright notice and this permission notice shall be included in
#  all copies or substantial portions of the Software.
#
#  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
#  THE SOFTWARE.

FROM openjdk:8-jdk
LABEL maintainer="lukas@capturemedia.ch"

ARG USER=jenkins
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
  && apt-get install -y jq make git

WORKDIR /var/jenkins_home
VOLUME /var/run/docker.sock


ENTRYPOINT ["jenkins-slave"]
