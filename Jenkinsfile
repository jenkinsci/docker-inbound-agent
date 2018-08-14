pipeline {
    agent any
    def imageName = "capturemedia/jenkins-slave-jnlp-docker"
    def credentialsId = "dockerhub-capturemediamachine"
    stages {
        stage('Build image') {
            steps {
                echo 'Starting to build docker image'
                checkout scm
                shortCommit = readFile('GIT_COMMIT').take(8)
                tag = sh('git tag --contains ${longCommit}')
                def imageTag = "build-${shortCommit}"
                script {
                    newImage = docker.build(${imageName}:${imageTag})
                    docker.withRegistry("https://hub.docker.com/v2", '${credentialsId}'){
                        newImage.tag("latest", false)
                        newImage.push()

                    }
            }
        }
    }
        stage('Push tagged release') {
            when { buildingTag() }
            steps {
                def imageTag = "release-${TAG_NAME}"
                script {
                    newImage = docker.build('${imageName}':'${imageTag}')
                    docker.withRegistry("https://hub.docker.com/v2", '${credentialsId}'){
                        newImage.tag("latest", false)
                        newImage.push()

                    }
            }
        }
    }
}