#!/usr/bin/perl

use strict;

my %state = (
    'aka.businesslink.gov.uk.edgekey.net.' => 'AKAMAI',
    'www.gov.uk.edgekey.net.' => 'AKAMAI',
    'redirector.www.gov.uk.edgekey.net.' => 'AKAMAI',
    'wildcard.ukwelcomes.businesslink.gov.uk.edgekey.net.' => 'AKAMAI',
    'aka.direct.gov.uk.edgekey.net.' => 'AKAMAI',
    'redirector-cdn-ssl-directgov.production.govuk.service.gov.uk.' => 'DYN',
    'redirector-cdn-ssl-businesslink.production.govuk.service.gov.uk.' => 'DYN',
    'redirector-cdn-ssl-events-businesslink.production.govuk.service.gov.uk.' => 'DYN',
    'redirector-cdn.production.govuk.service.gov.uk.' => 'DYN',
	'46.137.92.159' => 'BOUNCE'
);

my $filename = @ARGV[0] || "hosts.csv";
open(FILE, "> $filename") || die "unable to open file $!\n";
print FILE "host,ttl,state,cname\n";

while (<STDIN>) {
    if ($_ =~ /\sCNAME\s|\sA\s/) {
        my ($host, $secs, $IN, $CNAME, $cname) = split;

        my $state = $state{$cname} // "-";

        my $old = $cname;

        printf "%-55s %8s  %-8s  %-4s %64s\n", $host, ttl($secs), $state, owner($host), $old;

        print FILE "$host,$secs,$state,$old\n";
    }
}
close(FILE);

sub ttl {
    my $secs = shift;
    return int($secs / 3600) . " hours" if ($secs > 3600);
    return                 1 . " hour " if ($secs == 3600);
    return   int($secs / 60) . " mins " if ($secs > 60);
    return                 1 . " min  " if ($secs == 60);
    return             $secs . " secs ";
}

sub owner {
    my $host = shift;

    my $host_is_directgov = $host =~ /direct\.gov\.uk\.$/;
    my $host_is_businesslink = $host =~ /businesslink\.gov\.uk\.$/
          || $host eq "www.business.gov.uk."
          || $host eq "www.businesslink.co.uk."
          || $host eq "www.businesslink.org.";

    my $owner = "-";

    if ($host_is_businesslink || $host_is_directgov) {
        $owner = "GDS";
    }

    return $owner;
}
