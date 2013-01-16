#!/bin/bash

set -e
mkdir -p dist

echo "Running unit tests..."
prove -lj4 tests/unit/logic/*.t

echo "Copying configuration to dist directory..."
rm -rf dist/*
rsync -a redirector/. dist/.

while IFS=, read site redirected generate_mappings rest
do 
    #baby steps - these are still in BL data
    [ $site = 'elearning' ] && continue
    [ $site = 'ukwelcomes' ] && continue
    [ $site = 'improve' ] && continue
    cp data/mappings/${site}.csv dist/${site}_mappings_source.csv
    if [ $redirected == N ]; then
        echo "Testing sources are valid for in progress site $site..."
        prove -l tests/unit/sources/${site}_valid_lines.t
    fi
    if [ $generate_mappings == Y ]; then
        echo "Creating mappings from $site source..."
        perl -Ilib create_mappings.pl dist/${site}_mappings_source.csv
    fi
done < sites.csv

echo "Creating 410 pages..."
(
    while IFS=, read site redirected generate_mappings old_homepage rest
    do
        if [ $generate_mappings == Y ]; then
            if [ ! -f dist/${old_homepage}.location_suggested_links.conf -a ! -f dist/${old_homepage}.location_suggested_links.conf ]; then
                touch dist/${old_homepage}.no_suggested_links.conf
            fi
            if [ ! -f dist/${old_homepage}.archive_links.conf ]; then
                touch dist/${old_homepage}.archive_links.conf
            fi
            cat \
                redirector/410_preamble.php \
                dist/${old_homepage}.*suggested_links*.conf \
                dist/${old_homepage}.archive_links.conf \
                redirector/410_header.php \
                redirector/static/${site}/410.html \
                    > dist/static/${site}/410.php
            cp redirector/410_suggested_links.php dist/static/${site}    
        fi
    done
) < sites.csv

echo "Generating sitemaps..."
perl tools/sitemap.pl dist/directgov_mappings_source.csv 'www.direct.gov.uk' > dist/static/directgov/sitemap.xml
prove bin/test_sitemap.pl :: dist/static/directgov/sitemap.xml www.direct.gov.uk
perl tools/sitemap.pl dist/businesslink_mappings_source.csv 'www.businesslink.gov.uk' 'online.businesslink.gov.uk' > dist/static/businesslink/sitemap.xml
prove bin/test_sitemap.pl :: dist/static/businesslink/sitemap.xml www.businesslink.gov.uk online.businesslink.gov.uk
while IFS=, read site rest
do 
    [ $site = 'directgov' ] && continue
    [ $site = 'businesslink' ] && continue
    [ $site = 'businesslink_piplinks' ] && continue
    [ $site = 'elearning' ] && continue
    [ $site = 'ukwelcomes' ] && continue
    [ $site = 'improve' ] && continue   
    domain=`case "$site" in
    mod) echo "www.mod.uk" ;;
    *) echo "www.${site}.gov.uk" ;;
    esac`

    perl tools/sitemap.pl dist/${site}_mappings_source.csv $domain > dist/static/${site}/sitemap.xml
    prove bin/test_sitemap.pl :: dist/static/${site}/sitemap.xml $domain
done < sites.csv

echo "Redirector build succeeded."
