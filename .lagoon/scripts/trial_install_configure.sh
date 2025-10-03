#!/bin/sh

LOCKFILE="/app/web/sites/default/files/.lagoon_trial_installed"

if [ -f "$LOCKFILE" ]; then
  echo "Site has already been installed"
elif [ -z "$AI_LLM_API_URL" ]; then
  echo "Please configure the AI_LLM_API_URL variable"
elif [ -z "$AI_LLM_API_TOKEN" ]; then
  echo "Please configure the AI_LLM_API_TOKEN variable"
elif [ -z "$AI_DB_HOST_NAME" ]; then
  echo "Please configure the AI_DB_HOST_NAME variable"
elif [ -z "$AI_DB_NAME" ]; then
  echo "Please configure the AI_DB_NAME variable"
elif [ -z "$AI_DB_PASSWORD" ]; then
  echo "Please configure the AI_DB_PASSWORD variable"
elif [ -z "$AI_DB_USERNAME" ]; then
  echo "Please configure the AI_DB_USERNAME variable"
else
  # Install site demo
  echo "Installing the site basics"
  drush site:install -y demo_umami

  # Install the provider.
  echo "Installing the amazee.io AI provider"

  # Install the provider.
  drush recipe ../recipes/ai_provider_amazeeio_recipe \
    --input=ai_provider_amazeeio_recipe.llm_host=$AI_LLM_API_URL \
    --input=ai_provider_amazeeio_recipe.llm_api_key=$AI_LLM_API_TOKEN \
    --input=ai_provider_amazeeio_recipe.postgres_db_host=$AI_DB_HOST_NAME  \
    --input=ai_provider_amazeeio_recipe.postgres_db_port=5432  \
    --input=ai_provider_amazeeio_recipe.postgres_db_username=$AI_DB_USERNAME  \
    --input=ai_provider_amazeeio_recipe.postgres_db_password=$AI_DB_PASSWORD  \
    --input=ai_provider_amazeeio_recipe.postgres_db_default_database=$AI_DB_NAME 

  # Install the recipe.
  drush recipe ../recipes/amazeeio_umami_search \
    --input amazeeio_umami_search.postgres_db_default_database=$AI_DB_NAME

  # Clear the cache
  echo "Rebuilding of the Drupal cache"
  drush cr

  touch $LOCKFILE
  echo "Site install complete."
fi
