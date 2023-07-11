ARG VERSION=3131.vf2b_b_798b_ce99-4
ARG JAVA_MAJOR_VERSION=17
FROM jenkins/agent:"${VERSION}"-jdk"${JAVA_MAJOR_VERSION}"

ARG VERSION=3131.vf2b_b_798b_ce99-4
LABEL Description="This is a base image, which allows connecting Jenkins agents via JNLP protocols" Vendor="Jenkins project" Version="$VERSION"

ARG user=jenkins

USER root
COPY jenkins-agent /usr/local/bin/jenkins-agent
RUN chmod +x /usr/local/bin/jenkins-agent &&\
    ln -s /usr/local/bin/jenkins-agent /usr/local/bin/jenkins-slave
USER ${user}

ENTRYPOINT ["/usr/local/bin/jenkins-agent"]
