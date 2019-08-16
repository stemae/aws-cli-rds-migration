#!/bin/bash
#set -x
#trap read debug

##########################################################################
# aws-cli-setup-dms.sh
# https://aws.amazon.com/blogs/database/how-to-script-a-database-migration/
# Usage:
#   ./aws-cli-setup-dms.sh [instance_name] [profile]
#
# Executes a preconfigured migration task:
#   - Creates a replication instance
#   - Defines source and target endpoints
#   - Executes the migration task
#   - Deletes the replication instance and the source and target endpoints
##########################################################################

instance_identifier=$1
profile=$2
instance_class=dms.t2.micro
db_user_name='db_user_name'
db_password='db_password'
replication_instance_id=$instance_identifier"-replication-instance"
staging_instance_id=$instance_identifier'-staging'
endpoint_source_id=$instance_identifier'-source-endpoint'
endpoint_target_id=$instance_identifier'-target-endpoint'
replication_task_id=$instance_identifier'-task'

function wait-for-status {
    instance=$1
    target_status=$2
    status=unknown
    while [[ "$status" != "$target_status" ]]; do
        status=`aws --profile $profile dms describe-replication-instances \
                    --filters=Name="replication-instance-id",Values=$instance \
                    --query "ReplicationInstances[0].ReplicationInstanceStatus" --output text`
        sleep 5
    done
}

##########################################################################
# Create replication instance
##########################################################################
aws --profile $profile dms create-replication-instance \
    --replication-instance-identifier $replication_instance_id \
    --replication-instance-class $instance_class

##########################################################################
# Create the source and target endpoints.
##########################################################################
source_server=`aws --profile $profile rds describe-db-instances \
		   --db-instance-identifier $staging_instance_id \
		   --query 'DBInstances[*].Endpoint.Address' \
		   --output text`

aws --profile $profile dms create-endpoint \
    --endpoint-identifier $endpoint_source_id \
    --endpoint-type source \
    --engine-name mysql \
    --username $db_user_name \
    --password $db_password \
    --server-name $source_server \
    --port 3306

target_instance_id=$instance_identifier
target_server=`aws --profile $profile rds describe-db-instances \
		   --db-instance-identifier $target_instance_id \
		   --query 'DBInstances[*].Endpoint.Address' \
		   --output text`

aws --profile $profile dms create-endpoint \
    --endpoint-identifier $endpoint_target_id  \
    --endpoint-type target \
    --engine-name mysql \
    --username $db_user_name \
    --password $db_password \
    --server-name $target_server \
    --extra-connection-attributes='SET FOREIGN_KEY_CHECKS'=0 \
    --port 3306

echo "Waiting for replication instance to be available"
wait-for-status $replication_instance_id available

# save arns to variable
rep_instance_arn=$(aws --profile $profile dms describe-replication-instances \
--filters=Name="replication-instance-id",Values=$replication_instance_id \
--query 'ReplicationInstances[0].ReplicationInstanceArn' --output text)

source_endpoint_arn=$(aws --profile $profile dms describe-endpoints \
--filters=Name="endpoint-id",Values=$endpoint_source_id \
--query="Endpoints[0].EndpointArn" --output text)

target_endpoint_arn=$(aws --profile $profile dms describe-endpoints \
--filters=Name="endpoint-id",Values=$endpoint_target_id \
--query="Endpoints[0].EndpointArn" --output text)

# Test source and target endpoints from the replication instance.
echo "Test source and target endpoints from the replication instance."
aws --profile $profile dms test-connection --replication-instance-arn $rep_instance_arn --endpoint-arn $source_endpoint_arn
aws --profile $profile dms test-connection --replication-instance-arn $rep_instance_arn --endpoint-arn $target_endpoint_arn

aws --profile $profile dms describe-connections --filter Name="endpoint-arn",Values=$source_endpoint_arn,$target_endpoint_arn

##########################################################################
# create task
##########################################################################
# If the test connections are successful, use the following command to create the task:
aws --profile $profile dms create-replication-task --replication-task-identifier $replication_task_id --source-endpoint-arn $source_endpoint_arn \
--target-endpoint-arn $target_endpoint_arn --replication-instance-arn $rep_instance_arn --migration-type full-load \
--table-mappings file://table-mappings.json --replication-task-settings file://task-settings.json

#set +x	# stop debugging
