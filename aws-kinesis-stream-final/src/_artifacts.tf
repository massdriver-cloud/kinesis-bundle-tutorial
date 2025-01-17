resource "massdriver_artifact" "stream" {
  field                = "stream"
  provider_resource_id = aws_kinesis_stream.main.arn
  name                 = "Kinesis stream from ${var.md_metadata.name_prefix}"
  artifact = jsonencode(
    {
      data = {
        infrastructure = {
          arn = aws_kinesis_stream.main.arn
        }
        security = {
          iam = {
            read = {
              policy_arn = aws_iam_policy.read.arn
            }
            write = {
              policy_arn = aws_iam_policy.write.arn
            }
            manage = {
              policy_arn = aws_iam_policy.manage.arn
            }
          }
        }
      }
      specs = {
        aws = {
          region = var.region
        }
      }
    }
  )
}
