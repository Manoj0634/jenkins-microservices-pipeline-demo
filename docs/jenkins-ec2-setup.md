# Jenkins and SonarQube on EC2

These steps use one EC2 instance for Jenkins plus SonarQube, and two separate EC2 instances for application hosting.

## 1. Jenkins EC2

Recommended demo shape:

- Amazon Linux 2023
- At least `t3.medium` for Jenkins only
- Prefer `t3.large` or larger when running Jenkins and SonarQube together
- Security group inbound:
  - `22` from your IP
  - `8080` from your IP or demo network
  - `9000` from your IP or demo network

Attach an IAM role using `infra/aws/iam/jenkins-policy.json`.

Run:

```bash
chmod +x infra/jenkins/bootstrap_jenkins_ec2_amazon_linux.sh
./infra/jenkins/bootstrap_jenkins_ec2_amazon_linux.sh
cd infra/jenkins
docker compose up -d --build
```

Jenkins opens on:

```text
http://JENKINS_EC2_PUBLIC_DNS:8080
```

SonarQube opens on:

```text
http://JENKINS_EC2_PUBLIC_DNS:9000
```

## 2. Jenkins Configuration

Install or verify these plugins:

- Pipeline
- Git
- GitHub
- Credentials Binding
- SSH Agent
- SonarQube Scanner
- JUnit
- Timestamper
- ANSI Color
- Workspace Cleanup

In `Manage Jenkins > System`, add a SonarQube server named exactly:

```text
SonarQube
```

Create a SonarQube token in SonarQube and add it to the Jenkins SonarQube server config.

For SonarQube quality gates to work, create a SonarQube webhook pointing back to Jenkins:

```text
http://JENKINS_EC2_PUBLIC_DNS:8080/sonarqube-webhook/
```

## 3. App EC2 Hosts

Create two app EC2 instances:

- `stable`
- `canary`

Attach an IAM role that can pull from ECR:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchGetImage",
        "ecr:GetDownloadUrlForLayer"
      ],
      "Resource": "*"
    }
  ]
}
```

On each app EC2 host:

```bash
chmod +x deploy/scripts/bootstrap_app_ec2_amazon_linux.sh
./deploy/scripts/bootstrap_app_ec2_amazon_linux.sh
```

Security group inbound:

- `22` from Jenkins EC2 security group
- `80` from the internet or demo network

## 4. Jenkins Credentials

Create these Jenkins credentials:

```text
app-ec2-ssh-key
stable-host
canary-host
stable-target
canary-target
route53-hosted-zone-id
route53-record-name
```

Use the app EC2 public DNS names for `stable-target` and `canary-target` when using the included Route 53 weighted CNAME script.

