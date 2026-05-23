# Upload This Project Using Only the GitHub Website

You do not need Git installed on your Mac for this demo.

## 1. Create an Empty GitHub Repository

1. Open GitHub in your browser.
2. Click `New repository`.
3. Repository name example:

```text
jenkins-microservices-pipeline-demo
```

4. Keep it empty for the easiest upload:
   - Do not add README
   - Do not add `.gitignore`
   - Do not add license

5. Click `Create repository`.

## 2. Upload the Files

1. On the empty repository page, click `uploading an existing file`.
2. Drag the project files and folders into GitHub.
3. Use this commit message:

```text
initial Jenkins microservices pipeline demo
```

4. Click `Commit changes`.

GitHub may not accept dragging a ZIP file as source code. If that happens, unzip `jenkins-microservices-demo.zip` on your Mac first, then drag the extracted files and folders into GitHub.

## 3. Trigger Jenkins from GitHub

After Jenkins is set up, add a GitHub webhook:

```text
http://JENKINS_EC2_PUBLIC_DNS:8080/github-webhook/
```

Then edit a file online in GitHub, for example:

```text
services/node-api/src/app.js
```

Change the message text, commit directly to `main`, and Jenkins should trigger automatically.

