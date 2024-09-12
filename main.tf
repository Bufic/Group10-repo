# S3 Bucket
resource "aws_s3_bucket" "s3_bucket" {
  bucket = var.bucket_name
  force_destroy = true

  tags = {
    Environment = var.env
  }
}

# S3 Bucket Website Configuration
resource "aws_s3_bucket_website_configuration" "website_config" {
  bucket = aws_s3_bucket.s3_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

# Uploading Files to S3 Bucket
resource "null_resource" "upload_app_to_s3" {
# This ensures that the S3 bucket is created before the upload command runs
  depends_on = [aws_s3_bucket.s3_bucket]

  provisioner "local-exec" {
    command = "aws s3 sync ./App-files/bootcamp-1-project-1a s3://${aws_s3_bucket.s3_bucket.bucket}/"
  }

  
}

# S3 Bucket Policy
resource "aws_s3_bucket_policy" "bucket_policy" {
  depends_on = [
    aws_cloudfront_distribution.cdn
  ]
  bucket = aws_s3_bucket.s3_bucket.id
  policy = data.aws_iam_policy_document.origin.json
}

## Create policy to allow CloudFront to reach S3 bucket
data "aws_iam_policy_document" "origin" {
  depends_on = [
    aws_cloudfront_distribution.cdn,
    aws_s3_bucket.s3_bucket
  ]
  statement {
    sid    = "3"
    effect = "Allow"
    actions = [
      "s3:GetObject"
    ]
    principals {
      identifiers = ["cloudfront.amazonaws.com"]
      type        = "Service"
    }
    resources = [
      "arn:aws:s3:::${aws_s3_bucket.s3_bucket.bucket}/*"
    ]
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"

      values = [
        aws_cloudfront_distribution.cdn.arn
      ]
    }
  }
}

resource "aws_cloudfront_origin_access_control" "oai" {
  name                              = "s3_bucket_access"
  description                       = "Access Policy to s3 bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

#CloudFront Distribution
resource "aws_cloudfront_distribution" "cdn" {
  depends_on = [
    aws_s3_bucket.s3_bucket,
    aws_cloudfront_origin_access_control.oai
  ]

  origin {
    domain_name = aws_s3_bucket.s3_bucket.bucket_regional_domain_name
    origin_id   = aws_s3_bucket.s3_bucket.id
    origin_access_control_id = aws_cloudfront_origin_access_control.oai.id
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = var.default_root_object

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = aws_s3_bucket.s3_bucket.id

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Environment = var.env
  }
}

