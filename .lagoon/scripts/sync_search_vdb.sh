#!/bin/sh

####################################################
# Bring the site in line with the current amazee.ai
# credentials, and keep AI Search servers pointed at
# the right pgvector database.
#
# The claim process can rotate the AI / vector DB
# credentials after provisioning. The provider config
# is re-applied from the Lagoon environment, and any
# AI Search server whose backend config still points
# at the old database is re-pointed and reindexed.
# Reindexing only happens when the database actually
# changed, so this is cheap to re-run.
####################################################

LOCKDIR="/tmp/sync_search_vdb.lock"

# Only run on an installed site.
if [ ! -f /app/web/sites/default/files/.lagoon_trial_installed ]; then
    echo "Site not installed yet, skipping search vdb sync"
    exit 0
fi

# Don't overlap with a running sync/reindex.
if ! mkdir "$LOCKDIR" 2>/dev/null; then
    echo "Another sync is already running, skipping"
    exit 0
fi
trap 'rmdir "$LOCKDIR"' EXIT

cd /app

# Re-apply the credentials from the Lagoon environment, in case they were
# rotated since provisioning. Mirrors polydock_post_deploy.sh.
if [ ! -z "$AI_LLM_API_TOKEN" ]; then
    drush config:set key.key.amazeeio_ai key_provider_settings.key_value $AI_LLM_API_TOKEN -y
fi
if [ ! -z "$AI_LLM_API_URL" ]; then
    drush config:set ai_provider_amazeeio.settings host $AI_LLM_API_URL -y
fi
if [ ! -z "$AI_DB_NAME" ]; then
    drush config:set ai_provider_amazeeio.settings postgres_default_database $AI_DB_NAME -y
fi
if [ ! -z "$AI_DB_HOST_NAME" ]; then
    drush config:set ai_provider_amazeeio.settings postgres_host $AI_DB_HOST_NAME -y
    drush config:set ai_provider_amazeeio.settings postgres_port 5432 -y
fi
if [ ! -z "$AI_DB_PASSWORD" ]; then
    drush config:set key.key.amazeeio_postgres key_provider_settings.key_value $AI_DB_PASSWORD -y
    drush config:set key.key.amazeeio_ai_database key_provider_settings.key_value $AI_DB_PASSWORD -y
fi
if [ ! -z "$AI_DB_USERNAME" ]; then
    drush config:set ai_provider_amazeeio.settings postgres_username $AI_DB_USERNAME -y
fi

RESULT=$(drush ev '
$db = \Drupal::config("ai_provider_amazeeio.settings")->get("postgres_default_database");
if (!$db || !is_string($db)) { print "SKIP"; return; }
$storage = \Drupal::entityTypeManager()->getStorage("search_api_server");
$ids = $storage->getQuery()
  ->condition("backend", "search_api_ai_search")
  ->condition("backend_config.database", "amazeeio_vector_db")
  ->accessCheck(FALSE)->execute();
$changed = FALSE;
foreach ($storage->loadMultiple($ids) as $server) {
  $config = $server->getBackendConfig();
  if (($config["database_settings"]["database_name"] ?? "") === $db) { continue; }
  $config["database_settings"]["database_name"] = $db;
  $server->setBackendConfig($config);
  $server->save();
  \Drupal::logger("dod_ai_search")->info("Re-pointed search server @s at pgvector database @d.", ["@s" => $server->id(), "@d" => $db]);
  $changed = TRUE;
}
print $changed ? "CHANGED" : "OK";
' 2>/dev/null | tail -1)

echo "Search vdb sync result: $RESULT"

if [ "$RESULT" = "CHANGED" ]; then
    echo "Vector database changed - rebuilding the search index"
    drush cr
    drush sapi-r -y
    drush sapi-i -y
fi
