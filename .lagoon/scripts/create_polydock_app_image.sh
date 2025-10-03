#!/bin/sh

echo "Ensuring polydock directory exists"
mkdir -p /app/web/sites/default/files/polydock/

cd /app

drush sql-dump --result-file=/app/web/sites/default/files/polydock/db-image

cd /app/web/sites/default

echo "Removing old app data image"
rm files/polydock/app-data-image.tgz

echo "Creating new app data image"
tar --exclude=files/config_* \
	--exclude=files/js \
	--exclude=files/css \
	--exclude=files/php \
	--exclude=files/.polydock* \
	--exclude=files/polydock/app-data-image* \
	-zcvf files/polydock/app-data-image.tgz \
	files

cd /app
