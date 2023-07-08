pipeline {
    agent none

    options {
        buildDiscarder(logRotator(daysToKeepStr: '10'))
        timestamps()
    }

    stages {
        stage('Build') {
            parallel {
                stage('Windows') {
                    agent {
                        label "docker-windows"
                    }
                    options {
                        timeout(time: 60, unit: 'MINUTES')
                    }
                    environment {
                        DOCKERHUB_ORGANISATION = "${infra.isTrusted() ? 'jenkins' : 'jenkins4eval'}"
                    }
                    stages {
                        stage('Build and Test') {
                            // This stage is the "CI" and should be run on all code changes triggered by a code change
                            when {
                                not { buildingTag() }
                            }
                            steps {
                                powershell '& ./build.ps1 test'
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
                                        // TODO: check if this function has the same beahvior in build.ps1 vs make.ps1
                                        powershell '& ./build.ps1 -PushVersions -VersionTag $env:TAG_NAME publish'
                                    }
                                }
                            }
                        }
                    }
                }
                stage('Linux') {
                    agent {
                        label "docker&&linux"
                    }
                    options {
                        timeout(time: 30, unit: 'MINUTES')
                    }
                    environment {
                        JENKINS_REPO = "${infra.isTrusted() ? 'jenkins' : 'jenkins4eval'}/inbound-agent"
                    }
                    stages {
                        stage('Prepare Docker') {
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
                                sh 'make build'
                                sh 'make test'
                                // If the tests are passing for Linux AMD64, then we can build all the CPU architectures
                                sh 'docker buildx bake --file docker-bake.hcl linux'
                            }
                            post {
                                always {
                                    junit(allowEmptyResults: true, keepLongStdio: true, testResults: 'target/*.xml')
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
                                    // This function is defined in the jenkins-infra/pipeline-library
                                    infra.withDockerCredentials {
                                        sh '''
                                        export IMAGE_TAG="${TAG_NAME}"
                                        export ON_TAG=true
                                        docker buildx bake --push --file docker-bake.hcl linux
                                        '''
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
