#!/usr/bin/env bash
#
# Copy Jekyll site to S3 bucket
#
####################################
#
# Custom vars
#
profile="blog"
s3_bucket="s3://blog.khd.me"
distribution_id="E2QWAENKO4QYUJ"
destination="_site_production"
####################################

set -e # halt script on error
set -v # echo on

tempfile=$(mktemp)

echo "Building site..."
JEKYLL_ENV=production bundle exec jekyll build --destination=$destination

echo "Removing .html extension"
find $destination/ -type f ! -iname 'index.html' -iname '*.html' -print0 | while read -d $'\0' f; do mv "$f" "${f%.html}"; done

echo "Copying files to server..."
aws s3 sync $destination/ $s3_bucket --size-only --exclude "*" --include "*.*" --delete --profile $profile  | tee -a $tempfile
echo "Copying files with content type..."
aws s3 sync $destination/ $s3_bucket --size-only --content-type text/html --exclude "*.*" --delete --profile $profile | tee -a $tempfile
#invalidate only modified files
grep "upload\|deleted" $tempfile | sed -e "s|.*upload.*to $s3_bucket|/|" | sed -e "s|.*delete: $s3_bucket|/|" | sed -e 's/index.html//' | sed -e 's/\(.*\).html/\1/' | tr '\n' ' ' | xargs aws cloudfront create-invalidation --distribution-id $distribution_id --paths --profile $profile
