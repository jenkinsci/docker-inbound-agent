pipeline {
    agent none

    options {
        buildDiscarder(logRotator(daysToKeepStr: '10'))
    }

    stages {
        stage('docker-inbound-agent') {
            failFast true
            matrix {
                axes {
                    axis {
                        name 'AGENT_TYPE'
                        values 'linux', 'windows-2019', 'windows-2022'
                    }
                }
                stages {
                    stage('Main') {
                        agent {
                            label env.AGENT_TYPE
                        }
                        options {
                            timeout(time: 30, unit: 'MINUTES')
                        }
                        environment {
                            DOCKERHUB_ORGANISATION = "${infra.isTrusted() ? 'jenkins' : 'jenkins4eval'}"
                        }
                        stages {
                            stage('Prepare Docker') {
                                when {
                                    environment name: 'AGENT_TYPE', value: 'linux'
                                }
                                steps {
                                    sh '''
                                    docker buildx create --use
                                    docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
                                    '''
                                }
                            }
                            stage('Build and Test') {
                                // This stage is the "CI" and should be run on all code changes triggered by a code change
                                when {
                                    not { buildingTag() }
                                }
                                steps {
                                    script {
                                        if(isUnix()) {
                                            sh 'make build'
                                            sh 'make test'
                                            // If the tests are passing for Linux AMD64, then we can build all the CPU architectures
                                            sh 'docker buildx bake --file docker-bake.hcl linux'
                                        } else {
                                            powershell '& ./build.ps1 test'
                                        }
                                    }
                                }
                                post {
                                    always {
                                        junit(allowEmptyResults: true, keepLongStdio: true, testResults: 'target/**/junit-results.xml')
                                    }
                                }
                            }
                            stage('Deploy to DockerHub') {
                                // This stage is the "CD" and should only be run when a tag triggered the build
                                when {
                                    buildingTag()
                                }
                                steps {
                                    script {
                                        infra.withDockerCredentials {
                                            if (isUnix()) {
                                                sh '''
                                                export IMAGE_TAG="${TAG_NAME}"
                                                export ON_TAG=true
                                                docker buildx bake --push --file docker-bake.hcl linux
                                                '''
                                            } else {
                                                powershell '& ./build.ps1 -PushVersions -VersionTag $env:TAG_NAME publish'
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

// vim: ft=groovy
