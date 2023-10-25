ARG version=3186.vc3b_7249b_87eb_-1
ARG JAVA_MAJOR_VERSION=17
FROM jenkins/agent:"${version}"-jdk"${JAVA_MAJOR_VERSION}"

ARG user=jenkins

USER root
COPY ../../jenkins-agent /usr/local/bin/jenkins-agent
RUN chmod +x /usr/local/bin/jenkins-agent &&\
    ln -s /usr/local/bin/jenkins-agent /usr/local/bin/jenkins-slave
USER ${user}

ENTRYPOINT ["/usr/local/bin/jenkins-agent"]
