#!/usr/bin/env bash
# build.sh — compile the Go API Lambda and produce terraform/lambda/api.zip
# Run this before `terraform apply` or `deploy.sh` when api/ code changes.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Building Go API Lambda (linux/arm64)..."
cd "$SCRIPT_DIR/api"

# First-time setup: populate go.sum from go.mod
if [[ ! -f go.sum ]]; then
  echo "  Running go mod tidy (first-time setup)..."
  go mod tidy
fi

GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build -tags lambda.norpc -o bootstrap .
zip -j "$SCRIPT_DIR/terraform/lambda/api.zip" bootstrap
rm bootstrap

echo "Built terraform/lambda/api.zip"
