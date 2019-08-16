#!/bin/bash

##########################################################################
# aws-cli-start-migration-task.sh
# https://aws.amazon.com/blogs/database/how-to-script-a-database-migration/
# Usage:
#   ./aws-cli-start-migration-task.sh [instance_name] [profile]
#
# Executes a preconfigured migration task:
#   - Starts a pre-configured migration-task
##########################################################################

instance_identifier=$1
profile=$2
replication_task_id=$instance_identifier'-task'
echo $replication_task_id

replication_task_arn=$(aws --profile $profile dms describe-replication-tasks \
--filters=Name="replication-task-id",Values=$replication_task_id \
--query "ReplicationTasks[0].ReplicationTaskArn" --output text)

# Run the following command to start the task after it is ready to be executed:
# for first execution
# aws --profile $profile dms start-replication-task --replication-task-arn $replication_task_arn \
# --start-replication-task-type start-replication

aws --profile $profile dms start-replication-task --replication-task-arn $replication_task_arn \
--start-replication-task-type reload-target

aws --profile $profile dms describe-replication-tasks --filters Name="replication-task-arn",Values=$replication_task_arn \
--query "ReplicationTasks[0].ReplicationTaskStats"

