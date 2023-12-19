#!/bin/sh
# Copyright (c) 2020-2023 Job Snijders <job@sobornost.net>
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

HTDOCS="/var/www/htdocs/console.rpki-client.org"
ASIDDB="${HTDOCS}/asid"
CACHEDIR="/var/cache/rpki-client"
OUTDIR="/var/db/rpki-client"
RSYNC_CACHEDIR="/var/cache/rpki-client-rsync"
RSYNC_OUTDIR="/var/db/rpki-client-rsync"

HTMLWRITER="$(mktemp -p /tmp html.XXXXXXXXXX)"
JSONWRITER="$(mktemp -p /tmp json.XXXXXXXXXX)"
ASIDWRITER="$(mktemp -p /tmp asid.XXXXXXXXXX)"
WD="$(mktemp -d)"
LOG_RRDP="$(mktemp -p ${WD} rrdplog.XXXXXXXXXX)"
LOG_RSYNC="$(mktemp -p ${WD} rsynclog.XXXXXXXXXX)"
ALLFILES="$(mktemp -p ${WD} allfiles.XXXXXXXXXX)"
FILELIST="$(mktemp -p ${WD} filelist.XXXXXXXXXX)"
HASHFILELIST="$(mktemp -p ${WD} sha256list.XXXXXXXXXX)"
DIFFLIST="$(mktemp -p ${WD} difflist.XXXXXXXXXX)"
INVALIDFILELIST="$(mktemp -p ${WD} invalidfilelist.XXXXXXXXXX)"
INVALIDHASHFILELIST="$(mktemp -p ${WD} invalidhashfilelist.XXXXXXXXXX)"
INVALIDDIFFLIST="$(mktemp -p ${WD} invaliddifflist.XXXXXXXXXX)"

doas cp console.gif footer.html "${HTDOCS}/"
doas rm -rf ${ASIDDB} && doas mkdir ${ASIDDB} && doas chown www ${ASIDDB}
install html.pl ${HTMLWRITER}
install json.pl ${JSONWRITER}
install asid.pl ${ASIDWRITER}

(doas rpki-client -coj    -d ${CACHEDIR}       ${OUTDIR}       2>&1 | ts > ${LOG_RRDP})  &
(doas rpki-client -coj -R -d ${RSYNC_CACHEDIR} ${RSYNC_OUTDIR} 2>&1 | ts > ${LOG_RSYNC}) &
wait

cd ${CACHEDIR}/

prep_vp() {
	doas install -m 644 -o www /var/db/rpki-client/$1 ${HTDOCS}/rpki.$1.tmp
	doas -u www gzip -k ${HTDOCS}/rpki.$1.tmp
	doas -u www mv ${HTDOCS}/rpki.$1.tmp ${HTDOCS}/rpki.$1
	doas -u www mv ${HTDOCS}/rpki.$1.tmp.gz ${HTDOCS}/rpki.$1.gz
	doas -u www touch ${HTDOCS}/rpki.$1 ${HTDOCS}/rpki.$1.gz
	doas -u www ln -f ${HTDOCS}/rpki.$1 ${HTDOCS}/vrps.$1
	doas -u www ln -f ${HTDOCS}/rpki.$1.gz ${HTDOCS}/vrps.$1.gz
}

prep_vp csv
prep_vp json

find * -type d | (cd ${HTDOCS}; xargs doas -u www mkdir -p)
find * -type f | sort | tee ${FILELIST} | xargs sha256 -r | sort > ${HASHFILELIST}
(cd ${HTDOCS}; find . -type f -not -name 'lost+found' -not -name '*.html' -not -name '*.json' -not -name 'index.*' -not -name '*.gz' -not -name '*.csv' -not -name '*.gif') \
	| sed -e 's,^\./,,' | sort | uniq > ${ALLFILES}
comm -1 -3 ${FILELIST} ${ALLFILES} > ${INVALIDFILELIST}
(cd ${HTDOCS}; cat ${INVALIDFILELIST} | xargs sha256 -r) | sort > ${INVALIDHASHFILELIST}

if [ -f ${HTDOCS}/index.SHA256 ]; then
	comm -2 -3 ${HASHFILELIST} ${HTDOCS}/index.SHA256 | awk '{print $2}' | sort > ${DIFFLIST}
	(cat ${DIFFLIST} | xargs rpki-client -d ${CACHEDIR} -vvf | doas -u www ${HTMLWRITER}) &
	(cat ${DIFFLIST} | xargs rpki-client -d ${CACHEDIR} -jf | doas -u www ${JSONWRITER}) &
else
	(cat ${FILELIST} | xargs rpki-client -d ${CACHEDIR} -vvf | doas -u www ${HTMLWRITER}) &
	(cat ${FILELIST} | xargs rpki-client -d ${CACHEDIR} -jf | doas -u www ${JSONWRITER}) &
fi
wait

