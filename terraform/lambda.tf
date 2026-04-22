data "archive_file" "handler" {
  type        = "zip"
  source_dir  = "${path.module}/../server"
  output_path = "${path.module}/build/handler.zip"
  excludes    = ["README.md", "__pycache__", "requirements.txt"]
}

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = "ddns-lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "lambda_inline" {
  statement {
    sid       = "Route53ReadWrite"
    actions   = ["route53:ChangeResourceRecordSets", "route53:ListResourceRecordSets"]
    resources = [data.aws_route53_zone.zone.arn]
  }

  statement {
    sid       = "Route53GetChange"
    actions   = ["route53:GetChange"]
    resources = ["*"]
  }

  statement {
    sid       = "SnsPublish"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.ip_change.arn]
  }
}

resource "aws_iam_role_policy" "lambda_inline" {
  name   = "ddns-lambda-inline"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.lambda_inline.json
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/ddns-updater"
  retention_in_days = 14
}

resource "aws_lambda_function" "updater" {
  function_name    = "ddns-updater"
  role             = aws_iam_role.lambda.arn
  runtime          = "python3.12"
  handler          = "handler.handler"
  filename         = data.archive_file.handler.output_path
  source_code_hash = data.archive_file.handler.output_base64sha256
  timeout          = 10
  memory_size      = 128

  environment {
    variables = {
      HOSTED_ZONE_ID = data.aws_route53_zone.zone.zone_id
      RECORD_NAME    = local.record_fqdn
      SNS_TOPIC_ARN  = aws_sns_topic.ip_change.arn
      TTL            = tostring(var.ttl)
    }
  }

  depends_on = [
    aws_iam_role_policy.lambda_inline,
    aws_cloudwatch_log_group.lambda,
  ]
}
