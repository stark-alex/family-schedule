#!/usr/bin/env bash
# deploy.sh — push updated schedule.html / schedule.yaml to S3 and bust the CDN cache
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BUCKET=$(cd "$SCRIPT_DIR/terraform" && terraform output -raw s3_bucket_name)
DIST_ID=$(cd "$SCRIPT_DIR/terraform" && terraform output -raw cloudfront_distribution_id)

echo "Syncing to s3://$BUCKET ..."
aws s3 sync "$SCRIPT_DIR" "s3://$BUCKET" \
  --exclude "terraform/*" \
  --exclude ".git/*" \
  --exclude "*.sh" \
  --exclude ".gitignore" \
  --exclude "CLAUDE.md" \
  --cache-control "no-cache, no-store"

echo "Invalidating CloudFront cache ..."
aws cloudfront create-invalidation \
  --distribution-id "$DIST_ID" \
  --paths "/*" \
  --query 'Invalidation.Id' \
  --output text

echo "Done. Changes live at $(cd "$SCRIPT_DIR/terraform" && terraform output -raw schedule_url) in ~30s."
