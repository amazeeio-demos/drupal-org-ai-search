#!/bin/sh

# Apply the (possibly rotated) amazee.ai credentials and re-point the search
# server at the current vector database, reindexing if it changed. Runs in
# the background so the claim returns immediately (reindexing can take a
# while), and off stdout because polydock validates claim output as a URL.
nohup sh /app/.lagoon/scripts/sync_search_vdb.sh \
    > /app/web/sites/default/files/polydock/sync_search_vdb.log 2>&1 &

ULI=`drush uli 2>/dev/null`

echo "$ULI?destination=/en/user"
