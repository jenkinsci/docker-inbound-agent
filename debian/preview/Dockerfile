ARG version=3206.vb_15dcf73f6a_9-1-preview
ARG JAVA_MAJOR_VERSION=21
FROM jenkins/agent:"${version}"-jdk"${JAVA_MAJOR_VERSION}-preview"

ARG user=jenkins

USER root
COPY ../../jenkins-agent /usr/local/bin/jenkins-agent
RUN chmod +x /usr/local/bin/jenkins-agent &&\
    ln -s /usr/local/bin/jenkins-agent /usr/local/bin/jenkins-slave
USER ${user}

ENTRYPOINT ["/usr/local/bin/jenkins-agent"]
