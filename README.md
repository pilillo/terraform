# Terraform examples

## Introduction
Terraform consists of:
* [Resources](https://www.terraform.io/docs/language/resources/index.html) to be managed; orthogonally to those, meta-arguments can be defined, such as [depends-on](https://www.terraform.io/docs/language/meta-arguments/depends_on.html), [count](https://www.terraform.io/docs/language/meta-arguments/count.html) to create multiple instances of the same resource type, [lifecycle](https://www.terraform.io/docs/language/meta-arguments/lifecycle.html) to define Terraform-related behavior such as upon update or deletion; 
* [Modules](https://www.terraform.io/docs/language/modules/index.html) - grouping a set of resources into a reusable named component that can be be published and maintaned as a whole; this enables code reuse and a more maintainable architecture; a natural design pattern is to separate code in a repository for modules and another one for live infrastructure;  
* [Providers](https://www.terraform.io/docs/language/providers/index.html) - managers of specific resource types; providers are indexed on the [Terraform Registry](https://registry.terraform.io/browse/providers) and can come from either Hashicorp, verified organizations or community members; No longer maintained ones are listed as "Archived". For instance, the [AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest) is maintained directly by Hashicorp. The documentation is available [here](https://registry.terraform.io/providers/hashicorp/aws/latest/docs) and the Github repo [here](https://github.com/hashicorp/terraform-provider-aws).
* [Input Variables](https://www.terraform.io/docs/language/values/variables.html) - used to abstract and parametrize providers;
* [Outputs](https://www.terraform.io/docs/language/values/outputs.html) - specifying values to export from a module; Terraform prints those specified output values to stdout when applying the configuration; You can alternatively explicitly query those values using the `terraform output` command, which is optionally provided the output name (e.g. `terraform output region`) to act as a resource query;
* [Data Sources](https://www.terraform.io/docs/language/data-sources/index.html) - definying a reference to information defined outside of Terraform;

As a declarative language, Terraform has no control flow constructs such as for-loop, although it provides with a basic if-else conditional construct, such as to define multiple variants of the modeled infrastructure, by deploying either these or those resources based on data or variable values.

## Pre-requisites
 1. Sign up for an AWS account, create a new non-root user and assign some policies  
 2. Create a `~/.aws/credentials` file with a new profile for the account created at 1 or export AWS_SECRET_ACCESS_KEY and AWS_ACCESS_KEY_ID 
 3. Install Terraform using a package manager or by downloading the binary from [here](https://www.terraform.io/downloads.html) or [here](https://github.com/hashicorp/terraform/releases)

Do not forget, in case you already didn't, to ignore the state files:
```bash
.terraform
*.tfstate
*.tfstate.backup
*.lock.hcl
```

## Terraform lifecycle
 1. `terraform init` to initialize the Terraform project
 2. `terraform plan` to see changes to the infrastructure with respect to the applied tf file
 3. `terraform apply` to apply the changes to the infrastructure (or `terraform apply -auto-approve` to skip confirmation)
 4. Once done `terraform destroy` to terminate all resources managed by the current configuration;


## Test-1
Example file, no changes to the infrastructure are to be applied.
The Terraform state is saved to a local *.tfstate file in JSON format. This, even when committed, may lead to inconsistencies across team members. Also, secrets may be contained in the state file and access to this information is thus unmanaged.
Another solution is to set up a CICD pipeline as the sole applier of Terraform configuration and use a persistent volume to store the state. Along with state sharing, [state locking](https://www.terraform.io/docs/language/state/locking.html) is a potential issue leading to inconsistencies. 

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
  
Why S3? Terraform is actually compatible with multiple backends, including its own Terraform Cloud. 
However, a file storage like GCS, S3 and Azure Storage will be just fine. Specifically, S3:
* it's managed and designed for 99.99% availability
* supports server-side encryption using AES-256 (super important since the tf state also contains secrets) and SSL during interaction
* supports versioning so rolling back to an older state is possible
* supports locking via DynamoDB

For instance, you can create an S3 bucket with enabled versioning and encryption as follows:
```hcl
provider "aws" {
    profile = var.aws["profile"]
    region = var.aws["region"]
}

resource "aws_s3_bucket" "terraform_state" {
  bucket = "pilillo-tf-state"
  
  versioning {
    enabled = true
  }

  lifecycle {
    prevent_destroy = true
  }
  
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}
```

You can similarly add a dynamo DB table to keep the locks:
```hcl
resource "aws_dynamodb_table" "terraform_lock" {
  name = "pilillo-tf-lock"
  hash_key = "LockID"
  
  attribute {
    name = "LockID"
    type = "S"
  }
}
```

We can then configure terraform to use those resources to keep its state:
```hcl
terraform {
    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = "~> 3.27"
        }
    }
    required_version = ">= 0.14.9"

    backend "s3" {
        bucket = "pilillo-tf-state"
        region = "eu-west-1"
        key="global/terraform.tfstate"
        dynamodb_table = "pilillo-tf-lock"
        encrypt = true
    }

}
```
You are now ready to go with S3 as state backend.

Mind that variables are not allowed within the backend block.
A solution is to use partial configuration, i.e. to move those backend parameters that are environment specific to an external file and provide them via a `-backend-config mybackendconf.hcl` command line argument when calling terraform init. Another possibility to manage a multi-environment state is to use terraform [workspaces](https://www.terraform.io/docs/language/state/workspaces.html). When omitted, terraform starts with a `default` workspace (run `terraform workspace show` to see the one you are currently in) and additional ones can be created using `terraform workspace new <workspace-name>` having a brand new state file. You can list workspaces using `terraform workspace list` and select one using `terraform workspace select <workspace-name>`. If you check your S3 bucket, an `env` folder is stored along with the one indicated in the `backend.s3.key`. This contains the terraform state of each created workspace. This is seamless for the user, who simply switches workspace. To achieve full environment isolation, an explicit env-specific directory shall be used to store terraform files, as well as a specific backend to store its state and lock.

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

## Test-5
Example to deploy a lambda function written in Python. For the sake of simplicity, we start from a clean `main.tf` file instead of bringing forward the one resulting from *Test-4*.  

The lambda simply logs the event payload:
```python
import json

def handler(event, context):
    print("Received event: " + json.dumps(event, indent=2))
```

Just zip it using the command in `zip_src.sh` and apply the configuration with `terraform apply`.
The lambda can be invoked using the aws cli (see `aws lambda invoke help`):

```bash
aws lambda invoke --region eu-west-1 \
--function-name myfirstlambda \
--invocation-type RequestResponse --log-type Tail \
--cli-binary-format raw-in-base64-out \
--payload '{"key1":"value1", "key2":"value2", "key3":"value3"}' \
response.json | \
jq .LogResult | sed 's/"//g' | base64 --decode
```

with the lambda printing out the provided payload:
```bash
START RequestId: 6001f62c-91d5-4baa-90d5-f22f12e5585e Version: $LATEST
Received event: {
  "key1": "value1",
  "key2": "value2",
  "key3": "value3"
}
END RequestId: 6001f62c-91d5-4baa-90d5-f22f12e5585e
REPORT RequestId: 6001f62c-91d5-4baa-90d5-f22f12e5585e  Duration: 0.26 ms       Billed Duration: 1 ms   Memory Size: 128 MB     Max Memory Used: 43 MB  Init Duration: 1.18 ms
```

## Test-6

### Configure the CLI for Localstack

You can configure fake aws credentials to be used for localstack, as explained [here](https://github.com/localstack/localstack/blob/master/README.md#setting-up-local-region-and-credentials-to-run-localstack), as follows:

```bash
$ aws configure --profile localstack
AWS Access Key ID [None]: fake
AWS Secret Access Key [None]: fake
Default region name [None]: us-east-1
Default output format [None]: 
```

which will append the following to your ~/.aws/credentials file:
```
[localstack]
aws_access_key_id = fake
aws_secret_access_key = fake
```

or alternatively just use the AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY variables:

export AWS_ACCESS_KEY_ID=fake
export AWS_SECRET_ACCESS_KEY=fake

### Invoke the lambda function

To interact with the lambda function, you can use as usual the [aws CLI](https://github.com/aws/aws-cli), or the thin wrapper [awslocal](https://github.com/localstack/awscli-local) made to work with Localstack.

```
aws lambda invoke --region eu-west-1 \
--function-name myfirstlambda \
--invocation-type RequestResponse --log-type Tail \
--cli-binary-format raw-in-base64-out \
--endpoint-url=http://localhost:4566 \
--payload '{"key1":"value1", "key2":"value2", "key3":"value3"}' \
response.json | \
jq .LogResult | sed 's/"//g' | base64 --decode
```

Looking at the localstack log:
```log
localstack_main | 2021-09-22T14:49:55:DEBUG:localstack.services.awslambda.lambda_executors: Creating docker-reuse Lambda container localstack_lambda_arn_aws_lambda_eu-west-1_000000000000_function_myfirstlambda from image lambci/lambda:20191117-python3.6
localstack_main | 2021-09-22T14:49:55:DEBUG:localstack.utils.docker: Creating container with image lambci/lambda:20191117-python3.6, command 'None', volumes None, env vars {'AWS_ACCESS_KEY_ID': 'test', 'AWS_SECRET_ACCESS_KEY': 'test', 'AWS_REGION': 'eu-west-1', 'LOCALSTACK_HOSTNAME': '172.17.0.2', 'AWS_ENDPOINT_URL': 'http://172.17.0.2:4566', 'EDGE_PORT': 4566, '_HANDLER': 'lambda.handler', 'AWS_LAMBDA_FUNCTION_TIMEOUT': '3', 'AWS_LAMBDA_FUNCTION_NAME': 'myfirstlambda', 'AWS_LAMBDA_FUNCTION_VERSION': '$LATEST', 'AWS_LAMBDA_FUNCTION_INVOKED_ARN': 'arn:aws:lambda:eu-west-1:000000000000:function:myfirstlambda', 'AWS_LAMBDA_COGNITO_IDENTITY': '{}', '_LAMBDA_SERVER_PORT': '5000', 'HOSTNAME': '9649705c54f4'}
localstack_main | 2021-09-22T14:49:55:DEBUG:localstack.utils.docker: Pulling image: lambci/lambda:20191117-python3.6
localstack_main | 2021-09-22T14:49:55:DEBUG:localstack.utils.docker: Repository: lambci/lambda Tag: 20191117-python3.6
...
localstack_main | 2021-09-22T14:50:53:DEBUG:localstack.utils.docker: Executing command in container localstack_lambda_arn_aws_lambda_eu-west-1_000000000000_function_myfirstlambda: ['/var/lang/bin/python3.6', '/var/runtime/awslambda/bootstrap.py', 'lambda.handler']
localstack_main | 2021-09-22T14:50:53:DEBUG:localstack.services.awslambda.lambda_executors: Lambda arn:aws:lambda:eu-west-1:000000000000:function:myfirstlambda result / log output:
localstack_main | null
localstack_main | > START RequestId: 1961d636-734b-40c3-9a83-5170a1a45f2d Version: $LATEST
localstack_main | > Received event: {
localstack_main | >   "key1": "value1",
localstack_main | >   "key2": "value2",
localstack_main | >   "key3": "value3"
localstack_main | > }
localstack_main | > END RequestId: 1961d636-734b-40c3-9a83-5170a1a45f2d
localstack_main | > REPORT RequestId: 1961d636-734b-40c3-9a83-5170a1a45f2d Duration: 0 ms Billed Duration: 100 ms Memory Size: 1536 MB Max Memory Used: 19 MB
localstack_main | 2021-09-22T14:51:47:DEBUG:localstack.services.awslambda.lambda_executors: Checking if there are idle containers ...
```

and the AWS cli will return after printing the following:

```
START RequestId: 1961d636-734b-40c3-9a83-5170a1a45f2d Version: $LATEST
Received event: {
  "key1": "value1",
  "key2": "value2",
  "key3": "value3"
}
END RequestId: 1961d636-734b-40c3-9a83-5170a1a45f2d
REPORT RequestId: 1961d636-734b-40c3-9a83-5170a1a45f2d Duration: 0 ms Billed Duration: 100 ms Memory Size: 1536 MB Max Memory Used: 19 MB% 
```

which is the same as we had in the previous tutorial.
