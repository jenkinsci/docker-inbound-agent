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
                echo 'Starting to build docker image'
                checkout scm
                shortCommit = readFile('GIT_COMMIT').take(8)
                tag = sh('git tag --contains ${longCommit}')
                def imageTag = "build-${shortCommit}"
                def image= "${env.IMAGE_NAME}:${imageTag}"
                script {
                    newImage = docker.build('${image}')
                    docker.withRegistry("https://hub.docker.com/v2", '${env.DOCKERHUB_CREDENTIALS_ID}'){
                        newImage.tag("latest", false)
                        newImage.push()
                    }
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
                script {
                    newImage = docker.build('${imageName}':'${imageTag}')
                    docker.withRegistry("https://hub.docker.com/v2", '${env.DOCKERHUB_CREDENTIALS_ID}'){
                        newImage.tag("latest", false)
                        newImage.push()
                       }
                    }
                }
            }
        }
    }
}