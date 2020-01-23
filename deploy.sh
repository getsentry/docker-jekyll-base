#!/bin/bash
set -eux

repo=getsentry/jekyll-base
version=$(date +%Y.%m.%d)

for variant in builder runtime; do
  docker build --pull --rm \
    -t $repo:$variant \
    -t $repo:$variant-latest \
    -t $repo:$variant-$version \
    -f $variant.dockerfile \
    .
  docker push $repo:$variant
  docker push $repo:$variant-latest
  docker push $repo:$variant-$version
done

cat <<EOF
ARG VERSION=$version
FROM getsentry/jekyll-base:builder-\${VERSION} AS builder
FROM getsentry/jekyll-base:runtime-\${VERSION} AS runtime
EOF
