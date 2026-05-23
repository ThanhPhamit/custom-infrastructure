# AWS S3 Frontend Hosting Terraform Module

Terraform module that hosts a static frontend (React, Vue, Angular, Next.js
static export, plain HTML) on S3 + CloudFront with HTTPS, optional basic auth,
and optional canonical-domain enforcement.

## Features

- **S3 Bucket** — private, versioned, 30-day non-current-version lifecycle.
- **CloudFront Distribution** — global CDN, multiple aliases on one distribution.
- **Origin Access Control (OAC)** — recommended over OAI; signed S3 origin requests.
- **Router CloudFront Function** — URI rewriter for SPA / Next.js static export.
- **Canonical Domain Redirect** — 301-redirect any non-canonical Host (e.g. `www.` → apex).
- **Basic Authentication** — optional CloudFront Function for staging gating.
- **SPA Fallback** — `403/404` → `index.html` for client-side routers.
- **Route53 DNS** — alias records for every domain in `domains`.
- **Secrets Manager** — basic-auth credentials stored outside the function.

## Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│                        Route53 DNS                                   │
│   thanhpham.site      ──┐                                            │
│   www.thanhpham.site  ──┴──→ CloudFront Distribution                 │
└─────────────────────────┬────────────────────────────────────────────┘
                          │
┌─────────────────────────▼────────────────────────────────────────────┐
│        CloudFront Distribution (single distribution)                 │
│   aliases:  [thanhpham.site, www.thanhpham.site]                     │
│   viewer-request function:                                           │
│     1. canonical redirect (Host != canonical → 301)                  │
│     2. URI rewrite (/about → /about/index.html)                      │
└─────────────────────────┬────────────────────────────────────────────┘
                          │  OAC (sigv4-signed)
