// Auto-generated variable declarations from massdriver.yaml
variable "md_metadata" {
  type = object({
    default_tags = object({
      managed-by  = string
      md-manifest = string
      md-package  = string
      md-project  = string
      md-target   = string
    })
    deployment = object({
      id = string
    })
    name_prefix = string
    observability = object({
      alarm_webhook_url = string
    })
    package = object({
      created_at             = string
      deployment_enqueued_at = string
      previous_status        = string
      updated_at             = string
    })
    target = object({
      contact_email = string
    })
  })
}
// Auto-generated variable declarations from massdriver.yaml
variable "capacity" {
  type = object({
    stream_mode = optional(string)
    shard_count = optional(number)
  })
}
variable "region" {
  type    = string
  default = null
}

variable "retention_hours" {
  type = number
}
variable "shard_level_metrics" {
  type = list(string)
}
// Auto-generated variable declarations from massdriver.yaml
variable "aws_authentication" {
  type = object({
    data = object({
      arn         = string
      external_id = optional(string)
    })
    specs = object({
      aws = optional(object({
        region = optional(string)
      }))
    })
  })
  default = null
}
