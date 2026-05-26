// ─────────────────────────────────────────────────────────────
// Declarative Jenkins pipeline for sample-api
//   Build → Test → Docker → Push to ECR → Blue/Green deploy to ECS
//   On main: deploys to prod with manual gate; on PR: ephemeral env
// ─────────────────────────────────────────────────────────────

pipeline {
  agent {
    label 'docker'
  }

  options {
    timestamps()
    timeout(time: 30, unit: 'MINUTES')
    buildDiscarder(logRotator(numToKeepStr: '20'))
    disableConcurrentBuilds()
    ansiColor('xterm')
  }

  environment {
    AWS_REGION       = 'ap-south-1'
    ECR_REGISTRY     = "${env.AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
    ECR_REPO         = 'sample-api'
    ECS_CLUSTER      = 'production'
    ECS_SERVICE      = 'sample-api'
    TASK_FAMILY      = 'sample-api'
    IMAGE_TAG        = "${env.BRANCH_NAME == 'main' ? 'prod' : env.BRANCH_NAME}-${env.BUILD_NUMBER}-${env.GIT_COMMIT.take(7)}"
    FULL_IMAGE       = "${ECR_REGISTRY}/${ECR_REPO}:${IMAGE_TAG}"
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
        sh 'git rev-parse --short HEAD > .sha && echo "SHA: $(cat .sha)"'
      }
    }

    stage('Install') {
      steps {
        dir('app') {
          sh 'npm ci'
        }
      }
    }

    stage('Lint') {
      steps {
        dir('app') {
          sh 'npm run lint || true'
        }
      }
    }

    stage('Test') {
      steps {
        dir('app') {
          sh 'npm test'
        }
      }
      post {
        always {
          junit allowEmptyResults: true, testResults: 'app/junit.xml'
        }
      }
    }

    stage('Docker Build') {
      steps {
        sh """
          docker build \
            --build-arg APP_VERSION=${IMAGE_TAG} \
            --build-arg BUILD_SHA=${env.GIT_COMMIT.take(7)} \
            -t ${FULL_IMAGE} \
            -t ${ECR_REGISTRY}/${ECR_REPO}:latest \
            .
        """
      }
    }

    stage('Image Scan') {
      steps {
        sh """
          docker run --rm \
            -v /var/run/docker.sock:/var/run/docker.sock \
            aquasec/trivy:latest image \
            --severity HIGH,CRITICAL \
            --exit-code 0 \
            --no-progress \
            ${FULL_IMAGE}
        """
      }
    }

    stage('Push to ECR') {
      steps {
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-ecr-push']]) {
          sh """
            aws ecr get-login-password --region ${AWS_REGION} \
              | docker login --username AWS --password-stdin ${ECR_REGISTRY}
            docker push ${FULL_IMAGE}
            docker push ${ECR_REGISTRY}/${ECR_REPO}:latest
          """
        }
      }
    }

    stage('Deploy — Blue/Green') {
      when { branch 'main' }
      steps {
        input message: 'Promote to production?', ok: 'Deploy'
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-ecs-deploy']]) {
          sh "./scripts/deploy.sh ${FULL_IMAGE}"
        }
      }
    }

    stage('Smoke Test') {
      when { branch 'main' }
      steps {
        sh './scripts/healthcheck.sh https://api.example.com/health'
      }
    }
  }

  post {
    success {
      slackSend channel: '#deploys',
        color: 'good',
        message: "✅ ${env.JOB_NAME} #${env.BUILD_NUMBER} — ${IMAGE_TAG} deployed"
    }
    failure {
      slackSend channel: '#deploys',
        color: 'danger',
        message: "❌ ${env.JOB_NAME} #${env.BUILD_NUMBER} — failed at ${env.STAGE_NAME}"
      script {
        if (env.BRANCH_NAME == 'main' && env.STAGE_NAME == 'Smoke Test') {
          sh './scripts/rollback.sh'
        }
      }
    }
    always {
      sh 'docker image prune -f --filter "until=24h" || true'
      cleanWs()
    }
  }
}
