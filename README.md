# Docker image for inbound Jenkins agents

[![Join the chat at https://gitter.im/jenkinsci/docker](https://badges.gitter.im/jenkinsci/docker.svg)](https://gitter.im/jenkinsci/docker?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)
[![Docker Stars](https://img.shields.io/docker/stars/jenkins/inbound-agent.svg)](https://hub.docker.com/r/jenkins/inbound-agent/)
[![Docker Pulls](https://img.shields.io/docker/pulls/jenkins/inbound-agent.svg)](https://hub.docker.com/r/jenkins/inbound-agent/)
[![Docker Automated build](https://img.shields.io/docker/automated/jenkins/inbound-agent.svg)](https://hub.docker.com/r/jenkins/inbound-agent/)
[![GitHub release](https://img.shields.io/github/release/jenkinsci/docker-inbound-agent.svg?label=changelog)](https://github.com/jenkinsci/docker-inbound-agent/releases/latest)

:exclamation: **Warning!** This image used to be published as [jenkinsci/jnlp-slave](https://hub.docker.com/r/jenkinsci/jnlp-slave/) and [jenkins/jnlp-slave](https://hub.docker.com/r/jenkins/jnlp-slave/). 
These images are deprecated, use [jenkins/inbound-agent](https://hub.docker.com/r/jenkins/jnlp-slave/).

This is an image for [Jenkins](https://jenkins.io) agents using TCP or WebSockets to establish inbound connection to the Jenkins master.
This agent is powered by the [Jenkins Remoting library](https://github.com/jenkinsci/remoting), which version is being taken from the base [Docker Agent](https://github.com/jenkinsci/docker-agent/) image.

See [Jenkins Distributed builds](https://wiki.jenkins-ci.org/display/JENKINS/Distributed+builds) for more info.

## Running

To run a Docker container

  Linux agent:

    docker run --init jenkins/inbound-agent -url http://jenkins-server:port <secret> <agent name>
  Note: `--init` is necessary for correct subprocesses handling (zombie reaping)

  Windows agent:

    docker run jenkins/jnlp-agent:latest-windows -Url http://jenkins-server:port -Secret <secret> -Name <agent name>

To run a Docker container with [Work Directory](https://github.com/jenkinsci/remoting/blob/master/docs/workDir.md) 

  Linux agent:

    docker run --init jenkins/inbound-agent -url http://jenkins-server:port -workDir=/home/jenkins/agent <secret> <agent name>
    
  Windows agent:

    docker run jenkins/jnlp-agent-windows -Url http://jenkins-server:port -WorkDir=C:/Jenkins/agent -Secret <secret> -Name <agent name>

Optional environment variables:

* `JENKINS_URL`: url for the Jenkins server, can be used as a replacement to `-url` option, or to set alternate jenkins URL
* `JENKINS_TUNNEL`: (`HOST:PORT`) connect to this agent host and port instead of Jenkins server, assuming this one do route TCP traffic to Jenkins master. Useful when when Jenkins runs behind a load balancer, reverse proxy, etc.
* `JENKINS_SECRET`: agent secret, if not set as an argument
* `JENKINS_AGENT_NAME`: agent name, if not set as an argument
* `JENKINS_AGENT_WORKDIR`: agent work directory, if not set by optional parameter `-workDir`
* `JENKINS_WEB_SOCKET`: `true` if the connection should be made via WebSocket rather than TCP

## Configuration specifics

### Enabled JNLP protocols

As of version 3.40-1 this image only supports the [JNLP4-connect](https://github.com/jenkinsci/remoting/blob/master/docs/protocols.md#jnlp4-connect) protocol.
Earlier, long-unsupported protocols have been removed.
As a result, Jenkins versions prior to 2.32 are no longer supported.

### Amazon ECS

Make sure your ECS container agent is [updated](http://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-agent-update.html) before running. Older versions do not properly handle the entryPoint parameter. See the [entryPoint](http://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_definition_parameters.html#container_definitions) definition for more information.
