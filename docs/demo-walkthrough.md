# Demo Walkthrough

Use this flow when you need to demonstrate the full Jenkins CI/CD pipeline.

## 1. Push Repo to GitHub

Create a GitHub repo, push this project, and create a Jenkins Pipeline or Multibranch Pipeline job from that GitHub repo.

In GitHub, create a webhook:

```text
Payload URL: http://JENKINS_EC2_PUBLIC_DNS:8080/github-webhook/
Content type: application/json
Events: Just the push event
```

## 2. First Stable Deployment

Run Jenkins manually:

```text
SERVICE=node-api
DEPLOY_MODE=stable
CANARY_WEIGHT=0
```

Expected result:

- Jenkins checks out GitHub source.
- Unit tests run.
- SonarQube analysis and quality gate run.
- Docker image is built and smoke-tested.
- Image is pushed to ECR.
- Stable and canary EC2 hosts are updated to the same image.
- Route 53 sends 100 percent to stable and 0 percent to canary.

Open:

```text
http://app.example.com/health
```

Replace `app.example.com` with your Route 53 record.

## 3. Canary Deployment

Run Jenkins again:

```text
SERVICE=node-api
DEPLOY_MODE=canary
CANARY_WEIGHT=10
```

Expected result:

- Only the canary EC2 host receives the new image.
- Route 53 sends 90 percent to stable and 10 percent to canary.

You can increase `CANARY_WEIGHT` to `25`, `50`, and finally run `DEPLOY_MODE=stable` to promote.

## 4. Demonstrate GitHub Trigger

Make a tiny app change:

```bash
sed -i.bak "s/Hello from Node through Jenkins/Hello from GitHub-triggered Jenkins/" services/node-api/src/app.js
rm services/node-api/src/app.js.bak
git add services/node-api/src/app.js
git commit -m "demo: trigger Jenkins pipeline"
git push
```

Jenkins should start automatically from the GitHub webhook.

## 5. Demonstrate Multi-Stack Support

Run the pipeline with:

```text
SERVICE=springboot-api
DEPLOY_MODE=none
```

Then run:

```text
SERVICE=static-site
DEPLOY_MODE=none
```

This shows that the same Jenkinsfile can handle Spring Boot, Node, and static HTML/CSS services.

