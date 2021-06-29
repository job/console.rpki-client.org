#!/bin/sh

set -ev

TMPDIR=$(mktemp -d)

LOG_RRDP=$(doas /usr/bin/time rpki-client -v -coj 2>&1 | ts)
LOG_RSYNC=$(doas /usr/bin/time rpki-client -v -coj -R -d /var/cache/rpki-client-rsync /var/db/rpki-client-rsync 2>&1 | ts)

doas mount_mfs -o nosuid,noperm -s 5G -P /var/cache/rpki-client-rsync swap "${TMPDIR}"

doas chown -R job "${TMPDIR}"

cd "${TMPDIR}"

# make a html file for each ASN with all the ROAs referencing that ASID
(cd rsync && find * -type f -name '*.roa' -print0 | xargs -r -0 -n1 /home/job/console.rpki-client.org/roa_print.pl) &

# Make HTML for all objects
# this is slow...
find * -type f ! -name '*.html' -print0 | xargs -P16 -r -0 -n1 -J {} sh -c '/home/job/console.rpki-client.org/rpki_print.pl $0 > $0.html; echo -n .' {}

wait

sed 1d /var/db/rpki-client-rsync/csv | sed 's/,[0-9]*$//' | sort > "${TMPDIR}/vrps-rsync-only.csv"
sed 1d /var/db/rpki-client/csv | sed 's/,[0-9]*$//' | sort > "${TMPDIR}/vrps-rrdp-rsync.csv"

cat > "${TMPDIR}/output.log" << EOF
# time rpki-client -v -c -j
${LOG_RRDP}

# time rpki-client -v -c -j -R
${LOG_RSYNC}

# wc -l vrps-rrdp-rsync.csv vrps-rsync-only.csv
$(cd "${TMPDIR}" && wc -l vrps-rrdp-rsync.csv vrps-rsync-only.csv)

# comm -3 vrps-rrdp-rsync.csv vrps-rsync-only.csv
$(cd "${TMPDIR}" && comm -3 vrps-rrdp-rsync.csv vrps-rsync-only.csv)
EOF

/home/job/console.rpki-client.org/rpki_print.pl "${TMPDIR}/output.log" > "${TMPDIR}/index.html"

cp /home/job/console.rpki-client.org/console.gif "${TMPDIR}/"

wait

find "${TMPDIR}" -type d -print0 | xargs -0 doas chmod 755
find "${TMPDIR}" -type f -print0 | xargs -0 doas chmod 644

# given the nature of the file and directory layout, using tar
# over ssh is perhaps faster than using rsync
set +e
cd "${TMPDIR}/" && tar cfj - . | ssh chloe.sobornost.net 'cd /var/www/htdocs/console.rpki-client.org/ && tar xfj -'
set -e

# cleanup
cd /
doas umount $TMPDIR
doas rmdir $TMPDIR
