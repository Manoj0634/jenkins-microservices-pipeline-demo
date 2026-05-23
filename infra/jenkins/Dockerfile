FROM jenkins/jenkins:lts-jdk17

USER root

ARG SONAR_SCANNER_VERSION=6.2.1.4610

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    awscli \
    ca-certificates \
    curl \
    docker.io \
    git \
    maven \
    nodejs \
    npm \
    unzip \
  && curl -fsSL "https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-${SONAR_SCANNER_VERSION}-linux-x64.zip" -o /tmp/sonar-scanner.zip \
  && unzip /tmp/sonar-scanner.zip -d /opt \
  && ln -s "/opt/sonar-scanner-${SONAR_SCANNER_VERSION}-linux-x64/bin/sonar-scanner" /usr/local/bin/sonar-scanner \
  && rm -rf /var/lib/apt/lists/* /tmp/sonar-scanner.zip

USER jenkins

RUN jenkins-plugin-cli --plugins \
  ansicolor \
  credentials-binding \
  git \
  github \
  junit \
  pipeline-stage-view \
  sonar \
  ssh-agent \
  timestamper \
  workflow-aggregator \
  ws-cleanup

