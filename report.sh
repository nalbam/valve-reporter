#!/bin/bash

SHELL_DIR=$(dirname $0)

USERNAME=${CIRCLE_PROJECT_USERNAME:-nalbam}
REPONAME=${CIRCLE_PROJECT_REPONAME:-valve-reporter}

rm -rf target
mkdir -p ${SHELL_DIR}/target