if [ -f ${HTDOCS}/index.old.SHA256 ]; then
	comm -2 -3 ${INVALIDHASHFILELIST} ${HTDOCS}/index.old.SHA256 | awk '{print $2}' | sort > ${INVALIDDIFFLIST}
	(cd ${HTDOCS}; cat ${INVALIDDIFFLIST} | xargs rpki-client -d ${CACHEDIR} -vvf | doas -u www ${HTMLWRITER}) &
	(cd ${HTDOCS}; cat ${INVALIDDIFFLIST} | xargs rpki-client -d ${CACHEDIR} -jf | doas -u www ${JSONWRITER}) &
else
	(cd ${HTDOCS}; cat ${INVALIDFILELIST} | xargs rpki-client -d ${CACHEDIR} -vvf | doas -u www ${HTMLWRITER}) &
	(cd ${HTDOCS}; cat ${INVALIDFILELIST} | xargs rpki-client -d ${CACHEDIR} -jf | doas -u www ${JSONWRITER}) &
fi
wait

doas rsync -xrt --chown www --exclude=.rsync --exclude=.rrdp --info=progress2 ./ /var/www/htdocs/console.rpki-client.org/

cd ${HTDOCS}/

cat ${FILELIST} | sed 's/$/.json/' | xargs cat | jq -c '.' | doas -u www tee dump.json.tmp | egrep '"router_key"|"roa"|"aspa"' | doas -u www ${ASIDWRITER}
echo '{"type":"metadata","buildmachine":"'$(hostname)'","buildtime":"'$(date +%Y-%m-%dT%H:%M:%SZ)'","objects":'$(cat dump.json.tmp | wc -l)'}' | doas -u www tee -a dump.json.tmp
doas -u www rm -f dump.json.tmp.gz && doas -u www gzip -k dump.json.tmp
doas -u www mv dump.json.tmp dump.json
doas -u www mv dump.json.tmp.gz dump.json.gz
doas -u www touch dump.json dump.json.gz
doas install -m 644 -o www ${HASHFILELIST} ${HTDOCS}/index.SHA256
doas install -m 644 -o www ${INVALIDHASHFILELIST} ${HTDOCS}/index.old.SHA256

doas rsync -xrt --chown www --info=progress2 ${ASIDDB}/ ${HTDOCS}/

sed 1d ${OUTDIR}/csv | sed 's/,[0-9]*$//' | sort | doas -u www tee vrps-rrdp-rsync.csv > /dev/zero
sed 1d ${RSYNC_OUTDIR}/csv | sed 's/,[0-9]*$//' | sort | doas -u www tee vrps-rsync-only.csv > /dev/zero

# make the pretty index page
doas -u www tee index.html > /dev/zero << EOF
<img border=0 src="/console.gif" />
<br />
<pre>
All validated RPKI payloads observed by this instance are available in <a href="/rpki.csv">csv</a> and <a href="/rpki.json">json</a> format.
A full JSON dump of all currently observed objects in the RPKI: <a href="/dump.json">dump.json</a> (<a href="/dump.json.gz">gzipped</a>).
Archived full copies of the global RPKI: <a href="https://www.rpkiviews.org/">rpkiviews.org</a>.

For example, you can view all VRPs related to AS 8283 at <a href="/AS8283.html">/AS8283.html</a>.
You can substitute the digits in the above URL with any ASN referenced as asID.

Listings of all currently valid <a href="/aspa.html">ASPA</a> objects and <a href="/bgpsec.html">BGPSec</a> router keys.

Trust Anchors:
<a href="/ta/afrinic/AfriNIC.cer.html">/ta/afrinic/AfriNIC.cer</a>
<a href="/ta/apnic/apnic-rpki-root-iana-origin.cer.html">/ta/apnic/apnic-rpki-root-iana-origin.cer</a>
<a href="/ta/arin/arin-rpki-ta.cer.html">/ta/arin/arin-rpki-ta.cer</a>
<a href="/ta/lacnic/rta-lacnic-rpki.cer.html">/ta/lacnic/lacnic-rpki.cer</a>
<a href="/ta/ripe/ripe-ncc-ta.cer.html">/ta/ripe/ripe-ncc-ta.cer</a>

<strong>Note:</strong> <i>rpki-client outputs information about errorenous objects and problems with repositories.
Any errors in the below log should be solved by CA operators!</i>

<strong># TZ=Etc/UTC rpki-client -c -j</strong>
$(cat ${LOG_RRDP})

<strong># TZ=Etc/UTC rpki-client -R -c -j</strong>
$(cat ${LOG_RSYNC})

<strong># wc -l vrps-rrdp-rsync.csv vrps-rsync-only.csv</strong>
$(wc -l vrps-rrdp-rsync.csv vrps-rsync-only.csv)

<strong># comm -3 vrps-rrdp-rsync.csv vrps-rsync-only.csv</strong>
$(comm -3 vrps-rrdp-rsync.csv vrps-rsync-only.csv)
</pre>
<br />
<i>Generated at $(date) by <a href="https://www.rpki-client.org/">rpki-client</a>$(cat footer.html).</i>
<br />
<i>Contact: job@openbsd.org</i>
EOF

# cleanup
rm -rf "${WD}"
rm "${HTMLWRITER}" "${JSONWRITER}" "${ASIDWRITER}"
doas rm -rf "${ASIDDB}"
cd -
