# aws-cli-rds-migration
collection of shell scripts to migrate between two mysql instances on rds. 

They should be executed via:
~~~~
source aws-cli-create-staging-clone.sh <database_name> <user_role>
~~~~
where the database_name is the name of the rds-database on aws one wishes to 
migrate to, e.g. `my_database` and the user_role is the role with the required permissions, 
e.g. `my-login-poweruser`. 

- aws-cli-create-staging-clone.sh
    - creates a staging clone from the last snapshot
- aws-cli-setup-dms.sh
    - creates replication-instance, task and endpoints
- aws-cli-start-migration-task.sh
    - starts the migration task from the staging clone and the database
- aws-cli-delete-all-instances.sh
    - deletes the staging clone, replication-instance, task and endpoints
    
The migration task is configured via two json files.
- table-mappings.json
- task-settings.json
