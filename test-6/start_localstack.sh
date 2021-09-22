SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

if [ ! -f "$SCRIPT_DIR/docker-compose.yml" ]; then
    echo "localstack docker-compose.yml not found! Downloading..."
    wget https://raw.githubusercontent.com/localstack/localstack/master/docker-compose.yml
fi


# used for macos
export TMPDIR=/private$TMPDIR

# set docker compose env vars to avoid them falling to default values
export SERVICES=apigateway,cloudformation,cloudwatch,dynamodb,es,firehose,iam,kinesis,lambda,route53,redshift,s3,secretsmanager,ses,sns,sqs,ssm,stepfunctions,sts
export DEBUG=1
export DATA_DIR=/tmp/localstack/data
export PORT_WEB_UI=8080
export LAMBDA_EXECUTOR=docker-reuse
export LAMBDA_REMOTE_DOCKER=true
export LAMBDA_REMOVE_CONTAINERS=true

docker-compose up