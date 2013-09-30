#!/bin/sh

tmpdir=tmp/dns_report
mkdir -p $tmpdir
[ -z "$DNS_SERVER" ] && DNS_SERVER=8.8.8.8

tools/site_hosts.sh |
    while read host
    do
        dig @$DNS_SERVER +trace $host > $tmpdir/$host.txt
    done

cat $tmpdir/*.txt | tools/dns_report.pl $tmpdir/hosts.csv

grep $tmpdir/hosts.csv -e "^.*AKAMAI.*$" > $tmpdir/still_to_migrate_to_fastly_cdn.csv
