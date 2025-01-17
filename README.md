# Tutorial: Building a Bundle From an Existing Terraform Module

## Intro

Cutting the red tape from operations starts with self-service. Providing developers with well crafted abstractions and built in guidance, enables them to own their infrastructure and operations to focus on value add work. This journey starts in Massdriver with creating a bundle. In this tutorial we will take an existing module and build a user interface accessible in the Massdriver platform.

If you run in to any questions watch the video below or join the [community Slack](https://massdrivercommunity.slack.com/join/shared_invite/zt-1sxag35w2-eYw7gatS1hwlH2y8MCmwXA#/shared-invite/email) to get help.

## Prerequisites

- Create your [Massdriver account](https://app.massdriver.cloud/register)
- Install and set up the [Massdriver CLI](https://docs.massdriver.cloud/getting-started/prerequisites#installing-the-mass-cli)
- Add an [AWS Credential](https://docs.massdriver.cloud/getting-started/credentials)
- Create a new project called demo
- Create a new environment called prod

If you do not add a credential you can still follow along, you will not be able to deploy the final kinesis stream.

## Video Tutorial

{{link to video}}

## Creating a Bundle

Create a bundle from the provided module by running the following command in your terminal:

```bash
mass bundle new -n aws-kinesis-stream -t terraform-module -c aws_authentication=massdriver/aws-iam-role -p ./kinesis-stream -d "Message queue for streaming architectures on AWS" -o aws-kinesis-stream
```

Change directories to the aws-kinesis-stream directory to begin the tutorial.

```bash
cd aws-kinesis-stream
```

## Setup the Terraform Provider File

Your module likely does not have a provider file because it inherits from the parent when utilized in a Terraform configuration. To set this up, uncomment the AWS related blocks. The final code will look like this:

```terraform
terraform {
  required_version = ">= 1.0"
  required_providers {
    massdriver = {
      source  = "massdriver-cloud/massdriver"
      version = "~> 1.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.region
  assume_role {
    role_arn    = var.authentication.data.arn
    external_id = var.authentication.data.external_id
  }
  default_tags {
    tags = var.md_metadata.default_tags
  }
}
```

## User Defined Region

We will want a user to define their region when deploying a stream. We will want to specify the regions that a stream can be deployed to so our developer doesn't have to guess. To add this to the UI, add the following code to the params block in the `massdriver.yaml` file:

```yaml
params:
  properties:
    region:
      title: Region
      type: string
      $md.immutable: true
      enum:
        - us-east-1
        - us-west-2
```

The `$md.immutable` field prevents a user from changing this value once it is deployed. Changing the region would create a delete and recreate of the resource which would result in data loss. Next, add region to the list of required properties for your module in the `massdriver.yaml` file.

```yaml
  required:
    - region
    - retention_hours
    - shard_level_metrics
    - shard_count
    - stream_mode
```

Publish this bundle to Massdriver to see the results by running:

```bash
mass bundle publish
```

Navigate to your project, and open the bundle catalog on the right of the screen. You will see your new Kinesis bundle. Drag it on to the screen and call it "clickstream". By clicking on the newly created box, we can navigate to the config menu and see our module's new UI.

## Using the Massdriver Naming Convention

In many Terraform modules, there is a name field that allows users to create a name for the resource. This is the surest way to no longer have a naming convention. By the nature of diagramming architectures with Massdriver, Massdriver applies a naming convention consisting of the project name, the environment, and the contextual name for the deployed resource. Assuming you have followed the prerequisites, your bundle will be deployed as demo-prod-clickstream. Massdriver also adds a suffix which is used to avoid global naming collisions.

- Remove the name variable from the `_variables.tf` file
- Remove the name attribute from the `massdriver.yaml` file
- Remove the name attribution from the required properties in the `massdriver.yaml` file
- Change all references of `var.name` to `var.md_metadata.name_prefix`

Your bundle is not setup to use the Massdriver naming convention.

## Creating Dependent Fields

One tricky problem in Terraform is field dependencies. There are times when given a setting, some fields will not be required. Massdriver makes this very obvious by creating field dependencies based on selections. This also allows for the validation of fields conditionally. Let's make the stream_mode and shard_count fields conditional. We will nest them in a new section called capacity so that they are displayed together and read as a single unit of configuration. Add the following code to the params block in the `massdriver.yaml` file:

```yaml
capacity:
      type: object
      title: Capacity
      description: Set scaling attributes for Kinesis. ON_DEMAND for autoscaling and PROVISIONED for manual scaling.
      dependencies:
        stream_mode:
          oneOf:
            - properties:
                stream_mode:
                  const: PROVISIONED
                shard_count:
                  title: Shard Count
                  type: number
              required:
                - stream_mode
                - shard_count
            - properties:
                stream_mode:
                  const: ON_DEMAND
              required:
                - stream_mode
      properties:
        stream_mode:
          title: Stream Mode
          type: string
          enum:
            - ON_DEMAND
            - PROVISIONED
```

Now users will be aware of the two valid values for stream mode via dropdown, while the shard_count attribute will be conditionally show and validated. Next add the capacity field as required to our `massdriver.yaml` file:

```yaml
  required:
    - region
    - retention_hours
    - shard_level_metrics
    - capacity
```

Publish the changes to Massdriver and experiment with the new field.

```bash
mass bundle publish
```

## Setting Field Constraints

The shard_count and retention_hours fields both have minimums and maximums that can be seen in the `_variables.tf` file.

```terraform
variable "shard_count" {
  type = number

  validation {
    condition     = (var.shard_count == null) || try((var.shard_count >= 1 && var.shard_count <= 4096), false)
    error_message = "shard_count must be greater than 0 and less than 4097"
  }
}

variable "retention_hours" {
  type = number

  validation {
    condition     = var.retention_hours <= 8760 && var.retention_hours >= 24
    error_message = "Retention must be greater than or equal to 24 and less than or equal to 8760"
  }
}
```

To set these in the form, we need to add two fields to each attribute in the `massdriver.yaml` file

```yaml
    retention_hours:
      title: Retention Hours
      type: number
      minimum: 24
      maximum: 8760
    shard_count:
        title: Shard Count
        type: number
        minimum: 1
        maximum: 4096
```

Publish to the platform and save some configurations to test the validations.

```bash
mass bundle publish
```

## Multiselect Form

The shard_level_metrics field is an array of strings. Developers would have to dig through documentation to know what values are valid for this field. There is also a need for all the strings in the array to be unique. We can create a good user experience by making this field a dropdown where a user can select whatever fields they want for shard level metrics.

```yaml
    shard_level_metrics:
      type: array
      title: Shard Level Metrics
      uniqueItems: true
      default: []
      minItems: 0
      items:
        type: string
        enum:
          - IncomingBytes
          - IncomingRecords
          - OutgoingBytes
          - OutgoingRecords
          - WriteProvisionedThroughputExceeded
          - ReadProvisionedThroughputExceeded
          - IteratorAgeMilliseconds
```

Now the end user can select from any of the 6 valid values.

Publish to the platform and select some values for shard_level_metrics.

```bash
mass bundle publish
```

## Defining Field Order

The form currently does not have a great flow. Using the bundle spec, we can order the fields in a way that will feel better to a user. To order the fields we must modify the UI block in the `massdriver.yaml` file.

```yaml
ui:
  ui:order:
    - "region"
    - "capacity"
    - "retention_hours"
    - "shard_level_metrics"
```

## Deploying the Stream

Set the following values in the form to deploy your kinesis stream:

```yaml
region: us-east-1
capacity:
    stream_mode: PROVISIONED
    shard_count: 1
retention_hours: 24
shard_level_metrics: ["IncomingBytes"]
```

Click deploy and wait until the rollout is complete.

## Defining an Artifact

Artifacts are the key to making modules composable. Defining inputs and outputs as types in modules enables interoperability and the creation of novel architectures. For the next step we will define an artifact. The definition for the artifact [can be found here](https://github.com/massdriver-cloud/artifact-definitions/blob/main/definitions/artifacts/aws-kinesis-stream.json).

In the `massdriver.yaml` file add the following lines under the artifacts block.

```yaml
artifacts:
  required:
    - stream
  properties:
    stream:
      $ref: massdriver/aws-kinesis-stream
```

Now add the following code in the `_artifacts.tf` file.

```terraform
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
```

Publish the bundle and deploy again to create the artifact.

```bash
mass bundle publish
```

## Testing the Stream

To test that our stream is working, copy the resource naming prefix from the details panel of the module. Run the following code one command at a time.

```bash
PACKAGE_NAME=your-package-naming-prefix
REGION=your-region
aws kinesis put-record --stream-name $PACKAGE_NAME --partition-key 123 --data testdata --region $REGION 
aws --region $REGION kinesis get-records --shard-iterator $(aws kinesis get-shard-iterator --shard-id shardId-000000000000 --shard-iterator-type TRIM_HORIZON --stream-name $PACKAGE_NAME --region $REGION --query 'ShardIterator')
```
