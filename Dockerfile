# The MIT License
#
#  Copyright (c) 2015, CloudBees, Inc.
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

FROM jenkinsci/slave:3.14-1
LABEL maintainer=devops@prominentedge.com

USER root

COPY jenkins-slave /usr/local/bin/jenkins-slave

ENV BUILD_PACKAGES apt-transport-https \
            build-essential \
            ca-certificates \
            curl \
            lsb-release \
            software-properties-common

ENV RUNTIME_PACKAGES apt-transport-https \
            awscli \
            docker-ce=17.03.1~ce-0~ubuntu-xenial

RUN apt-get update && \
    apt-get install -y --no-install-recommends $BUILD_PACKAGES && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - && \
    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu xenial stable" && \
    apt-get update && \
    apt-get install -y $RUNTIME_PACKAGES

RUN wget https://github.com/kelseyhightower/confd/releases/download/v0.14.0/confd-0.14.0-linux-amd64 && \
    mv confd-0.14.0-linux-amd64 /usr/local/bin/confd && \
    chmod 755 /usr/local/bin/confd && \
    curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get | bash && \
    curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl && \
    chmod +x ./kubectl && \
    mv ./kubectl /usr/local/bin/kubectl

RUN wget https://bootstrap.pypa.io/get-pip.py && \
    python get-pip.py && \
    pip install \
        elasticsearch-curator==5.4.0

# Clean up
#RUN apt-get remove -y --purge $BUILD_PACKAGES $RUNTIME_PACKAGES && \
#    rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["jenkins-slave"]
