#!/bin/sh

set -ev

TMPDIR=$(mktemp -d)

LOG=$(doas /usr/bin/time rpki-client -vcj 2>&1 > /dev/zero)

doas mount_mfs -o nosuid,noperm -s 3G -P /var/cache/rpki-client swap $TMPDIR

doas chown -R job $TMPDIR

cat > $TMPDIR/output.log << EOF
# date
$(date)

# time rpki-client -v -j -c
${LOG}
EOF

# make per-ASN html file based on ROA data
(cd "${TMPDIR}/rsync/" && find * -type f -name '*.roa' -print0 | xargs -r -0 -n1 /home/job/console.rpki-client.org/roa_print.pl) &

# make per object files
cd "${TMPDIR}/rsync/"
find * -type f ! -name '*.html' -print0 | xargs -P16 -r -0 -n1 -J {} sh -c '/home/job/console.rpki-client.org/rpki_print.pl $0 > $0.html; echo -n .' {}
cd -

cp console.gif $TMPDIR/
cp /var/db/rpki-client/csv "${TMPDIR}/vrps.csv"
cp /var/db/rpki-client/json "${TMPDIR}/vrps.json"
mv "${TMPDIR}/output.log.html" "${TMPDIR}/index.html"

wait

mv "${TMPDIR}/rsync/*" "${TMPDIR}/"
find "${TMPDIR}" -type d -print0 | xargs -0 doas chmod 755
find "${TMPDIR}" -type f -print0 | xargs -0 doas chmod 644

# given the nature of the file and directory layout, using tar
# over ssh is perhaps faster than using rsync
cd "${TMPDIR}/" && tar cfj - . | ssh chloe.sobornost.net 'cd /var/www/htdocs/console.rpki-client.org/ && tar xfj -'

cd
doas umount $TMPDIR
doas rmdir $TMPDIR
