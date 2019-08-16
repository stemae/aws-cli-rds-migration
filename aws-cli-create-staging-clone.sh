#!/bin/bash

##########################################################################
# aws-cli-create-staging-clone.sh
#
# Usage:
#   ./aws-cli-create-staging-clone.sh [instance_name] [profile]
#
# Creates a new RDS instance by cloning the latest production snapshot.
#   - Determine the snapshot id to use (using the latest snapshot-date)
#   - Create the new database
#   - Make necessary modifications to the new instances (disable backups)
##########################################################################

instance_identifier=$1
profile=$2
instance_class=db.t3.micro
staging_instance_id=$instance_identifier'-staging'

function wait-for-status {
    instance=$1
    target_status=$2
    status=unknown
    while [[ "$status" != "$target_status" ]]; do
        status=`aws --profile $profile rds describe-db-instances \
            --db-instance-identifier $instance --query "DBInstances[0].DBInstanceStatus" --output text`
        sleep 5
    done
}

# fetch snapshot id (and remove the quotes from the string)
snapshot_id=`aws --profile $profile rds describe-db-snapshots \
    --db-instance-identifier $instance_identifier \
    --query="reverse(sort_by(DBSnapshots, &SnapshotCreateTime))[0]|DBSnapshotIdentifier"`
snapshot_id="${snapshot_id%\"}";snapshot_id="${snapshot_id#\"}"
echo "Snapshot Id: $snapshot_id"

# create the new instance
aws --profile $profile rds restore-db-instance-from-db-snapshot \
    --db-instance-identifier $staging_instance_id  \
    --db-snapshot-identifier $snapshot_id \
    --db-instance-class $instance_class

# TODO: no backup setting
echo "Waiting for new DB instance to be available"
echo $staging_instance_id
wait-for-status "$staging_instance_id" available
