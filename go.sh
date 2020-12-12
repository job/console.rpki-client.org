#!/bin/sh

USERNAME='job'
OS=`uname -s`
if test $OS = 'Linux'; then
	DOAS='sudo'
else
	DOAS='doas'
fi

set -ev

TMPDIR=`mktemp -d`

LOG=$($DOAS /usr/bin/time rpki-client -vcj 2>&1 > /dev/zero)

$DOAS mount_mfs -o nosuid,noperm -s 3G -P /var/cache/rpki-client swap $TMPDIR

$DOAS chown -R $USERNAME $TMPDIR

cat > $TMPDIR/output.log << EOF
# date
$(date)

# time rpki-client -v -j -c
${LOG}
EOF

# make per-ASN html file based on ROA data
(cd $TMPDIR && find * -type f -name '*.roa' -print0 | xargs -r -0 -n1 /home/job/console.rpki-client.org/roa_print.pl) &

# make per object files
cd $TMPDIR
find * -type f ! -name '*.html' -print0 | xargs -P16 -r -0 -n1 -J {} sh -c '/home/job/console.rpki-client.org/rpki_print.pl $0 > $0.html; echo -n .' {}
cd -

cp console.gif $TMPDIR/
cp /var/db/rpki-client/csv $TMPDIR/vrps.csv
cp /var/db/rpki-client/json $TMPDIR/vrps.json
mv $TMPDIR/output.log.html $TMPDIR/index.html

wait

find $TMPDIR -type d -print0 | xargs -0 $DOAS chmod 755
find $TMPDIR -type f -print0 | xargs -0 $DOAS chmod 644

# given the nature of the file and directory layout, using tar
# over ssh is perhaps faster than using rsync
cd $TMPDIR/ && tar cfj - . | ssh chloe.sobornost.net 'cd /var/www/htdocs/console.rpki-client.org/ && tar xfj -'

# openrsync -rt $TMPDIR/ chloe.sobornost.net:/var/www/htdocs/console.rpki-client.org/

cd
$DOAS umount $TMPDIR
$DOAS rmdir $TMPDIR
