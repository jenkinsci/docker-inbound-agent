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
                                script {
                                    def parallelBuilds = [:]
                                    def images = ['jdk11-windowsservercore-ltsc2019', 'jdk11-nanoserver-1809', 'jdk17-windowsservercore-ltsc2019', 'jdk17-nanoserver-1809']
                                    for (unboundImage in images) {
                                        def image = unboundImage // Bind variable before the closure
                                        // Prepare a map of the steps to run in parallel
                                        parallelBuilds[image] = {
                                            // Allocate a node for each image to avoid filling disk
                                            node('docker-windows') {
                                                // Cleanup the Docker Engine if the machine is reused (to avoid harddrive being filled)
                                                powershell 'docker.exe system prune --volumes --force'
                                                checkout scm
                                                powershell '& ./make.ps1 -Build ' + image + ' test'
                                                junit(allowEmptyResults: true, keepLongStdio: true, testResults: 'target/**/junit-results.xml')
                                            }
                                        }
                                    }
                                    // Peform the parallel execution
                                    parallel parallelBuilds
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
                                        powershell "& ./make.ps1 -PushVersions -VersionTag $tagName publish"
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
                        stage('Prepare Docker BuildX Runner for multi-arch') {
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
