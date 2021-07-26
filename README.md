# Terraform examples

## Introduction
Terraform consists of:
* [Resources](https://www.terraform.io/docs/language/resources/index.html) to be managed;
* [Modules](https://www.terraform.io/docs/language/modules/index.html) - to group multiple resources used together and favour code reuse;
* [Providers](https://www.terraform.io/docs/language/providers/index.html) - managers of specific resource types; providers are indexed on the [Terraform Registry](https://registry.terraform.io/browse/providers) and can come from either Hashicorp, verified organizations or community members; No longer maintained ones are listed as "Archived". For instance, the [AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest) is maintained directly by Hashicorp. The documentation is available [here](https://registry.terraform.io/providers/hashicorp/aws/latest/docs) and the Github repo [here](https://github.com/hashicorp/terraform-provider-aws).
* [Input Variables](https://www.terraform.io/docs/language/values/variables.html) - used to abstract and parametrize providers;
* [Outputs](https://www.terraform.io/docs/language/values/outputs.html) - specifying values to export from a module; Terraform prints those specified output values to stdout when applying the configuration; You can alternatively explicitly query those values using the `terraform output` command, which is optionally provided the output name (e.g. `terraform output region`) to act as a resource query;

## Pre-requisites
 1. Sign up for an AWS account, create a new non-root user and assign some policies  
 2. Create a `credentials` file at `~/.aws` with a profile for the account created at 1.  
 3. Install Terraform using a package manager or by downloading the binary from [here](https://www.terraform.io/downloads.html) or [here](https://github.com/hashicorp/terraform/releases)
 4. `terraform init` to initialize the Terraform project
 5. define a `~/.aws/credentials` file or export `AWS_SECRET_ACCESS_KEY` and `AWS_ACCESS_KEY_ID`
 6. `terraform plan` to see changes to the infrastructure with respect to the applied tf file
 7. `terraform apply` to apply the changes to the infrastructure (or `terraform apply -auto-approve` to skip confirmation)
 8. Once done `terraform destroy` to terminate all resources managed by the current configuration;

Do not forget, in case you already didn't, to ignore the state files:
```bash
.terraform
*.tfstate
*.tfstate.backup
*.lock.hcl
```

## Test-1
Example file, no changes to the infrastructure are to be applied.
The Terraform state is saved to a local *.tfstate file in JSON format. This, even when committed, may lead to inconsistencies across team members. Also, secrets may be contained in the state file and access to this information is thus unmanaged.
Another solution is to set up a CICD pipeline as the sole applier of Terraform configuration and use a persistent volume to store the state.

## Test-2
Example of using S3 as a shared state storage, where state files can be shared, versioned and encrypted.
You can firstly create the S3 bucket by commenting the *backend* configuration. Once done, you can uncomment and apply the *backend* so that the state is written to the selected S3 bucket. In summary:

* `terraform apply`:
  ```bash
  aws_s3_bucket.terraform_state: Creating...
  aws_s3_bucket.terraform_state: Creation complete after 5s [id=pilillo-tf-state]
  
  Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
  
  Outputs:
  
  region = "eu-west-1"
  state_arn = "arn:aws:s3:::pilillo-tf-state"
  ```

* `terraform init` to initialize the backend after uncommenting the s3 reference:
  ```bash
  Successfully configured the backend "s3"! Terraform will automatically
  use this backend unless the backend configuration changes.
  
  Initializing provider plugins...
  - Reusing previous version of hashicorp/aws from the dependency lock file
  - Using previously-installed hashicorp/aws v3.51.0
  
  Terraform has been successfully initialized!
  You may now begin working with Terraform. Try running "terraform plan" to see
  any changes that are required for your infrastructure. All Terraform commands
  should now work.
  
  If you ever set or change modules or backend configuration for Terraform,
  rerun this command to reinitialize your working directory. If you forget, other
  commands will detect it and remind you to do so if necessary.
  ```

## Test-3
Example creating an S3 bucket and using it from Athena. This also shows how to define dependencies between resources.

```bash
❯ terraform plan
aws_s3_bucket.terraform_state: Refreshing state... [id=pilillo-tf-state]

Terraform used the selected providers to generate the following execution plan. Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  # aws_athena_database.datalake will be created
  + resource "aws_athena_database" "datalake" {
      + bucket        = "datalake"
      + force_destroy = false
      + id            = (known after apply)
      + name          = "myfirstdb"
    }

  # aws_s3_bucket.datalake will be created
  + resource "aws_s3_bucket" "datalake" {
      + acceleration_status         = (known after apply)
      + acl                         = "private"
      + arn                         = (known after apply)
      + bucket                      = "datalake"
      + bucket_domain_name          = (known after apply)
      + bucket_regional_domain_name = (known after apply)
      + force_destroy               = false
      + hosted_zone_id              = (known after apply)
      + id                          = (known after apply)
      + region                      = (known after apply)
      + request_payer               = (known after apply)
      + tags_all                    = (known after apply)
      + website_domain              = (known after apply)
      + website_endpoint            = (known after apply)

      + versioning {
          + enabled    = (known after apply)
          + mfa_delete = (known after apply)
        }
    }
```

Once applied:  
```
aws_s3_bucket.datalake: Creating...
aws_s3_bucket.datalake: Creation complete after 5s [id=pilillo-datalake]
aws_athena_database.datalake: Creating...
aws_athena_database.datalake: Creation complete after 9s [id=myfirstdb]

Apply complete! Resources: 2 added, 0 changed, 0 destroyed.

Outputs:

datalake_arn = "arn:aws:s3:::pilillo-datalake"
region = "eu-west-1"
state_arn = "arn:aws:s3:::pilillo-tf-state"
```

## Test-4
Example showing how to setup a Kinesis stream and ingesting messages to the previously created bucket.
Please have a look [here](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kinesis_stream) for Kinesis streams and [here](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kinesis_firehose_delivery_stream) for Firehose. The output (truncated):

```bash
...
aws_s3_bucket.datalake: Creating...
aws_s3_bucket.datalake: Creation complete after 5s [id=pilillo-datalake]
aws_athena_database.datalake: Creating...
aws_kinesis_firehose_delivery_stream.test_stream: Creating...
aws_athena_database.datalake: Creation complete after 8s [id=myfirstdb]
aws_kinesis_firehose_delivery_stream.test_stream: Still creating... [10s elapsed]
aws_kinesis_firehose_delivery_stream.test_stream: Still creating... [20s elapsed]
aws_kinesis_firehose_delivery_stream.test_stream: Still creating... [30s elapsed]
aws_kinesis_firehose_delivery_stream.test_stream: Creation complete after 32s [id=arn:aws:firehose:eu-west-1:196393882643:deliverystream/terraform-kinesis-firehose-test-stream]

Apply complete! Resources: 3 added, 0 changed, 0 destroyed.

Outputs:

datalake_arn = "arn:aws:s3:::pilillo-datalake"
region = "eu-west-1"
state_arn = "arn:aws:s3:::pilillo-tf-state"
```

## Cleanup

Destroy all resources with `terraform destroy`.
Mind that the destroy may fail since S3 was defined with prevent_destroy.
Since there is no destroy all but one, we can do the [following](https://stackoverflow.com/questions/55265203/terraform-delete-all-resources-except-one):

```bash
# list all resources
terraform state list

# remove that resource you don't want to destroy
# you can add more to be excluded if required
terraform state rm <resource_to_be_deleted> 

# destroy the whole stack except above excluded resource(s)
terraform destroy 
```

which will destroy everything but the s3 state:

```bash
❯ terraform state list
aws_athena_database.datalake
aws_iam_role.firehose_role
aws_kinesis_firehose_delivery_stream.test_stream
aws_kinesis_stream.input_stream
aws_s3_bucket.datalake
aws_s3_bucket.terraform_state
❯ terraform state rm aws_s3_bucket.terraform_state
Removed aws_s3_bucket.terraform_state
Successfully removed 1 resource instance(s).
❯ terraform destroy
aws_kinesis_stream.input_stream: Refreshing state... [id=arn:aws:kinesis:eu-west-1:196393882643:stream/terraform-kinesis-test]
aws_s3_bucket.datalake: Refreshing state... [id=pilillo-datalake]
aws_iam_role.firehose_role: Refreshing state... [id=firehose_test_role]
aws_athena_database.datalake: Refreshing state... [id=myfirstdb]
aws_kinesis_firehose_delivery_stream.test_stream: Refreshing state... [id=arn:aws:firehose:eu-west-1:196393882643:deliverystream/terraform-kinesis-firehose-test-stream]

...

aws_athena_database.datalake: Destroying... [id=myfirstdb]
aws_kinesis_firehose_delivery_stream.test_stream: Destroying... [id=arn:aws:firehose:eu-west-1:196393882643:deliverystream/terraform-kinesis-firehose-test-stream]
aws_athena_database.datalake: Destruction complete after 4s
aws_kinesis_firehose_delivery_stream.test_stream: Still destroying... [id=arn:aws:firehose:eu-west-1:196393882643...terraform-kinesis-firehose-test-stream, 10s elapsed]
aws_kinesis_firehose_delivery_stream.test_stream: Destruction complete after 14s
aws_kinesis_stream.input_stream: Destroying... [id=arn:aws:kinesis:eu-west-1:196393882643:stream/terraform-kinesis-test]
aws_s3_bucket.datalake: Destroying... [id=pilillo-datalake]
aws_iam_role.firehose_role: Destroying... [id=firehose_test_role]
aws_iam_role.firehose_role: Destruction complete after 1s
aws_s3_bucket.datalake: Destruction complete after 5s
aws_kinesis_stream.input_stream: Still destroying... [id=arn:aws:kinesis:eu-west-1:196393882643:stream/terraform-kinesis-test, 10s elapsed]
aws_kinesis_stream.input_stream: Destruction complete after 10s

Destroy complete! Resources: 5 destroyed.

```