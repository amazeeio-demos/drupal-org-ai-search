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
  # Install the Umami demo profile.
  echo "Installing the site basics"
  drush -n site:install demo_umami

  # AI modules, assistant, chatbot and welcome block.
  echo "Applying the drupal-org-ai-search-pre-init recipe"
  drush recipe /app/recipes/drupal-org-ai-search-pre-init

  # Install and configure the amazee.io AI provider.
  echo "Installing the amazee.io AI provider"
  drush recipe /app/recipes/ai_provider_amazeeio_recipe \
    --input=ai_provider_amazeeio_recipe.llm_host=$AI_LLM_API_URL \
    --input=ai_provider_amazeeio_recipe.llm_api_key=$AI_LLM_API_TOKEN \
    --input=ai_provider_amazeeio_recipe.postgres_db_host=$AI_DB_HOST_NAME \
    --input=ai_provider_amazeeio_recipe.postgres_db_port=5432 \
    --input=ai_provider_amazeeio_recipe.postgres_db_username=$AI_DB_USERNAME \
    --input=ai_provider_amazeeio_recipe.postgres_db_password=$AI_DB_PASSWORD \
    --input=ai_provider_amazeeio_recipe.postgres_db_default_database=$AI_DB_NAME

  # Search server/index (via the amazeeio_umami_search recipe) wired to the
  # external pgvector database.
  echo "Applying the drupal-org-ai-search-post-init recipe"
  drush recipe /app/recipes/drupal-org-ai-search-post-init \
    --input=drupal-org-ai-search-post-init.postgres_default_database=$AI_DB_NAME \
    --input=amazeeio_umami_search.postgres_db_default_database=$AI_DB_NAME

  # Demos don't self-update; remove the Update Manager stack so admins don't
  # see "out of date" warnings. Per-module + `|| true` handles both the CMS
  # demos (all three present) and search (only `update`).
  echo "Uninstalling update-manager modules"
  for module in automatic_updates update package_manager; do
    drush -y pm:uninstall "$module" || true
  done

  # Clear the cache and index the content.
  echo "Rebuilding the Drupal cache"
  drush cr

  echo "Indexing content"
  drush sapi-r -y
  drush sapi-i -y

  touch $LOCKFILE
  echo "Site install complete."
fi
