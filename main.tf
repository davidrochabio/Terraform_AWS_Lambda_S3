provider "aws" {
  region = "us-east-2"
}

resource "aws_s3_bucket" "input" {
  bucket = "input-banking-dirty"
}

resource "aws_s3_bucket" "output" {
  bucket = "output-banking-clean"
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "iam_for_lambda" {
  name               = "iam_for_lambda"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "lambdabasic_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role = aws_iam_role.iam_for_lambda.name
}

resource "aws_iam_role_policy_attachment" "s3_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
  role = aws_iam_role.iam_for_lambda.name
}

resource "aws_lambda_layer_version" "pandasrequests_layer" {
  filename   = "pandasrequests_layer.zip"
  layer_name = "pandasrequests_layer"

  compatible_runtimes = ["python3.11"]
}

data "archive_file" "convert_currency_lambda" {
  type        = "zip"
  source_file = "convert_currency.py"
  output_path = "convert_currency_lambda_payload.zip"
}

resource "aws_lambda_function" "convert_currency" {
  filename      = "convert_currency_lambda_payload.zip"
  function_name = "convert_currency"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "convert_currency.lambda_handler"

  source_code_hash = data.archive_file.convert_currency_lambda.output_base64sha256

  runtime     = "python3.11"
  layers      = [aws_lambda_layer_version.pandasrequests_layer.arn]
  memory_size = 512
  timeout     = 300

}

resource "aws_lambda_permission" "permission_convert_currency" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.convert_currency.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.input.arn

  depends_on = [ aws_lambda_function.convert_currency ]

}

resource "aws_s3_bucket_notification" "notification_convert_currency" {
  bucket = aws_s3_bucket.input.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.convert_currency.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [ aws_s3_bucket.input, aws_lambda_function.convert_currency ]
}
