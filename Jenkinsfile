pipeline {
    agent any
        environment {
            IMAGE_NAME='capturemedia/jenkins-slave-jnlp-docker'
            DOCKERHUB_CREDENTIALS_ID='dockerhub-capturemediamachine'
        }
    stages {
        stage('Build image') {
            steps {
                script {
                sh 'make build'
                }
            }
        }
        stage('Push image') {
            steps {
                script {
                    docker.withRegistry('https://registry.hub.docker.com', "${env.DOCKERHUB_CREDENTIALS_ID}"){
                        sh 'make snapshot'
                    }
                }
            }
        }
        stage('Release new version') {
            steps {
                script {
                    docker.withRegistry('https://registry.hub.docker.com', "${env.DOCKERHUB_CREDENTIALS_ID}"){
                        sh 'make release'
                    }
                    }
                }
            }
        }
    }
}