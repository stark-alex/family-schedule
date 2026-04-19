# Bootstrap — one-time infrastructure setup

Do this once when standing up the project from scratch. Normal deploys only need `./deploy.sh`.

---

## Prerequisites

### AWS CLI

```bash
brew install awscli      # or https://aws.amazon.com/cli/
```

Configure with credentials from your AWS account (**IAM → Users → your user → Security credentials → Create access key**):

```bash
aws configure
# AWS Access Key ID:     AKIA...
# AWS Secret Access Key: ...
# Default region name:  us-east-1
# Default output format: json
```

Verify it works:

```bash
aws sts get-caller-identity
```

### Terraform

```bash
brew install terraform   # or https://developer.hashicorp.com/terraform/install
terraform -version       # must be >= 1.5
```

---

## Step 1 — Register the domain

1. Go to **AWS Console → Route 53 → Registered domains → Register domain**
2. Search for your domain (e.g. `starkfamily.com`), complete the purchase, enable **auto-renew**
3. AWS automatically creates a hosted zone. Go to **Route 53 → Hosted zones**, click your domain, and copy the **Hosted zone ID** (e.g. `Z0ABCDEF1234567`) — you'll need it in Step 4

> DNS propagates in minutes. WHOIS registration takes up to 24–48hr but doesn't block the next steps.

---

## Step 2 — Create Terraform state bucket

Pick a globally unique bucket name (e.g. `stark-tf-state`):

```bash
aws s3 mb s3://stark-tf-state --region us-east-1

aws s3api put-bucket-versioning \
  --bucket stark-tf-state \
  --versioning-configuration Status=Enabled

aws s3api put-public-access-block \
  --bucket stark-tf-state \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
```

Update the bucket name in `terraform/backend.tf` if you used something other than `stark-tf-state`.

---

## Step 3 — Create Google OAuth credentials

1. Go to [console.cloud.google.com](https://console.cloud.google.com) → create a new project (e.g. "Family Schedule")
2. **APIs & Services → OAuth consent screen**
   - User type: **External** → fill in app name + your email → Save
   - Click **Publish App** (required so family members aren't blocked as "test users")
3. **APIs & Services → Credentials → Create credentials → OAuth 2.0 Client ID**
   - Application type: **Web application**
   - Authorized redirect URI: `https://auth.yourdomain.com/oauth2/idpresponse`
     *(use your actual domain)*
   - Create → copy the **Client ID** and **Client Secret**
4. Store them in AWS SSM (keeps secrets out of code and Terraform vars):

```bash
aws ssm put-parameter \
  --name "/family-schedule/google_client_id" \
  --value "YOUR_CLIENT_ID" \
  --type SecureString \
  --region us-east-1

aws ssm put-parameter \
  --name "/family-schedule/google_client_secret" \
  --value "YOUR_CLIENT_SECRET" \
  --type SecureString \
  --region us-east-1
```

---

## Step 4 — Configure Terraform variables

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
domain_name    = "starkfamily.com"   # your actual domain
hosted_zone_id = "Z0ABCDEF1234567"  # from Step 1
```

---

## Step 5 — Apply Terraform (two passes)

The ACM certificate must be created and DNS-validated before the rest of the infrastructure can reference it:

```bash
cd terraform
terraform init

# Pass 1 — create cert + DNS validation records
terraform apply -target=aws_acm_certificate.main -target=aws_route53_record.acm_validation
```

Wait ~2 minutes, then confirm the cert is issued:

```bash
aws acm list-certificates --region us-east-1 \
  --query "CertificateSummaryList[?contains(DomainName, 'yourdomain.com')].Status" \
  --output text
# Wait until it returns: ISSUED
```

```bash
# Pass 2 — everything else (takes 5–10 min; CloudFront distributions are slow to create)
terraform apply
```

---

## Step 6 — Deploy content

```bash
cd ..   # back to repo root
./deploy.sh
```

The site is now live at `https://schedule.yourdomain.com`.

---

## Adding a family member

1. AWS Console → Cognito → User pools → `family-schedule` → Users → **Create user**
2. Enter their email, check **Send an email invitation**
3. They visit the site, get redirected to Google login, and sign in with that email
