#!/bin/sh
set -eu

export TF_HTTP_ADDRESS="${CI_API_V4_URL:?}/projects/${CI_PROJECT_ID:?}/terraform/state/${TF_STATE_NAME:?}"
export TF_HTTP_LOCK_ADDRESS="$TF_HTTP_ADDRESS/lock"
export TF_HTTP_UNLOCK_ADDRESS="$TF_HTTP_LOCK_ADDRESS"
export TF_HTTP_LOCK_METHOD=POST
export TF_HTTP_UNLOCK_METHOD=DELETE
export TF_HTTP_RETRY_WAIT_MIN=5
export TF_HTTP_USERNAME="gitlab-ci-token"
export TF_HTTP_PASSWORD="${CI_JOB_TOKEN:?}"
export TF_CLI_CONFIG_FILE="${CI_PROJECT_DIR:?}/ci/terraform.rc"
