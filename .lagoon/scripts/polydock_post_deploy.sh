#!/bin/sh

####################################################
# This script gets run by Polydock as a post deploy
# over ssh. This is NOT a Lagoon post-deploy task.
###################################################

LOCKFILE="/app/web/sites/default/files/.polydock_post_deploy"
APP_IMAGE_URL_DEFAULT="https://nginx.main.ai-trial-storage.us2.amazee.io/storage/drupal-org/search/app-data-image.tgz"
POLYDOCK_APP_IMAGE_FILENAME="polydock_post_deploy_image.tgz"
POLYDOCK_TMP="/tmp/polydock_post_deploy"
POLYDOCK_APP_IMAGE_DB_FILENAME="/app/web/sites/default/files/polydock/db-image"

mkdir -p $POLYDOCK_TMP

if [ -z "POLYDOCK_APP_IMAGE_URL" ]; then
    export POLYDOCK_APP_IMAGE_URL=$APP_IMAGE_URL_DEFAULT
fi;

if [ ! -f "$LOCKFILE" ]; then
    echo "This is the first time the script is running"
    cd $POLYDOCK_TMP
    wget -O $POLYDOCK_APP_IMAGE_FILENAME -P $POLYDOCK_TMP $APP_IMAGE_URL_DEFAULT

    echo "Extracing app image"
    tar -zxf $POLYDOCK_APP_IMAGE_FILENAME

    echo "Syncing app image files"
    rsync -a files /app/web/sites/default


    cd /app

    if [ -f "$POLYDOCK_APP_IMAGE_DB_FILENAME" ]; then
        echo "Removing collation from DB ..."
        sed -i 's/COLLATE=utf8mb3_uca1400_ai_ci.*;/;/g' $POLYDOCK_APP_IMAGE_DB_FILENAME
        sed -i 's/COLLATE=utf8mb4_uca1400_ai_ci.*;/;/g' $POLYDOCK_APP_IMAGE_DB_FILENAME
        echo "Loading database image"
        cat $POLYDOCK_APP_IMAGE_DB_FILENAME | drush sql-cli
        echo "Database image loaded"
    else
        echo "There is no database image at: $POLYDOCK_APP_IMAGE_DB_FILENAME"
    fi;

    if [ ! -z "$AI_LLM_API_TOKEN" ]; then
        echo "Importing amazee Private AI keys"
        drush config:set key.key.amazeeio_ai key_provider_settings.key_value $AI_LLM_API_TOKEN -y
    fi;

    if [ ! -z "$AI_LLM_API_URL" ]; then
        echo "Importing amazee Private AI LLM URL"
        drush config:set ai_provider_amazeeio.settings host $AI_LLM_API_URL -y
    fi;

    if [ ! -z "$AI_DB_NAME" ]; then
        echo "Importing amazee Private AI AI_DB_NAME"
        drush config:set ai_provider_amazeeio.settings postgres_default_database $AI_DB_NAME -y
    fi;

    if [ ! -z "$AI_DB_HOST_NAME" ]; then
        echo "Importing amazee Private AI AI_DB_HOST_NAME"
        drush config:set ai_provider_amazeeio.settings postgres_host $AI_DB_HOST_NAME -y

        echo "Importing amazee Private AI AI_DB_HOST_NAME"
        drush config:set ai_provider_amazeeio.settings postgres_port 5432 -y
    fi;

    if [ ! -z "$AI_DB_PASSWORD" ]; then
        echo "Importing amazee Private AI AI_DB_PASSWORD for TWO KEYS"
        drush config:set key.key.amazeeio_postgres key_provider_settings.key_value $AI_DB_PASSWORD -y
        drush config:set key.key.amazeeio_ai_database key_provider_settings.key_value $AI_DB_PASSWORD -y
    fi;

    if [ ! -z "$AI_DB_USERNAME" ]; then
        echo "Importing amazee Private AI AI_DB_USERNAME"
        drush config:set ai_provider_amazeeio.settings postgres_username $AI_DB_USERNAME -y
        drush config:set search_api.server.umami_recipe_server backend_config.database_settings.database_name $AI_DB_NAME -y
    fi;

    if [ ! -z "$AI_DB_USERNAME" ]; then
        echo "Resaving umami_recipe_server to create tables"
        drush entity:save search_api_server umami_recipe_server
    fi;

    if [ ! -z "$POLYDOCK_GENERATED_APP_ADMIN_USERNAME" ]; then
        echo "Updating admin username to $POLYDOCK_GENERATED_APP_ADMIN_USERNAME"
        echo "update users_field_data set name='$POLYDOCK_GENERATED_APP_ADMIN_USERNAME' where name='admin'" | drush sql-cli
        drush cr

        if [ ! -z "$POLYDOCK_GENERATED_APP_ADMIN_PASSWORD" ]; then
            echo "Updating $POLYDOCK_GENERATED_APP_ADMIN_USERNAME password";
            drush upwd "$POLYDOCK_GENERATED_APP_ADMIN_USERNAME" "$POLYDOCK_GENERATED_APP_ADMIN_PASSWORD"
        fi;

    fi;

    echo "Created $LOCKFILE to ensure we don't run more than once"
    touch $LOCKFILE
fi;

cd /app

echo "Now running the tasks that should run on every deploy"
drush cr
drush sapi-r -y
drush sapi-i -
