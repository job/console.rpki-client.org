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
#
# Use the filesystem as database to map asID's to ROA filenames

set -e

cd ${ASID_DB}

ROA_INFO=$(test-roa -v ${RSYNC_CACHE}/$1)

HASH=$(echo "${ROA_INFO}" | sha256 -q)

ASID=$(echo "${ROA_INFO}" | awk '/^asID: / { print $2 }' | sed 's/^\([0-9]\)\([0-9]\)\(.*\)/\1\/\2\/\1\2\3/')

mkdir -p ${ASID}
echo "File: $1" > ${ASID}/${HASH}
echo "${ROA_INFO}" >> ${ASID}/${HASH}
