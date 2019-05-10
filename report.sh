#!/bin/bash

OS_NAME="$(uname | awk '{print tolower($0)}')"

SHELL_DIR=$(dirname $0)

USERNAME=${CIRCLE_PROJECT_USERNAME:-opsnow-tools}
REPONAME=${CIRCLE_PROJECT_REPONAME:-valve-reporter}

prepare() {
    rm -rf ${SHELL_DIR}/build
    mkdir -p ${SHELL_DIR}/build

    if [ "${OS_NAME}" == "darwin" ]; then
        PREV_MONTH=$(date -v -1m +"%Y-%m-01")
        NEXT_MONTH=$(date -v +1m +"%Y-%m-01")

        WEEK_BGN=$(date -v -6d +"%Y-%m-%d")
        WEEK_END=$(date +"%Y-%m-%d")
    else
        PREV_MONTH=$(date -d "11 month" +%Y-%m-01)
        NEXT_MONTH=$(date -d "+1 month" +%Y-%m-01)

        WEEK_BGN=$(date -d "-6 day" +%Y-%m-%d)
        WEEK_END=$(date +%Y-%m-%d)
    fi
}

get_cost_with_filter() {
    LIST=${SHELL_DIR}/build/filter
    ls ${SHELL_DIR}/config | grep json | sort > ${LIST}

    while read VAL; do
        echo "Start=${PREV_MONTH},End=${NEXT_MONTH} UnblendedCost : ${VAL}"
        aws ce get-cost-and-usage \
            --time-period Start=${PREV_MONTH},End=${NEXT_MONTH} \
            --granularity MONTHLY \
            --metrics "UnblendedCost" \
            --filter file://${SHELL_DIR}/config/${VAL} \
            | jq '.ResultsByTime[] | {Start:.TimePeriod.Start,End:.TimePeriod.End,Amount:.Total.UnblendedCost.Amount}'

        echo "Start=${WEEK_BGN},End=${WEEK_END} UnblendedCost : ${VAL}"
        aws ce get-cost-and-usage \
            --time-period Start=${WEEK_BGN},End=${WEEK_END} \
            --granularity DAILY \
            --metrics "UnblendedCost" \
            --filter file://${SHELL_DIR}/config/${VAL} \
            | jq '.ResultsByTime[] | {Start:.TimePeriod.Start,End:.TimePeriod.End,Amount:.Total.UnblendedCost.Amount}'

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

            echo "Start=${PREV_MONTH},End=${NEXT_MONTH} UnblendedCost : ${TAG}=${VAL}"
            aws ce get-cost-and-usage \
                --time-period Start=${PREV_MONTH},End=${NEXT_MONTH} \
                --granularity MONTHLY \
                --metrics "UnblendedCost" \
                --filter file://${SHELL_DIR}/build/filter.json \
                | jq '.ResultsByTime[] | {Start:.TimePeriod.Start,End:.TimePeriod.End,Amount:.Total.UnblendedCost.Amount}'

            echo "Start=${WEEK_BGN},End=${WEEK_END} UnblendedCost : ${TAG}=${VAL}"
            aws ce get-cost-and-usage \
                --time-period Start=${WEEK_BGN},End=${WEEK_END} \
                --granularity DAILY \
                --metrics "UnblendedCost" \
                --filter file://${SHELL_DIR}/build/filter.json \
                | jq '.ResultsByTime[] | {Start:.TimePeriod.Start,End:.TimePeriod.End,Amount:.Total.UnblendedCost.Amount}'

        done < ${LIST}

    done < ${SHELL_DIR}/config/tags.txt
}

prepare

get_cost_with_filter

get_cost_with_tag
