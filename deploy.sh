#!/bin/bash
set -eux

repo=getsentry/jekyll-base
version=$(date +%Y.%m.%d)
rev=$(git rev-parse --short HEAD)

for variant in builder runtime; do
  docker build --pull --rm \
    -t $repo:$variant-latest \
    -t $repo:$variant-$version \
    -t $repo:$variant-$rev \
    -f $variant.dockerfile \
    .
  docker push $repo:$variant-latest
  docker push $repo:$variant-$version
  docker push $repo:$variant-$rev
done

cat <<EOF
FROM $repo:builder-$version AS builder
FROM $repo:runtime-$version AS runtime
EOF
