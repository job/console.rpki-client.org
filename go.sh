#!/bin/sh
# Copyright (c) 2020-2022 Job Snijders <job@sobornost.net>
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

set -ev

MAXPROC=6
LOG_RRDP=$(mktemp)
LOG_RSYNC=$(mktemp)
LIST_OF_DIRS=$(mktemp)
export HTDOCS="/var/www/htdocs/console.rpki-client.org"
export RSYNC_CACHE="/var/cache/rpki-client-rsync"
export ASID_DB="${RSYNC_CACHE}/asid"

doas chown -R _rpki-client ${RSYNC_CACHE}

(doas /usr/bin/time rpki-client -coj 2>&1 | ts > ${LOG_RRDP}) &
(doas /usr/bin/time rpki-client -coj -R -d ${RSYNC_CACHE} /var/db/rpki-client-rsync 2>&1 | ts > ${LOG_RSYNC}) &
wait

doas chown -R job ${RSYNC_CACHE}
cd ${RSYNC_CACHE}

rm -rf ${ASID_DB}
mkdir -p ${ASID_DB}

cd ${RSYNC_CACHE}/
rmdir .rsync

(find . -type f -name '*.roa' -print0 | xargs -0 -P${MAXPROC} -n1 /home/job/console.rpki-client.org/asid_roa_map.sh) &

date +%s > ${HTDOCS}/dump.tmp
(find . -type f -print0 | xargs -0 rpki-client -f) >> ${HTDOCS}/dump.tmp && mv ${HTDOCS}/dump.tmp ${HTDOCS}/dump.txt
rm -f ${HTDOCS}/dump.tmp.gz && gzip -k ${HTDOCS}/dump.tmp && mv ${HTDOCS}/dump.tmp.gz ${HTDOCS}/dump.txt.gz

wait

cd ${ASID_DB}
ls -1 | xargs -P${MAXPROC} -n1 /home/job/console.rpki-client.org/roa_print.pl

cd ${RSYNC_CACHE}
rm -rf ${ASID_DB}
cat > roas.html << EOF
<a href="/"><img src="/console.gif" border=0></a><br />
<i>Generated at $(date) by <a href="https://www.rpki-client.org/">rpki-client</a>.</i><br /><br />
<style>td { border-bottom: 1px solid grey; }</style>
<table>
<tr><th>Prefixes</th><th width=20%>asID</th><th>Subject Information Access (SIA)</th></tr>
EOF
find . -type f -name '*.all.html' | sed 's/..//' | sort -r -n | xargs cat >> roas.html
find . -type f -name '*.all.html' | xargs rm
find . -type d | sed '1d' | sed 's/..//' > ${LIST_OF_DIRS}

for repo in $(cat ${LIST_OF_DIRS}); do
	cd ${RSYNC_CACHE}/${repo}
	if [ ! "$(find . -type f -maxdepth 1 ! -name '*.html')" ]; then
		# empty dir
		continue
	fi
	find . ! -name SHA256 -type f -maxdepth 1 | cut -d/ -f2 | xargs sha256 -- > SHA256
	mkdir -p ${HTDOCS}/${repo}
	mv SHA256 ${HTDOCS}/${repo}/

	cd ${HTDOCS}/${repo}
	# find files that changed or were missed in a previous run
	for fn in $(sha256 -q -c SHA256 2>/dev/zero | awk '{ print $2 }' | sed 's/:$//'); do
		echo "${repo}/${fn}"
	done
	# check if HTML ever was generated
	for fn in $(cat SHA256 | awk '{ print $2 }' | sed 's/^.//;s/.$//'); do
		test -f "${fn}.html" || echo "${repo}/${fn}"
	done
done | xargs -P${MAXPROC} -r -n1 -J {} sh -c \
	'/home/job/console.rpki-client.org/rpki_print.pl $0 > $0.html' {}

wait

cd ${RSYNC_CACHE}
find . -type d -print0 | xargs -0 doas chmod 755
find . -type f -print0 | xargs -0 doas chmod 644
# copy all freshly generated HTML and DER files
rsync -rt . ${HTDOCS}/
find . -type f -name '*.html' | xargs rm

sed 1d /var/db/rpki-client/csv | sed 's/,[0-9]*$//' | \
	sort > "${HTDOCS}/vrps-rrdp-rsync.csv"
sed 1d /var/db/rpki-client-rsync/csv | sed 's/,[0-9]*$//' | \
	sort > "${HTDOCS}/vrps-rsync-only.csv"

# make the pretty index page
cat > "${HTDOCS}/output.log" << EOF
# time rpki-client -c -j
$(cat ${LOG_RRDP})

# time rpki-client -R -c -j
$(cat ${LOG_RSYNC})

# wc -l vrps-rrdp-rsync.csv vrps-rsync-only.csv
$(cd "${HTDOCS}" && wc -l vrps-rrdp-rsync.csv vrps-rsync-only.csv)

# comm -3 vrps-rrdp-rsync.csv vrps-rsync-only.csv
$(cd "${HTDOCS}" && comm -3 vrps-rrdp-rsync.csv vrps-rsync-only.csv)
EOF

/home/job/console.rpki-client.org/rpki_print.pl "${HTDOCS}/output.log" > "${HTDOCS}/index.html"
cp /home/job/console.rpki-client.org/console.gif "${HTDOCS}/"

# cleanup
rm ${LOG_RRDP}
rm ${LOG_RSYNC}
rm ${LIST_OF_DIRS}
