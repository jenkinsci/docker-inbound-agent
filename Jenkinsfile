/* NOTE: this Pipeline mainly aims at catching mistakes (wrongly formed Dockerfile, etc.)
 * This Pipeline is *not* used for actual image publishing.
 * This is currently handled through Automated Builds using standard Docker Hub feature
*/
pipeline {
    agent none

    options {
        timeout(time: 30, unit: 'MINUTES')
        buildDiscarder(logRotator(daysToKeepStr: '10'))
        timestamps()
    }

    triggers {
        pollSCM('H/24 * * * *') // once a day in case some hooks are missed
    }

    stages {
        stage('Build Docker Image') {
            parallel {
                stage('Windows') {
                    agent {
                        label 'windock'
                    }
                    environment {
                        DOCKERHUB_ORGANISATION = 'jenkins4eval'
                    }
                    steps {
                        script {
                            // we can't use dockerhub builds for windows
                            // so we publish here
                            if (infra.isTrusted()) {
                                env.DOCKERHUB_ORGANISATION = 'jenkins'
                            }
                            infra.withDockerCredentials {
                                powershell '& ./make.ps1 publish'
                            }
                            
                            powershell '& docker system prune --force --all'
                        }
                        
                    }
                }
                stage('Linux') {
                    agent {
                        label "docker&&linux"
                    }
                    steps {                        
                        script {
                            if(!infra.isTrusted()) {                                
                                deleteDir()
                                checkout scm
                                sh "make build ; docker system prune --force --all"
                            }
                        }
                    }
                }
            }
        }
    }
}

// vim: ft=groovy
