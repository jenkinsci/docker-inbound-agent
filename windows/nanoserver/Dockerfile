# escape=`
# The MIT License
#
#  Copyright (c) 2019, Alex Earl
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

ARG version=3192.v713e3b_039fb_e-2
ARG JAVA_MAJOR_VERSION=17
ARG WINDOWS_VERSION_TAG=1809
FROM jenkins/agent:"${version}"-jdk"${JAVA_MAJOR_VERSION}"-nanoserver-"${WINDOWS_VERSION_TAG}"

COPY jenkins-agent.ps1 C:/ProgramData/Jenkins
ENTRYPOINT ["pwsh.exe", "-f", "C:/ProgramData/Jenkins/jenkins-agent.ps1"]
