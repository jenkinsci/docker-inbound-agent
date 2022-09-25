pipeline {
    agent none

    options {
        buildDiscarder(logRotator(daysToKeepStr: '10'))
        timestamps()
    }

    triggers {
        pollSCM('H/24 * * * *') // once a day in case some hooks are missed
    }

    stages {
        stage('Build') {
            matrix {

                axes {
                    axis {
                        name 'OS'
                        values 'linux', 'windows'
                    }

                    axis {
                        name 'IMAGE_NAME'
                        values 'linux', 'jdk11-windowsservercore-ltsc2019', 'jdk11-nanoserver-1809', 'jdk17-windowsservercore-ltsc2019', 'jdk17-nanoserver-1809'
                    }
                }

                excludes {
                    exclude {
                        axis {
                            name 'OS'
                            values 'windows'
                        }

                        axis {
                            name 'IMAGE_NAME'
                            values 'linux'
                        }
                    }

                    exclude {
                        axis {
                            name 'OS'
                            values 'linux'
                        }

                        axis {
                            name 'IMAGE_NAME'
                            notValues 'linux'
                        }
                    }
                }

                stages {
                    stage('Windows') {
                        agent {
                            label 'docker-windows'
                        }
                        when {
                            beforeAgent true                            
                            when { environment name: 'OS', value: 'windows' }
                        }
                        options {
                            timeout(time: 60, unit: 'MINUTES')
                        }
                        environment {
                            DOCKERHUB_ORGANISATION = "${infra.isTrusted() ? 'jenkins' : 'jenkins4eval'}"
                        }
                        steps {
                            powershell "& ./make.ps1 test"
                            script {
                                def branchName = "${env.BRANCH_NAME}"
                                if (branchName ==~ 'master') {
                                    // we can't use dockerhub builds for windows
                                    // so we publish here
                                    infra.withDockerCredentials {
                                        powershell '& ./make.ps1 publish'
                                    }
                                }

                                def tagName = "${env.TAG_NAME}"
                                if(tagName =~ /\d(\.\d)+(-\d+)?/) {
                                    // we need to build and publish the tagged version
                                    infra.withDockerCredentials {
                                        powershell "& ./make.ps1 -PushVersions -VersionTag $tagName publish"
                                    }
                                }
                            }
                        }
                        post {
                            always {
                                junit(allowEmptyResults: true, keepLongStdio: true, testResults: 'target/**/junit-results.xml')
                            }
                        }
                    }

                    stage('Linux') {
                        agent {
                            label "docker&&linux"
                        }
                        when {
                            beforeAgent true
                            when { environment name: 'OS', value: 'linux' }
                        }
                        options {
                            timeout(time: 30, unit: 'MINUTES')
                        }
                        environment {
                            JENKINS_REPO = "${infra.isTrusted() ? 'jenkins' : 'jenkins4eval'}/inbound-agent"
                        }
                        steps {
                            script {
                                def branchName = "${env.BRANCH_NAME}"
                                infra.withDockerCredentials {
                                    if (branchName ==~ 'master') {
                                        // publish the images to Dockerhub
                                            sh '''
                                            docker buildx create --use
                                            docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
                                            docker buildx bake --push --file docker-bake.hcl linux
                                            '''
                                    } else if (env.TAG_NAME == null) {
                                        sh 'make build'
                                        sh 'make test'
                                        sh '''
                                            docker buildx create --use
                                            docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
                                            docker buildx bake --file docker-bake.hcl linux
                                        '''
                                    }
                                }

                                if(env.TAG_NAME != null) {
                                    def tagItems = env.TAG_NAME.split('-')
                                    if(tagItems.length == 2) {
                                        def remotingVersion = tagItems[0]
                                        def buildNumber = tagItems[1]
                                        // we need to build and publish the tag version
                                        infra.withDockerCredentials {
                                            sh """
                                            docker buildx create --use
                                            docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
                                            export REMOTING_VERSION=$remotingVersion
                                            export BUILD_NUMBER=$buildNumber
                                            export ON_TAG=true
                                            docker buildx bake --push --file docker-bake.hcl linux
                                            """
                                        }
                                    }
                                }
                            }
                        }
                        post {
                            always {
                                junit(allowEmptyResults: true, keepLongStdio: true, testResults: 'target/*.xml')
                            }
                        }
                    }
                }
            }
        }
    }
}

// vim: ft=groovy
