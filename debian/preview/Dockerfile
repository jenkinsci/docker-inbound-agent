ARG version=3203.v94ce994fdb_31-2-preview
ARG JAVA_MAJOR_VERSION=21
FROM jenkins/agent:"${version}"-jdk"${JAVA_MAJOR_VERSION}-preview"

ARG user=jenkins

USER root
COPY ../../jenkins-agent /usr/local/bin/jenkins-agent
RUN chmod +x /usr/local/bin/jenkins-agent &&\
    ln -s /usr/local/bin/jenkins-agent /usr/local/bin/jenkins-slave
USER ${user}

ENTRYPOINT ["/usr/local/bin/jenkins-agent"]
