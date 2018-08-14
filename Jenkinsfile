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
                tag = sh('git tag --contains ${longCommit}')
                shortCommit = readFile('GIT_COMMIT').take(8)
                def imageTag = "build-${shortCommit}"
                def image= "${env.IMAGE_NAME}:${imageTag}"
                echo 'Starting to build docker image ${env.IMAGE_NAME}:${imageTag}'
                
                    docker.withRegistry("https://hub.docker.com/v2", '${env.DOCKERHUB_CREDENTIALS_ID}'){
                        newImage = docker.build('${image}')
                        newImage.tag("latest", false)
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
                    docker.withRegistry("https://hub.docker.com/v2", '${env.DOCKERHUB_CREDENTIALS_ID}'){
                        newImage = docker.build('${imageName}':'${imageTag}')
                        newImage.tag("latest", false)
                        newImage.push()
                       }
                    }
                
            }
        }
    }
}