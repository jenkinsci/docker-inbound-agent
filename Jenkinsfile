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
                shortCommit = sh(returnStdout: true, script: "git log -n 1 --pretty=format:'%h'").trim().take(8)
                def imageTag = "build-${shortCommit}"
                def image= "${env.IMAGE_NAME}:${imageTag}"
                echo 'Starting to build docker image ${env.IMAGE_NAME}:${imageTag}'
                newImage = docker.build("${image}")
                    docker.withRegistry('https://registry.hub.docker.com', "${env.DOCKERHUB_CREDENTIALS_ID}"){
                        newImage.push()
                    }       
                }
            }
        }
        stage('Push tagged release') {
            when { buildingTag() }
            steps {
                script {
                    def imageTag = "release-${TAG_NAME}"
                    def image= "${env.IMAGE_NAME}:${imageTag}"
                    newImage = docker.build("${image}")
                    docker.withRegistry('https://registry.hub.docker.com', "${env.DOCKERHUB_CREDENTIALS_ID}"){
                        newImage.push()
                    }
                }
            }
        }
    }
}