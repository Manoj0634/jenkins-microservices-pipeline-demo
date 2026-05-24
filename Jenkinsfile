def serviceCatalog() {
  return [
    'springboot-api': [
      path: 'services/springboot-api',
      containerPort: '8080',
      smokePort: '18080',
      healthPath: '/health'
    ],
    'node-api': [
      path: 'services/node-api',
      containerPort: '3000',
      smokePort: '13000',
      healthPath: '/health'
    ],
    'static-site': [
      path: 'services/static-site',
      containerPort: '80',
      smokePort: '18000',
      healthPath: '/'
    ]
  ]
}

def resolveServices() {
  def services = serviceCatalog()

  if (params.SERVICE == 'all') {
    return services.keySet() as List
  }

  if (params.SERVICE != 'changed') {
    return [params.SERVICE]
  }

  def hasPreviousCommit = sh(returnStatus: true, script: 'git rev-parse HEAD~1 >/dev/null 2>&1') == 0
  if (!hasPreviousCommit) {
    return services.keySet() as List
  }

  def changedText = sh(returnStdout: true, script: 'git diff --name-only HEAD~1..HEAD').trim()
  if (!changedText) {
    return services.keySet() as List
  }

  def changedFiles = changedText.split('\n') as List
  def selected = services.findAll { serviceName, cfg ->
    changedFiles.any { it.startsWith("${cfg.path}/") }
  }.keySet() as List

  return selected ?: services.keySet() as List
}

def runTests(String serviceName, Map cfg) {
  dir(cfg.path) {
    if (fileExists('pom.xml')) {
      sh 'mvn -B clean test'
      junit allowEmptyResults: true, testResults: 'target/surefire-reports/*.xml'
    } else if (fileExists('package.json')) {
      sh '''
        if [ -f package-lock.json ]; then
          npm ci
        else
          npm install
        fi

        if npm run | grep -q " test"; then
          npm test
        else
          echo "No npm test script found. Skipping Node/static tests."
        fi
      '''
      junit allowEmptyResults: true, testResults: 'junit.xml'
    } else {
      sh 'test -f index.html || true'
    }
  }
}

def runSonarCloud() {
  def scannerHome = tool 'SonarScanner'

  withSonarQubeEnv(env.SONARQUBE_ENV) {
    sh """
      ${scannerHome}/bin/sonar-scanner \
        -Dsonar.projectKey=cicd-demo0634 \
        -Dsonar.organization=manoj-devops \
        -Dsonar.sources=services \
        -Dsonar.host.url=\$SONAR_HOST_URL \
        -Dsonar.token=\$SONAR_AUTH_TOKEN \
        -Dsonar.exclusions=**/node_modules/**,**/coverage/**,**/dist/**,**/build/**,**/target/**
    """
  }
}

def buildAndPushImage(String serviceName, Map cfg, String imageTag) {
  def accountId = sh(returnStdout: true, script: 'aws sts get-caller-identity --query Account --output text').trim()
  def registry = "${accountId}.dkr.ecr.${params.AWS_REGION}.amazonaws.com"

  /*
   Your ECR repositories are:
   springboot-api
   node-api
   static-site

   So repository name should be serviceName directly.
  */
  def repository = serviceName

  def remoteImage = "${registry}/${repository}:${imageTag}"
  def latestImage = "${registry}/${repository}:latest"

  sh "aws ecr describe-repositories --region ${params.AWS_REGION} --repository-names ${repository}"

  sh "aws ecr get-login-password --region ${params.AWS_REGION} | docker login --username AWS --password-stdin ${registry}"

  dir(cfg.path) {
    sh "docker build --pull -t ${serviceName}:${imageTag} ."
    sh "docker tag ${serviceName}:${imageTag} ${remoteImage}"
    sh "docker tag ${serviceName}:${imageTag} ${latestImage}"
  }

  smokeTestImage(serviceName, cfg, remoteImage)

  sh "docker push ${remoteImage}"
  sh "docker push ${latestImage}"

  return remoteImage
}

def smokeTestImage(String serviceName, Map cfg, String imageUri) {
  def containerName = "smoke-${serviceName}-${env.BUILD_NUMBER}"

  try {
    sh "docker rm -f ${containerName} >/dev/null 2>&1 || true"

    sh """
      docker run -d \
        --name ${containerName} \
        -p ${cfg.smokePort}:${cfg.containerPort} \
        ${imageUri}
    """

    sh """
      for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
        if curl -fsS http://localhost:${cfg.smokePort}${cfg.healthPath}; then
          exit 0
        fi
        sleep 2
      done

      docker logs ${containerName}
      exit 1
    """
  } finally {
    sh "docker rm -f ${containerName} >/dev/null 2>&1 || true"
  }
}

def validateCanaryWeight() {
  if (!(params.CANARY_WEIGHT ==~ /[0-9]+/)) {
    error('CANARY_WEIGHT must be an integer from 0 to 100')
  }

  def weight = params.CANARY_WEIGHT as Integer

  if (weight < 0 || weight > 100) {
    error('CANARY_WEIGHT must be between 0 and 100')
  }
}

