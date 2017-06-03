#!groovy
@Library('juiceinc-library') _

pipeline {
  agent  { label 'python-ecs' }
  stages {
    stage('Starting') {
      steps {
        sendNotifications 'STARTED'
      }
    }
    stage('Docker Build') {
      steps {
        sh 'env=dev make docker_build'
      }
    }
    stage('Docker Publish') {
      when {
        expression {
           BRANCH_NAME == "master"
        }
      }
      steps{
        sh '''export AWS_DEFAULT_REGION=us-east-1
ACCOUNT_NUMBER=423681189101
$(aws ecr get-login --registry-ids $ACCOUNT_NUMBER  --region us-east-1)
make docker_publish'''
      }
    }
  }
  post {
    always {
      sendNotifications currentBuild.result
    }
  }
}
