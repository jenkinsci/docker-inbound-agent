ARG version=3107.v665000b_51092-14
ARG JAVA_MAJOR_VERSION=17
FROM jenkins/agent:"${version}"-jdk"${JAVA_MAJOR_VERSION}"

ARG version=3107.v665000b_51092-14
LABEL Description="This is a base image, which allows connecting Jenkins agents via JNLP protocols" Vendor="Jenkins project" Version="$version"

ARG user=jenkins

USER root
COPY ../../jenkins-agent /usr/local/bin/jenkins-agent
RUN chmod +x /usr/local/bin/jenkins-agent &&\
    ln -s /usr/local/bin/jenkins-agent /usr/local/bin/jenkins-slave
USER ${user}

ENTRYPOINT ["/usr/local/bin/jenkins-agent"]
