#!/usr/bin/env bash
set -euo pipefail

sudo dnf update -y
sudo dnf install -y docker awscli
sudo systemctl enable --now docker
sudo usermod -aG docker ec2-user || true

echo "App EC2 host is ready. Attach an IAM role with ECR read access before deployment."

