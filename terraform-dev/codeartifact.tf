# Private npm registry for the @mitto-sh/* shared libraries.
# The `libs` repo proxies public npmjs through `npm-store`, so a single registry
# serves both the private libs and every public dependency.

resource "aws_codeartifact_domain" "mitto" {
  domain = var.platform_name
}

resource "aws_codeartifact_repository" "npm_store" {
  domain      = aws_codeartifact_domain.mitto.domain
  repository  = "npm-store"
  description = "Proxy of public npmjs"

  external_connections {
    external_connection_name = "public:npmjs"
  }
}

resource "aws_codeartifact_repository" "libs" {
  domain      = aws_codeartifact_domain.mitto.domain
  repository  = "libs"
  description = "@mitto-sh/* shared libraries + upstream public packages"

  upstream {
    repository_name = aws_codeartifact_repository.npm_store.repository
  }
}

# ── IAM policies (attached to the CI roles that build/publish) ─────────────────
data "aws_iam_policy_document" "codeartifact_read" {
  statement {
    sid       = "GetAuthToken"
    actions   = ["codeartifact:GetAuthorizationToken", "codeartifact:GetRepositoryEndpoint"]
    resources = [aws_codeartifact_domain.mitto.arn, aws_codeartifact_repository.libs.arn]
  }
  statement {
    sid       = "ReadPackages"
    actions   = ["codeartifact:ReadFromRepository"]
    resources = [aws_codeartifact_repository.libs.arn]
  }
  statement {
    sid       = "ServiceBearerToken"
    actions   = ["sts:GetServiceBearerToken"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "sts:AWSServiceName"
      values   = ["codeartifact.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "codeartifact_publish" {
  source_policy_documents = [data.aws_iam_policy_document.codeartifact_read.json]
  statement {
    sid       = "PublishPackages"
    actions   = ["codeartifact:PublishPackageVersion", "codeartifact:PutPackageMetadata"]
    resources = ["${aws_codeartifact_repository.libs.arn}/*"]
  }
}

resource "aws_iam_policy" "codeartifact_read" {
  name   = "${local.name}-codeartifact-read"
  policy = data.aws_iam_policy_document.codeartifact_read.json
}

resource "aws_iam_policy" "codeartifact_publish" {
  name   = "${local.name}-codeartifact-publish"
  policy = data.aws_iam_policy_document.codeartifact_publish.json
}
