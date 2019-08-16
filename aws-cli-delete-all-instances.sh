#!/bin/bash
#set -x
#trap read debug

##########################################################################
# aws-cli-close-dms.sh
# https://aws.amazon.com/blogs/database/how-to-script-a-database-migration/
# Usage:
#   ./aws-cli-close-dms.sh [instance_name] [profile]
#
# Executes a preconfigured migration task:
#   - Deletes the staging clone
#   - Deletes the replication task
#   - Deletes the replication instance
#   - Deletes source and target endpoints
##########################################################################

instance_identifier=$1
profile=$2
db_user_name=db_user_name
db_password=db_password
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

# save arns to variable
replication_task_arn=$(aws --profile $profile dms describe-replication-tasks \
--filters Name="replication-task-id",Values=$replication_task_id \
--query "ReplicationTasks[0].ReplicationTaskArn" --output text)

rep_instance_arn=$(aws --profile $profile dms describe-replication-instances \
--filters=Name="replication-instance-id",Values=$replication_instance_id \
--query 'ReplicationInstances[0].ReplicationInstanceArn' --output text)

source_endpoint_arn=$(aws --profile $profile dms describe-endpoints \
--filters=Name="endpoint-id",Values=$endpoint_source_id \
--query="Endpoints[0].EndpointArn" --output text)

target_endpoint_arn=$(aws --profile $profile dms describe-endpoints \
--filters=Name="endpoint-id",Values=$endpoint_target_id \
--query="Endpoints[0].EndpointArn" --output text)

source_server=`aws --profile $profile rds describe-db-instances \
		   --db-instance-identifier $staging_instance_id \
		   --query 'DBInstances[*].Endpoint.Address' \
		   --output text`
##########################################################################
# Stop the replication task.
##########################################################################
aws --profile $profile dms stop-replication-task --replication-task-arn $replication_task_arn
aws --profile $profile dms delete-replication-task --replication-task-arn $replication_task_arn

##########################################################################
# Delete the replication instance.
##########################################################################
aws --profile $profile dms delete-replication-instance --replication-instance-arn $rep_instance_arn

##########################################################################
# Delete the source and target endpoints.
##########################################################################
aws --profile $profile dms delete-endpoint --endpoint-arn $source_endpoint_arn
aws --profile $profile dms delete-endpoint --endpoint-arn $target_endpoint_arn


##########################################################################
# Delete the staging instance.
##########################################################################
aws --profile $profile rds delete-db-instance --db-instance-identifier $staging_instance_id --skip-final-snapshot
#set +x	# stop debugging
