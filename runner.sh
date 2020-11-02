#!/bin/sh

while true; do
        doas /home/job/console/generate-rpki-console /home/job/console/output
        rsync -rt --delete -e 'ssh -i ~/.ssh/id_ed25519_start' /home/job/console/output/ chloe.sobornost.net:/var/www/htdocs/console.rpki-client.org/
done
