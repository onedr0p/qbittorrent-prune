#!/bin/bash -e
# shellcheck shell=bash

# Allow this script to be run without Docker
# shellcheck disable=SC1091
test -f .env && source .env

# Source this file in order for crontab to have access to global variables
# shellcheck disable=SC1091
test -f /root/app_env.sh && source /root/app_env.sh

# Set default values if not defined
DRY_RUN=${DRY_RUN:-"true"}
LOG_LEVEL=${LOG_LEVEL:-1}
QB_DELETE_FILES=${QB_DELETE_FILES:-"true"}
QB_CATEGORY_1=${QB_CATEGORY_1:-"QB_CATEGORY_1"}
QB_CATEGORY_2=${QB_CATEGORY_2:-"QB_CATEGORY_2"}
QB_CATEGORY_3=${QB_CATEGORY_3:-"QB_CATEGORY_3"}

# Exit script if currently running
# shellcheck disable=SC2006,SC2086
if pidof -o %PPID -x "`basename $0`">/dev/null; then
    [[ ${LOG_LEVEL} -ge 1 ]] && echo "$(date -u) - ERROR: Script already running"
    exit 1
fi

# Exit script if we don't have the necessary environment variables
if
    [[ -z "${QB_HOSTNAME}" ]] ||
    [[ -z "${QB_USERNAME}" ]] ||
    [[ -z "${QB_PASSWORD}" ]];
then
    [[ ${LOG_LEVEL} -ge 1 ]] && echo "$(date -u) - ERROR: Missing environment variables, see README.md"
    exit 1
fi

# Exit script if there are not qBittorrent categories enabled
if
    [[ "${QB_CATEGORY_1}" == "QB_CATEGORY_1" ]] &&
    [[ "${QB_CATEGORY_2}" == "QB_CATEGORY_2" ]] &&
    [[ "${QB_CATEGORY_3}" == "QB_CATEGORY_3" ]];
then
    [[ ${LOG_LEVEL} -ge 1 ]] && echo "$(date -u) - ERROR: All categories are disabled, set one to enable the script"
    exit 1
fi

# Warn about dry run environment variable being set
if [ "${DRY_RUN}" == "true" ]; then
    [[ ${LOG_LEVEL} -ge 1 ]] && echo "$(date -u) - INFO: DRY_RUN set, this script will not actually delete anything from qBittorrent"
fi

# Append the qBittorrent API path
API_URL="${QB_HOSTNAME}/api/v2"

# Log into qBittorrent and save the cookie in a variable
COOKIE=$(curl -s --fail -i --header "Referer: ${QB_HOSTNAME}" --data "username=${QB_USERNAME}&password=${QB_PASSWORD}" "${API_URL}/auth/login" | grep set-cookie | awk -F[=";"] '{print $2}')
if [[ -z "${COOKIE}" ]]; then
    [[ ${LOG_LEVEL} -ge 1 ]] && echo "$(date -u) - ERROR: Could not log into qBittorrent, problem with host, port or credentials?"
    exit 1
else
    [[ ${LOG_LEVEL} -ge 2 ]] && echo "$(date -u) - SUCCESS: Logged into qBittorrent, using cookie: ${COOKIE}"
fi

# Check the API Version 
API_VERSION=$(curl -s --fail --cookie "SID=${COOKIE}" "${API_URL}/app/webapiVersion")
if [[ "${API_VERSION}" =~ ^2\.. ]]; then
    [[ ${LOG_LEVEL} -ge 2 ]] && echo "$(date -u) - SUCCESS: qBittorrent version '${API_VERSION}' is supported"
else
    [[ ${LOG_LEVEL} -ge 1 ]] && echo "$(date -u) - ERROR: qBittorrent version '${API_VERSION}' is not supported by this script"
    exit 1
fi

