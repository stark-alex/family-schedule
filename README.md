# family-schedule

A private family schedule viewer hosted on AWS (S3 + CloudFront), protected by Google login via Cognito. Edit `schedule.yaml` and run `./deploy.sh` to update the live site.

---

## Local development

The HTML fetches `schedule.yaml` via `fetch()` and will fail if opened as a `file://` URL. Use a local server:

```bash
python3 -m http.server
# open http://localhost:8000
```

---

## Deploying changes

Requires AWS CLI configured with credentials for the account where the infrastructure lives:

```bash
aws configure        # one-time: enter Access Key ID + Secret + region (us-east-1)
aws sts get-caller-identity  # verify it's working
```

Then to deploy:

```bash
# Edit schedule.yaml (or schedule.html), then:
./deploy.sh
```

Changes are live at `https://schedule.yourdomain.com` within ~30 seconds.

---

## Adding a family member

1. AWS Console → Cognito → User pools → `family-schedule` → Users → **Create user**
2. Enter their email, check **Send an email invitation**
3. They visit the site, get redirected to Google login, and sign in with that email

---

## First-time setup

See [docs/bootstrap.md](docs/bootstrap.md) for the one-time infrastructure setup (domain registration, Terraform, Google OAuth).

---

## Infrastructure overview

All AWS resources are defined as Terraform in `terraform/` (flat files, no nested modules):

| File | What it manages |
|---|---|
| `main.tf` | Providers — default region + `aws.us_east_1` alias (required for CloudFront) |
| `backend.tf` | S3 remote state |
| `dns.tf` | Route 53 records for schedule subdomain, auth subdomain, ACM validation |
| `acm.tf` | Wildcard ACM cert (must be `us-east-1`) |
| `s3.tf` | Private S3 bucket + CloudFront Origin Access Control |
| `cognito.tf` | User Pool + Google IdP + Cognito hosted UI domain |
| `cloudfront.tf` | CloudFront distribution with Lambda@Edge auth on every request |
| `lambda_auth.tf` | Lambda@Edge function — PKCE flow, JWT verification, callback, logout |

**Auth flow:** Every request hits a Lambda@Edge function that checks a JWT cookie. If missing or expired, the user is redirected to the Cognito hosted UI which shows Google login. After auth, a signed JWT is set as a cookie and the user lands on the schedule.