def selectedServices = []
def imageUris = [:]

pipeline {
  agent any

  options {
    ansiColor('xterm')
    buildDiscarder(logRotator(numToKeepStr: '20'))
    disableConcurrentBuilds()
    timestamps()
  }

  triggers {
    githubPush()
  }

  parameters {
    choice(
      name: 'SERVICE',
      choices: ['changed', 'all', 'springboot-api', 'node-api', 'static-site'],
      description: 'Service to build. Use changed for GitHub push-triggered builds.'
    )

    choice(
      name: 'DEPLOY_MODE',
      choices: ['none', 'stable', 'canary'],
      description: 'none only builds, stable deploys to both EC2 hosts, canary deploys only to canary host.'
    )

    string(
      name: 'CANARY_WEIGHT',
      defaultValue: '10',
      description: 'Route 53 percentage for canary when DEPLOY_MODE=canary.'
    )

    string(
      name: 'AWS_REGION',
      defaultValue: 'us-east-2',
      description: 'AWS region for ECR.'
    )

    string(
      name: 'PUBLIC_PORT',
      defaultValue: '80',
      description: 'Public port exposed on app EC2 hosts.'
    )
  }

  environment {
    SONARQUBE_ENV = 'SonarQubeCloud'
    SSH_CREDENTIALS_ID = 'app-ec2-ssh-key'
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Resolve Services') {
      steps {
        script {
          validateCanaryWeight()

          selectedServices = resolveServices()

          if (params.DEPLOY_MODE != 'none' && selectedServices.size() != 1) {
            error('Deployment demo expects exactly one service. Set SERVICE to springboot-api, node-api, or static-site.')
          }

          echo "Selected services: ${selectedServices.join(', ')}"
        }
      }
    }

    stage('Unit Tests') {
      steps {
        script {
          def services = serviceCatalog()

          selectedServices.each { serviceName ->
            runTests(serviceName, services[serviceName])
          }
        }
      }
    }

    stage('Docker Build, Smoke Test, Push') {
      steps {
        script {
          def services = serviceCatalog()
          def shortCommit = env.GIT_COMMIT ? env.GIT_COMMIT.take(8) : 'local'
          def imageTag = "${env.BUILD_NUMBER}-${shortCommit}"

          selectedServices.each { serviceName ->
            imageUris[serviceName] = buildAndPushImage(serviceName, services[serviceName], imageTag)
          }
        }
      }
    }

    stage('Deploy to EC2 and Update Route 53') {
      when {
        expression { params.DEPLOY_MODE != 'none' }
      }

      steps {
        script {
          def services = serviceCatalog()
          def serviceName = selectedServices[0]
          def cfg = services[serviceName]
          def canaryWeight = params.DEPLOY_MODE == 'canary' ? params.CANARY_WEIGHT : '0'

          withCredentials([
            string(credentialsId: 'stable-host', variable: 'STABLE_HOST'),
            string(credentialsId: 'canary-host', variable: 'CANARY_HOST'),
            string(credentialsId: 'stable-target', variable: 'STABLE_TARGET'),
            string(credentialsId: 'canary-target', variable: 'CANARY_TARGET'),
            string(credentialsId: 'route53-hosted-zone-id', variable: 'HOSTED_ZONE_ID'),
            string(credentialsId: 'route53-record-name', variable: 'DNS_NAME')
          ]) {
            withEnv([
              "SERVICE_NAME=${serviceName}",
              "IMAGE_URI=${imageUris[serviceName]}",
              "DEPLOY_MODE=${params.DEPLOY_MODE}",
              "CONTAINER_PORT=${cfg.containerPort}",
              "PUBLIC_PORT=${params.PUBLIC_PORT}",
              "AWS_REGION_PARAM=${params.AWS_REGION}",
              "STABLE_HOST=${STABLE_HOST}",
              "CANARY_HOST=${CANARY_HOST}",
              "CANARY_WEIGHT_EFFECTIVE=${canaryWeight}"
            ]) {
              sshagent(credentials: [env.SSH_CREDENTIALS_ID]) {
                sh '''
                  chmod +x deploy/scripts/deploy_ec2.sh
                  deploy/scripts/deploy_ec2.sh "$SERVICE_NAME" "$IMAGE_URI" "$DEPLOY_MODE" "$CONTAINER_PORT" "$PUBLIC_PORT" "$AWS_REGION_PARAM"
                '''
              }

              sh '''
                chmod +x deploy/scripts/update_route53_weighted.sh
                deploy/scripts/update_route53_weighted.sh "$HOSTED_ZONE_ID" "$DNS_NAME" "$STABLE_TARGET" "$CANARY_TARGET" "$CANARY_WEIGHT_EFFECTIVE"
              '''
            }
          }
        }
      }
    }
  }

  post {
    success {
      echo 'Pipeline completed successfully.'
    }

    failure {
      echo 'Pipeline failed. Check Jenkins console output.'
    }

    always {
      cleanWs deleteDirs: true, notFailBuild: true
    }
  }
}