# Get all completed torrents in stalledUP state
# TORRENT_COMPLETED_LIST=$(curl -s --fail --cookie "SID=${COOKIE}" "${API_URL}/torrents/info?filter=completed" | jq -r '.[] | select(.state=="stalledUP"'))

# Iterate thru each QB_CATEGORY_x and append torrent hash to array
# declare -a TORRENT_HASHES=()
# for CATEGORY in "${!QB_CATEGORY_@}"; do
#   CAT=${!CATEGORY}
#   TORRENT_HASHES+=($(echo $TORRENT_COMPLETED_LIST | jq -r --arg CAT "${CAT}" '.[] | select(.category==$CAT) | .hash' && printf '\0'))
# done

# Retrieve all torrents hashes for those that are complete and in our categories
# https://unix.stackexchange.com/a/314379
IFS=$'\n' read -r -d '' -a TORRENT_HASHES \
  < <(set -o pipefail; curl -s --fail --cookie "SID=${COOKIE}" "${API_URL}/torrents/info?filter=completed" | jq -r --arg QB_CATEGORY_1 "${QB_CATEGORY_1}" --arg QB_CATEGORY_2 "${QB_CATEGORY_2}" --arg QB_CATEGORY_3 "${QB_CATEGORY_3}" '.[] | select( ((.category==$QB_CATEGORY_1) or (.category==$QB_CATEGORY_2) or (.category==$QB_CATEGORY_3)) and (.state=="stalledUP") ) | .hash' && printf '\0')

# If no torrents are found, die
if [ "${#TORRENT_HASHES[@]}" -eq 0 ]; then
    [[ ${LOG_LEVEL} -ge 2 ]] && echo "$(date -u) - INFO: No torrents were found in your categories"
    exit 1
fi

# Verify the torrent in the list defined above has an error
FAILED_TORRENT_HASHES=()
for torrent_hash in "${TORRENT_HASHES[@]}"
do
    has_error=$(curl -s --fail --cookie "SID=${COOKIE}" "${API_URL}/torrents/trackers?hash=${torrent_hash}" | jq -r '.[] | select(.msg | test("(not registered)|(unregistered)";"i"))')
    if [ "${has_error}" != "" ]; then
        FAILED_TORRENT_HASHES+=("${torrent_hash}")
    fi
done

# # If torrents were found but the API hates us, die
if [ "${#FAILED_TORRENT_HASHES[@]}" -eq 0 ]; then
    [[ ${LOG_LEVEL} -ge 2 ]] && echo "$(date -u) - INFO: No torrents were found that will be pruned in your categories"
    exit 1
fi

# Delete the torrent
for failed_torrent_hash in "${FAILED_TORRENT_HASHES[@]}"
do
    # Get the torrent name
    torrent_name=$(curl -s --fail --cookie "SID=${COOKIE}" "${API_URL}/torrents/files?hash=${failed_torrent_hash}" | jq -r '.[] | .name')

    # Delete the torrent
    if [ "${DRY_RUN}" == "false" ]; then
        http_response_code=$(curl -s -o /dev/null -w "%{http_code}" --cookie "SID=${COOKIE}" "${API_URL}/torrents/delete?hashes=${failed_torrent_hash}&deleteFiles=${QB_DELETE_FILES}")
        if [ "${http_response_code}" != "200" ]; then
            [[ ${LOG_LEVEL} -ge 1 ]] && echo "$(date -u) - ERROR: Unable to delete torrent ${torrent_name}"
            [[ ${LOG_LEVEL} -ge 1 ]] && echo "$(date -u) - ERROR: Invalid HTTP Status Code: ${http_response_code}"
        else
            [[ ${LOG_LEVEL} -ge 1 ]] && echo "$(date -u) - SUCCESS: Torrent ${torrent_name} deleted"
        fi
    else
        [[ ${LOG_LEVEL} -ge 1 ]] && echo "$(date -u) - INFO: Found torrent '${torrent_name}' to delete but did not because of the DRY_RUN flag being set"
    fi
done

exit 0
