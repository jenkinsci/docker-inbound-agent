pipeline {
    agent { node { label 'jenkins-slave' } }
        environment {
            IMAGE_NAME='capturemedia/docker-jnlp-slave'
            DOCKERHUB_CREDENTIALS='dockerhub-capturemediamachine'
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
                    sh 'make snapshot'
                }
            }
        }
        stage('Release new version') {
            when { buildingTag() }
            steps {
                script {
                    sh 'make release'
                }
            }
        }
    }
}
