#!/bin/sh
set -eu

case "${NEXUS_HELM_URL:?}" in
  https://nexus.infra.students-projects.ru/repository/*|https://nexus.praktikum-services.tech/repository/*) ;;
  *) echo "Expected an HTTPS course Nexus Helm repository" >&2; exit 1 ;;
esac
nexus_url="${NEXUS_HELM_URL%/}/"
test -n "${NEXUS_USER:?}" && test -n "${NEXUS_PASSWORD:?}"
mkdir -p dist
helm lint --strict sausage-store-chart
helm package sausage-store-chart --version "${CHART_VERSION:?}" --app-version "${CI_COMMIT_SHA:?}" --destination dist
archive="dist/sausage-store-${CHART_VERSION}.tgz"

curl --fail --silent --show-error --user "$NEXUS_USER:$NEXUS_PASSWORD" --upload-file "$archive" "$nexus_url"
helm pull sausage-store --repo "$nexus_url" --version "$CHART_VERSION" --username "$NEXUS_USER" --password "$NEXUS_PASSWORD" --destination /tmp
cmp "$archive" "/tmp/sausage-store-${CHART_VERSION}.tgz"
