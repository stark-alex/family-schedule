# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Running the app locally

Open via a local HTTP server — the HTML fetches `schedule.yaml` via `fetch()` and will fail with a `file://` URL:

```
python3 -m http.server
# then open http://localhost:8000
```

## Deploying

After the Terraform infrastructure is applied, push content changes with:

```bash
./deploy.sh
```

This syncs `schedule.html` and `schedule.yaml` to S3 and invalidates the CloudFront cache.

## Infrastructure

All AWS infrastructure is defined in `terraform/` (flat file structure, no local modules):

| File | What it manages |
|---|---|
| `main.tf` | Providers (default region + `aws.us_east_1` alias required for CloudFront) |
| `backend.tf` | S3 remote state |
| `variables.tf` / `outputs.tf` | Inputs / outputs |
| `dns.tf` | Route 53 records for schedule subdomain, auth subdomain, ACM validation |
| `acm.tf` | Wildcard ACM cert (must be `us-east-1`) |
| `s3.tf` | Private S3 bucket + Origin Access Control |
| `cognito.tf` | User Pool, Google IdP, hosted UI domain — reads Google OAuth credentials from SSM |
| `cloudfront.tf` | CloudFront distribution with Lambda@Edge viewer-request auth |
| `lambda_auth.tf` | Lambda@Edge IAM role + function; uses `templatefile()` to bake Cognito config into source |
| `lambda/auth.js.tpl` | Lambda@Edge source template — handles PKCE flow, JWT verification, callback, logout |

**Key constraint:** ACM cert and Lambda@Edge function must both be in `us-east-1` regardless of your primary region. Both use `provider = aws.us_east_1`.

**Adding a user:** AWS Console → Cognito → User Pool → Create user (enter email).

**Terraform first-apply order** (cert DNS validation must exist before the cert validates):
```bash
terraform apply -target=aws_acm_certificate.main   # creates cert + DNS validation records
# wait ~2 min, then:
terraform apply                                      # everything else
```

## App architecture

Two files, no build step:

- **`schedule.yaml`** — the single source of truth for all schedule data. Edit this to change the schedule.
- **`schedule.html`** — a self-contained viewer that fetches and renders `schedule.yaml` at runtime using [js-yaml](https://github.com/nodeca/js-yaml) from CDN. No framework, no bundler.

### Data model (`schedule.yaml`)

Top-level key `days` is an array of day objects, each with a `blocks` array:

```yaml
days:
  - name: Sunday
    blocks:
      - time: "8:00–9:00"
        label: Peloton spin
        category: peloton   # controls color; see categories below
        who: alex            # alex | tricia | both | all | kids | one (note-only, not rendered differently)
        flexible: false      # true = ~marker + muted opacity
        note: "..."          # shown as tooltip on hover
```

Valid categories: `gym`, `yoga`, `peloton`, `tennis`, `walk`, `kids`, `dinner`, `vball`, `ninja`, `cheer`, `work`, `rest`

### Rendering (`schedule.html`)

- `loadYaml()` fetches `schedule.yaml` with a cache-busting query string, then calls `render()`
- `render()` calls three sub-functions: `renderLegend()`, `renderGrid()`, `renderStats()`
- `renderGrid()` filters blocks by `currentView` (`all` / `exercise` / `kids` / `food`) — view tabs are wired via `VIEW_CATS`
- `renderStats()` counts Alex/Tricia workouts, walks, cook nights, eat-out nights by scanning category + who fields
- Category colors are pure CSS classes (`cat-gym`, `cat-yoga`, …) — add a new category by adding both a CSS rule and a `CAT_LABELS` entry in the JS config block at the top of the script

To add a new category: update `CAT_LABELS`, add a `--catname` CSS variable in `:root`, add a `.cat-catname` rule, and add it to `VIEW_CATS` filter groups as appropriate.
