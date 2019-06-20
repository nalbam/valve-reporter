#!/bin/bash

OS_NAME="$(uname | awk '{print tolower($0)}')"

SHELL_DIR=$(dirname $0)

USERNAME=${CIRCLE_PROJECT_USERNAME:-opsnow-tools}
REPONAME=${CIRCLE_PROJECT_REPONAME:-valve-reporter}

################################################################################

TPUT=
command -v tput > /dev/null && TPUT=true

_echo() {
    if [ "${TPUT}" != "" ] && [ "$2" != "" ]; then
        echo -e "$(tput setaf $2)$1$(tput sgr0)"
    else
        echo -e "$1"
    fi
}

_result() {
    echo
    _echo "# $@" 4
}

_command() {
    echo
    _echo "$ $@" 3
}

_success() {
    echo
    _echo "+ $@" 2
    exit 0
}

_error() {
    echo
    _echo "- $@" 1
    exit 1
}

_replace() {
    if [ "${OS_NAME}" == "darwin" ]; then
        sed -i "" -e "$1" $2
    else
        sed -i -e "$1" $2
    fi
}

################################################################################

prepare() {
    rm -rf ${SHELL_DIR}/build
    mkdir -p ${SHELL_DIR}/build

    if [ "${OS_NAME}" == "darwin" ]; then
        PREV_MONTH=$(date -v -1m +"%Y-%m-01")
        NEXT_MONTH=$(date -v +1m +"%Y-%m-01")

        WEEK_BGN=$(date -v -6d +"%Y-%m-%d")
        WEEK_END=$(date +"%Y-%m-%d")
    else
        PREV_MONTH=$(date -d "-1 month" +%Y-%m-01)
        NEXT_MONTH=$(date -d "+1 month" +%Y-%m-01)

        WEEK_BGN=$(date -d "-6 day" +%Y-%m-%d)
        WEEK_END=$(date +%Y-%m-%d)
    fi
}

get_cost() {
    aws ce get-cost-and-usage \
        --granularity ${1} \
        --time-period Start=${2},End=${3} \
        --metrics "UnblendedCost" \
        --filter ${4} \
        | jq -r '"Start\t End\t Amount",
                (.ResultsByTime[] | "\(.TimePeriod.Start) \(.TimePeriod.End) \(.Total.UnblendedCost.Amount)")' \
        | column -t
}

get_cost_with_filter() {
    LIST=${SHELL_DIR}/build/filter
    ls ${SHELL_DIR}/config | grep json | sort > ${LIST}

    while read VAL; do
        _result "Start=${PREV_MONTH},End=${NEXT_MONTH} UnblendedCost : ${VAL}" >> cost.txt
        get_cost "MONTHLY" ${PREV_MONTH} ${NEXT_MONTH} file://${SHELL_DIR}/config/${VAL} >> cost.txt

        _result "Start=${WEEK_BGN},End=${WEEK_END} UnblendedCost : ${VAL}" >> cost.txt
        get_cost "DAILY" ${WEEK_BGN} ${WEEK_END} file://${SHELL_DIR}/config/${VAL} >> cost.txt

    done < ${LIST}
}

get_cost_with_tag() {
    while read TAG; do
        LIST=${SHELL_DIR}/build/tags-${TAG}.txt

        aws ce get-tags --time-period Start=${PREV_MONTH},End=${NEXT_MONTH} --tag-key ${TAG} | jq -r '.Tags[]' > ${LIST}

        while read VAL; do
            if [ "${VAL}" == "" ]; then
                continue
            fi

            echo "{\"Tags\":{\"Key\":\"${TAG}\",\"Values\":[\"${VAL}\"]}}" > ${SHELL_DIR}/build/filter.json

            _result "Start=${PREV_MONTH},End=${NEXT_MONTH} UnblendedCost : ${TAG}=${VAL}" >> cost.txt
            get_cost "MONTHLY" ${PREV_MONTH} ${NEXT_MONTH} file://${SHELL_DIR}/build/filter.json >> cost.txt

            _result "Start=${WEEK_BGN},End=${WEEK_END} UnblendedCost : ${TAG}=${VAL}" >> cost.txt
            get_cost "DAILY" ${WEEK_BGN} ${WEEK_END} file://${SHELL_DIR}/build/filter.json >> cost.txt

        done < ${LIST}

    done < ${SHELL_DIR}/config/tags.txt
}

prepare

rm -f cost.txt log.csv

get_cost_with_filter

get_cost_with_tag
