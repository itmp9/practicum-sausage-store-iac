#!/bin/sh
set -eu

archive="terraform_${TERRAFORM_VERSION:?}_linux_amd64.zip"
checksums="terraform_${TERRAFORM_VERSION}_SHA256SUMS"
url="https://hashicorp-releases.yandexcloud.net/terraform/$TERRAFORM_VERSION"
workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT
cd "$workdir"

curl -fsSLO "$url/$archive"
curl -fsSLO "$url/$checksums"
awk -v archive="$archive" '$2 == archive { print }' "$checksums" > terraform.sha256
sha256sum -c terraform.sha256
unzip -q "$archive" terraform
install terraform /usr/local/bin/terraform
