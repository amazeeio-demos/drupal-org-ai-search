# Drupal AI Demo: Search

A Drupal demo on [Lagoon](https://lagoon.sh) showing AI-powered search with [amazee.ai](https://amazee.ai): a RAG "recipe finder" chatbot answers questions about the [Umami](https://www.drupal.org/docs/umami-drupal-demonstration-installation-profile) demo content, backed by an external amazee.ai Postgres/pgvector vector database.

Unlike the sibling demos this one is not Drupal CMS: it is a `drupal/recommended-project` site installed from the `demo_umami` profile, with the AI stack ([AI](https://www.drupal.org/project/ai) 1.4, AI Agents, AI Chatbot, AI Search, Search API, LiteLLM/OpenAI providers) layered on top via recipes.

## How it's built

Installation is `drush site:install demo_umami` plus three recipes, applied in order by `.lagoon/scripts/trial_install_configure.sh`:

1. `recipes/drupal-org-ai-search-pre-init` (bundled) — installs the AI modules, the agent-based *Recipe Finder Assistant*, the Umami Recipe Bot chatbot block, a welcome block, and grants the anonymous/authenticated chatbot permissions.
2. `recipes/ai_provider_amazeeio_recipe` (composer-installed) — installs and configures the amazee.ai provider from the `AI_LLM_API_*` / `AI_DB_*` env vars.
3. `recipes/drupal-org-ai-search-post-init` (bundled) — applies the composer-installed `amazeeio_umami_search` recipe (search server + indexes on the pgvector backend, boosted search view) and wires the search server to this environment's vector database name.

Model IDs in all AI config are amazee.ai aliases (`chat`, `embeddings`, `chat_with_complex_json`, ...), never concrete models.

amazee.ai credentials are never in the repo. They're injected per environment from `AI_LLM_API_*` / `AI_DB_*` env vars — by `.lagoon/scripts/trial_install_configure.sh` (fresh install) or `.lagoon/scripts/polydock_post_deploy.sh` (Polydock trial restore).

## Local development

```sh
cp .env.example .env   # fill in your amazee.ai credentials
docker compose build
docker compose up -d
docker compose exec cli bash -c 'wait-for mariadb:3306'
docker compose exec cli bash -c '.lagoon/scripts/trial_install_configure.sh'
```

The pre-init recipe can be verified without any amazee.ai credentials (e.g. on sqlite): install `demo_umami`, then `drush recipe /app/recipes/drupal-org-ai-search-pre-init`. The provider and post-init recipes need a reachable amazee.ai LLM endpoint and pgvector database.

Note: `patches/drush-recipe-command-core-11.4.patch` restores the `drush recipe` command, which is silently missing with drush 13.7 on Drupal core 11.4.

## Lagoon / Polydock

On first deploy of a trial environment, `polydock_post_deploy.sh` fetches and restores the pre-built `app-data-image.tgz` (fast spin-up), then wires AI credentials from env vars and re-applies the post-init recipe to point the search server at the trial's own vector database. `create_polydock_app_image.sh` regenerates that image from a verified build — the recipes in git are the source of truth; the image is a build artifact.