┌─────────────────────────▼────────────────────────────────────────────┐
│          S3 Bucket — versioned, private, OAC-only access             │
│   /index.html                                                        │
│   /about/index.html                                                  │
│   /assets/*                                                          │
└──────────────────────────────────────────────────────────────────────┘
```

## Routing modes

The module picks one URI rewrite strategy per distribution. Set via `routing_mode`:

| `routing_mode` | Use it when… | Rewrite |
| --- | --- | --- |
| `"spa"`    | Vite / CRA / Vue / React with a single `/index.html` + client-side router. | Anything without an extension or ending in `/` → `/index.html`. |
| `"nextjs"` | `next build` with `output: "export"` (one HTML per route at `/route/index.html`). | `/about` → `/about/index.html`, `/about/` → `/about/index.html`. |
| `"none"`   | Plain static sites where every requested object exists in S3 as-is. | No rewrite. |

Leave `routing_mode = null` and the module falls back to the deprecated
`enable_spa_router` boolean (kept for backward compatibility).

## Canonical-domain redirect (`canonical_domain`)

Force every incoming request to resolve to one canonical host. Most useful for
**`www` ↔ apex** disambiguation — pick one as canonical, 301-redirect the other:

```hcl
module "frontend" {
  source = "../../modules/s3_frontend"
  # …
  domains          = ["thanhpham.site", "www.thanhpham.site"]
  canonical_domain = "thanhpham.site"   # www → thanhpham.site
}
```

Behaviour on every viewer-request:

1. **`Host != canonical_domain`** → return `301 Location: https://<canonical><uri>?<query>` with `Cache-Control: max-age=3600`. The browser follows the redirect; the second request hits CloudFront with the canonical Host and skips this branch.
2. **`Host == canonical_domain`** → apply the URI rewrite for the configured `routing_mode`.

Currently only implemented for `routing_mode = "nextjs"` because all routing
modes share the same CloudFront-function slot. Combining with `spa` / `none`
just needs an analogous JS template — see `nextjs_router_with_canonical_redirect.js`.

## Usage

### Example 1 — Next.js export with `www` → apex 301

```hcl
module "frontend" {
  source = "../../modules/s3_frontend"

  app_name            = "personal-homepage"
  domains             = ["thanhpham.site", "www.thanhpham.site"]
  acm_certificate_arn = module.acm.virginia_certificate_arn
  route_53_zone_id    = data.aws_route53_zone.root.zone_id

  routing_mode               = "nextjs"
  canonical_domain           = "thanhpham.site"
  spa_mode                   = false
  create_cloudfront_function = false  # no basic auth on public site

  price_class = "PriceClass_200"
  tags        = local.tags
}
```

### Example 2 — Multi-subdomain SPA (Vue / React) with basic auth

```hcl
module "frontend" {
  source = "../../modules/s3_frontend"

  app_name = "${var.environment}-${var.app_name}"

  domains = [
    "patient.example.com",
    "clinic.example.com",
    "admin.example.com",
  ]

  acm_certificate_arn = module.acm.virginia_certificate_arn
  route_53_zone_id    = data.aws_route53_zone.main.zone_id

  routing_mode = "spa"
  spa_mode     = true

  create_cloudfront_function = true               # basic auth in front of staging
  basic_auth_password        = var.staging_password

  price_class = "PriceClass_200"
  tags        = local.tags
}
```

### Example 3 — Internal tool, no custom domain

For internal-only frontends that are fine living at the default
`*.cloudfront.net` URL. Skip ACM + Route53 by leaving the three custom-domain
inputs at their null/empty defaults.

```hcl
module "frontend" {
  source = "../../modules/s3_frontend"

  app_name                   = "${var.environment}-portal"
  routing_mode               = "nextjs"
  create_cloudfront_function = false

  tags = local.tags
}
```

Read the `*.cloudfront.net` URL from the `cloudfront_domain_name` output and
hand it back to users.

### Example 4 — Plain static site (no rewrite, no SPA fallback)

```hcl
module "docs_site" {
  source = "../../modules/s3_frontend"

  app_name            = "${var.environment}-docs"
  domains             = ["docs.example.com"]
  acm_certificate_arn = module.acm.virginia_certificate_arn
  route_53_zone_id    = data.aws_route53_zone.main.zone_id

  routing_mode               = "none"
  spa_mode                   = false
  create_cloudfront_function = false

  price_class = "PriceClass_100"
  tags        = local.tags
}
```

## Deploying frontend files

After the first `terraform apply`, ship content with `aws s3 sync` and a
CloudFront invalidation. Pull bucket name + distribution ID from outputs (or
state) so it works the same in local + CI:

```bash
BUCKET=$(terraform output -raw bucket_name)
DIST_ID=$(terraform output -raw cloudfront_distribution_id)

npm run build

# Long-lived caching for hashed assets…
aws s3 sync ./out s3://$BUCKET/ --delete \
  --exclude "*.html" --exclude "*.json" \
  --cache-control "public, max-age=31536000, immutable"

# …short cache for HTML so route updates ship immediately after invalidation.
aws s3 sync ./out s3://$BUCKET/ \
  --exclude "*" --include "*.html" --include "*.json" \
  --cache-control "public, max-age=0, must-revalidate"

aws cloudfront create-invalidation --distribution-id "$DIST_ID" --paths "/*"
```

### GitHub Actions example

```yaml
- name: Deploy to S3 + invalidate CloudFront
  run: |
    aws s3 sync ./out s3://${{ secrets.S3_BUCKET }} --delete \
      --cache-control "public, max-age=31536000, immutable" \
      --exclude "*.html" --exclude "*.json"

    aws s3 sync ./out s3://${{ secrets.S3_BUCKET }} \
      --exclude "*" --include "*.html" --include "*.json" \
      --cache-control "public, max-age=0, must-revalidate"

    aws cloudfront create-invalidation \
      --distribution-id ${{ secrets.CF_DISTRIBUTION_ID }} \
      --paths "/*"
```

## Price class

| Price class      | Edge locations              | Cost    |
| ---------------- | --------------------------- | ------- |
| `PriceClass_All` | All edge locations          | Highest |
| `PriceClass_200` | US, Europe, Asia, ME, India | Medium  |
| `PriceClass_100` | US, Europe only             | Lowest  |

Pick `PriceClass_200` for Southeast Asia viewers — that's the cheapest tier
that still includes Singapore / Tokyo / Mumbai edges.

## SPA vs static fallback

| `spa_mode` | What changes | Use for |
| --- | --- | --- |
| `true`  | `403` and `404` from S3 are rewritten to `200 /index.html`. | Vue / React / Angular SPAs. |
| `false` | `403` / `404` propagate to the viewer. | Next.js export, Hugo, docs, anything pre-rendered. |

Combine `routing_mode = "nextjs"` with `spa_mode = false` for Next.js exports —
the URI rewrite already targets the correct per-route HTML, so the SPA
fallback would mask real 404s.

## Inputs

| Name | Description | Type | Default |
| --- | --- | --- | --- |
| `app_name` | Application name — prefixes all resource names. | `string` | n/a (**required**) |
| `domains` | Custom domain aliases. Empty list → serve from `*.cloudfront.net`. | `list(string)` | `[]` |
| `acm_certificate_arn` | ACM cert ARN (must be in `us-east-1`). Required when `domains` is non-empty. | `string` | `null` |
| `route_53_zone_id` | Route53 hosted zone ID. Required when `domains` is non-empty. | `string` | `null` |
| `routing_mode` | URI rewrite mode: `"spa"`, `"nextjs"`, `"none"`. | `string` | `null` (uses legacy bool) |
| `enable_spa_router` | **Deprecated** — prefer `routing_mode`. | `bool` | `true` |
| `canonical_domain` | When set, 301-redirect any non-matching Host to `https://<canonical><uri>`. Currently only honoured for `routing_mode = "nextjs"`. | `string` | `null` |
| `create_cloudfront_function` | Enable basic auth in CloudFront function. | `bool` | `true` |
| `basic_auth_password` | Password for basic auth (username = `app_name`). | `string` (sensitive) | `""` |
| `spa_mode` | When `true`, `403/404` from S3 → `200 /index.html`. | `bool` | `true` |
| `default_root_object` | Default root object (index file). | `string` | `"index.html"` |
| `price_class` | CloudFront price class. | `string` | `"PriceClass_All"` |
| `tags` | Tags applied to every resource the module creates. | `map(string)` | `{}` |

## Outputs

| Name | Description |
| --- | --- |
| `bucket_name` | S3 bucket name (use with `aws s3 sync`). |
| `bucket_id` | S3 bucket ID. |
| `bucket_arn` | S3 bucket ARN. |
| `bucket_regional_domain_name` | S3 regional domain (origin domain). |
| `cloudfront_distribution_id` | CloudFront distribution ID (use with `create-invalidation`). |
| `cloudfront_distribution_arn` | CloudFront distribution ARN. |
| `cloudfront_domain_name` | `dXXXXXXXX.cloudfront.net` — useful while DNS propagates. |
| `website_urls` | List of `https://<domain>` URLs. |
| `domains` | Echoes back the `domains` input. |
| `basic_auth_secret_arn` | Secrets Manager ARN (null when basic auth disabled). |

## Basic auth credentials

When `create_cloudfront_function = true`:

- **Username**: same as `app_name`.
- **Password**: value of `basic_auth_password`.
- Both are stored in AWS Secrets Manager and only inlined into the CloudFront
  function code at deploy time.

Retrieve:

```bash
aws secretsmanager get-secret-value \
  --secret-id "<app_name>-CDN-basic-auth" \
  --query SecretString --output text | jq
```

## CloudFront function files

The module ships four template scripts. Only **one** is bound to the
distribution at a time, picked from `routing_mode` + `canonical_domain` +
`create_cloudfront_function`:

| File | Picked when |
| --- | --- |
| `spa_router.js` | `routing_mode == "spa"`, basic auth off. |
| `spa_router_with_auth.js` | `routing_mode == "spa"`, basic auth on. |
| `nextjs_router.js` | `routing_mode == "nextjs"`, `canonical_domain == null`. |
| `nextjs_router_with_canonical_redirect.js` | `routing_mode == "nextjs"`, `canonical_domain` set. |
| `basic_auth.js` | `routing_mode == "none"`, basic auth on (standalone gate). |

## Requirements

| Name      | Version   |
| --------- | --------- |
| terraform | >= 1.4.0  |
| aws       | >= 5.86.1 |
| random    | >= 3.6.3  |

## Notes

1. The ACM cert must live in `us-east-1` — CloudFront doesn't accept certs from any other region.
2. DNS propagation after first apply usually takes 5–10 minutes.
3. Always invalidate `/*` (or specific paths) after a content sync; CloudFront edges otherwise keep the previous version until the TTL expires.

## License

Apache 2 Licensed. See LICENSE for full details.
