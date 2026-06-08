# GitHub's OIDC provider — may already exist if used by other repos in this account.
# If terraform apply errors on this resource, import the existing one:
#   terraform import aws_iam_openid_connect_provider.github \
#     arn:aws:iam::<account_id>:oidc-provider/token.actions.githubusercontent.com
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1",
                     "1c58a3a8518e8759bf075b76b750d4f2df264fcd"]
}

resource "aws_iam_role" "github_actions" {
  name = "${var.project_name}-github-actions"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:stark-alex/family-schedule:*"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "github_actions" {
  name = "ci-cd"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "TerraformState"
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject",
                  "s3:ListBucket", "s3:GetBucketVersioning"]
        Resource = ["arn:aws:s3:::stark-tf-state", "arn:aws:s3:::stark-tf-state/*"]
      },
      {
        Sid    = "ContentBucket"
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket",
                  "s3:GetBucketAcl"]
        Resource = ["arn:aws:s3:::family-schedule-*", "arn:aws:s3:::family-schedule-*/*"]
      },
      {
        Sid    = "Lambda"
        Effect = "Allow"
        Action = [
          "lambda:CreateFunction", "lambda:UpdateFunctionCode",
          "lambda:UpdateFunctionConfiguration", "lambda:GetFunction",
          "lambda:DeleteFunction", "lambda:AddPermission", "lambda:RemovePermission",
          "lambda:GetPolicy", "lambda:CreateFunctionUrlConfig",
          "lambda:UpdateFunctionUrlConfig", "lambda:GetFunctionUrlConfig",
          "lambda:DeleteFunctionUrlConfig", "lambda:ListVersionsByFunction",
          "lambda:GetFunctionCodeSigningConfig"
        ]
        Resource = "arn:aws:lambda:us-east-1:*:function:family-schedule-api*"
      },
      {
        Sid    = "IAM"
        Effect = "Allow"
        Action = [
          "iam:CreateRole", "iam:DeleteRole", "iam:GetRole", "iam:PassRole",
          "iam:AttachRolePolicy", "iam:DetachRolePolicy", "iam:ListAttachedRolePolicies",
          "iam:PutRolePolicy", "iam:DeleteRolePolicy", "iam:GetRolePolicy",
          "iam:ListRolePolicies", "iam:ListInstanceProfilesForRole"
        ]
        Resource = "arn:aws:iam::*:role/family-schedule-api*"
      },
      {
        Sid    = "CloudFront"
        Effect = "Allow"
        Action = [
          "cloudfront:CreateDistribution", "cloudfront:UpdateDistribution",
          "cloudfront:GetDistribution", "cloudfront:GetDistributionConfig",
          "cloudfront:DeleteDistribution", "cloudfront:CreateInvalidation",
          "cloudfront:CreateOriginAccessControl", "cloudfront:GetOriginAccessControl",
          "cloudfront:UpdateOriginAccessControl", "cloudfront:DeleteOriginAccessControl",
          "cloudfront:ListDistributions", "cloudfront:ListTagsForResource"
        ]
        Resource = "*"
      },
      {
        Sid    = "S3BucketManagement"
        Effect = "Allow"
        Action = [
          "s3:CreateBucket", "s3:DeleteBucket", "s3:GetBucketPolicy",
          "s3:PutBucketPolicy", "s3:GetBucketVersioning", "s3:PutBucketVersioning",
          "s3:GetBucketPublicAccessBlock", "s3:PutBucketPublicAccessBlock",
          "s3:GetAccelerateConfiguration", "s3:GetBucketCORS",
          "s3:GetBucketLogging", "s3:GetBucketObjectLockConfiguration",
          "s3:GetBucketRequestPayment", "s3:GetBucketTagging",
          "s3:GetBucketWebsite", "s3:GetEncryptionConfiguration",
          "s3:GetLifecycleConfiguration", "s3:GetReplicationConfiguration"
        ]
        Resource = ["arn:aws:s3:::family-schedule-*"]
      },
      {
        Sid    = "Cognito"
        Effect = "Allow"
        Action = [
          "cognito-idp:CreateUserPool", "cognito-idp:UpdateUserPool",
          "cognito-idp:DeleteUserPool", "cognito-idp:DescribeUserPool",
          "cognito-idp:CreateUserPoolClient", "cognito-idp:UpdateUserPoolClient",
          "cognito-idp:DeleteUserPoolClient", "cognito-idp:DescribeUserPoolClient",
          "cognito-idp:CreateUserPoolDomain", "cognito-idp:DeleteUserPoolDomain",
          "cognito-idp:DescribeUserPoolDomain", "cognito-idp:UpdateUserPoolDomain",
          "cognito-idp:CreateIdentityProvider", "cognito-idp:UpdateIdentityProvider",
          "cognito-idp:DeleteIdentityProvider", "cognito-idp:DescribeIdentityProvider",
          "cognito-idp:GetUserPoolMfaConfig"
        ]
        Resource = "*"
      },
      {
        Sid    = "ACM"
        Effect = "Allow"
        Action = [
          "acm:RequestCertificate", "acm:DescribeCertificate",
          "acm:DeleteCertificate", "acm:ListCertificates",
          "acm:AddTagsToCertificate", "acm:ListTagsForCertificate"
        ]
        Resource = "*"
      },
      {
        Sid    = "Route53"
        Effect = "Allow"
        Action = [
          "route53:GetHostedZone", "route53:ListHostedZones",
          "route53:ChangeResourceRecordSets", "route53:ListResourceRecordSets",
          "route53:GetChange", "route53:ListTagsForResource"
        ]
        Resource = [
          "arn:aws:route53:::hostedzone/*",
          "arn:aws:route53:::change/*",
          "*"
        ]
      },
      {
        Sid    = "SSM"
        Effect = "Allow"
        Action = ["ssm:GetParameter"]
        Resource = "arn:aws:ssm:us-east-1:*:parameter/family-schedule/*"
      },
      {
        Sid    = "LambdaEdge"
        Effect = "Allow"
        Action = [
          "lambda:CreateFunction", "lambda:UpdateFunctionCode",
          "lambda:UpdateFunctionConfiguration", "lambda:GetFunction",
          "lambda:DeleteFunction", "lambda:PublishVersion",
          "lambda:GetFunctionCodeSigningConfig", "lambda:ListVersionsByFunction",
          "lambda:EnableReplication"
        ]
        Resource = "arn:aws:lambda:us-east-1:*:function:family-schedule-auth*"
      },
      {
        Sid    = "IAMShared"
        Effect = "Allow"
        Action = [
          "iam:CreateRole", "iam:DeleteRole", "iam:GetRole", "iam:PassRole",
          "iam:AttachRolePolicy", "iam:DetachRolePolicy", "iam:ListAttachedRolePolicies",
          "iam:PutRolePolicy", "iam:DeleteRolePolicy", "iam:GetRolePolicy",
          "iam:ListRolePolicies", "iam:CreateOpenIDConnectProvider",
          "iam:GetOpenIDConnectProvider", "iam:DeleteOpenIDConnectProvider",
          "iam:UpdateOpenIDConnectProviderThumbprint"
        ]
        Resource = [
          "arn:aws:iam::*:role/family-schedule-*",
          "arn:aws:iam::*:oidc-provider/token.actions.githubusercontent.com"
        ]
      },
      {
        Sid      = "CallerIdentity"
        Effect   = "Allow"
        Action   = "sts:GetCallerIdentity"
        Resource = "*"
      }
    ]
  })
}
