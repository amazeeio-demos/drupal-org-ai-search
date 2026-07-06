FROM uselagoon/php-8.4-cli-drupal:latest AS cli

# Set up scaffolding (composer install + settings.php) as an entrypoint.
COPY .lagoon/scripts/scaffold.sh /lagoon/entrypoints/999-drupal-scaffold.sh

COPY composer.* patches.lock.json /app/
COPY patches /app/patches
COPY assets /app/assets
COPY .lagoon /app/.lagoon

# Let the scaffolding file take care of running the install for us.
RUN /lagoon/entrypoints/999-drupal-scaffold.sh
RUN mkdir -p -v -m775 /app/web/sites/default/

# Copy the rest of the repo (bundled recipes, drush config, ...) into the
# image so non-mounted (Lagoon) environments have them too.
COPY . /app

# Define where the Drupal Root is located
ENV WEBROOT=web

FROM uselagoon/nginx-drupal:latest AS nginx

COPY --from=cli /app /app

ENV WEBROOT=web

FROM uselagoon/php-8.4-fpm:latest AS php

COPY --from=cli /app /app

# php-fpm needs to have the composer binary and rsync available
COPY --from=cli /usr/local/bin/composer /usr/local/bin/composer
