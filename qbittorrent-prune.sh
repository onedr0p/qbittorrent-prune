#!/bin/bash -e
# shellcheck shell=bash

# Allow this script to be run without Docker
# shellcheck disable=SC1091
test -f .env && source .env

# Set default values if not defined
DRY_RUN=${DRY_RUN:-"true"}
LOG_LEVEL=${LOG_LEVEL:-1}
QB_DELETE_FILES=${QB_DELETE_FILES:-"true"}
PUSHOVER_PRIORITY=${PUSHOVER_PRIORITY:-1}
DISABLE_SSL_VERIFY=${DISABLE_SSL_VERIFY:-"false"}

# Exit script if we don't have the necessary environment variables
if
    [[ -z "${QB_URL}" ]] ||
    [[ -z "${QB_USERNAME}" ]] ||
    [[ -z "${QB_PASSWORD}" ]];
then
    [[ ${LOG_LEVEL} -ge 1 ]] && echo "$(date -u) - ERROR: Missing environment variables, see README.md"
    exit 1
fi

# Exit script if there are not qBittorrent categories enabled
if
    [[ "${QB_CATEGORIES}" == "" ]];
then
    [[ ${LOG_LEVEL} -ge 1 ]] && echo "$(date -u) - ERROR: No categories are present, add one to enable the script"
    exit 1
fi

# Exit script if QB_CATEGORIES is not a valid comma delimited list
category_regex="([A-Za-z0-9\-_]+)(,\s*[A-Za-z0-9\-_]+)*"
if [[ ! "${QB_CATEGORIES}" =~ ${category_regex} ]]; then
    [[ ${LOG_LEVEL} -ge 1 ]] && echo "$(date -u) - ERROR: Categories is not in the right syntax"
    exit 1
fi

# Warn about dry run environment variable being set
if [ "${DRY_RUN}" == "true" ]; then
    [[ ${LOG_LEVEL} -ge 1 ]] && echo "$(date -u) - INFO: DRY_RUN set, this script will not actually delete anything from qBittorrent"
fi

# Set the curl command
CURL_CMD="curl -s"
if
    [[ "${DISABLE_SSL_VERIFY}" == "true" ]];
then
    [[ ${LOG_LEVEL} -ge 1 ]] && echo "$(date -u) - INFO: DISABLE_SSL_VERIFY set, SSL verification is disabled"
    CURL_CMD="curl -s -k"
fi

# Append the qBittorrent API path
api_url="${QB_URL}/api/v2"

# Log into qBittorrent and save the cookie in a variable
cookie=$(${CURL_CMD} --fail -i --header "Referer: ${QB_URL}" --data "username=${QB_USERNAME}&password=${QB_PASSWORD}" "${api_url}/auth/login" | grep "set-cookie: SID" | awk -F[=";"] '{print $2}')
if [[ -z "${cookie}" ]]; then
    [[ ${LOG_LEVEL} -ge 1 ]] && echo "$(date -u) - ERROR: Could not log into qBittorrent, problem with host, port or credentials?"
    exit 1
else
    [[ ${LOG_LEVEL} -ge 2 ]] && echo "$(date -u) - SUCCESS: Logged into qBittorrent, using cookie: ${cookie}"
fi

# Check the API Version
api_version=$(${CURL_CMD} --fail --cookie "SID=${cookie}" "${api_url}/app/webapiVersion")
valid_api_version_regex="^2\.."
if [[ ! "${api_version}" =~ ${valid_api_version_regex} ]]; then
    [[ ${LOG_LEVEL} -ge 1 ]] && echo "$(date -u) - ERROR: qBittorrent version '${api_version}' is not supported by this script"
    exit 1
fi

# Iterate thru each comma delimited value in QB_CATEGORIES and append torrent hash to array based on filters
torrent_hashes=()
for category in ${QB_CATEGORIES//,/ }; do
    hash=$(${CURL_CMD} --fail --cookie "SID=${cookie}" "${api_url}/torrents/info?filter=completed" | jq -r --arg CATEGORY "${category}" '.[] | select( (.category==$CATEGORY) and (.state=="stalledUP") ) | .hash')
    torrent_hashes+=(${hash[@]})
done

# Exit if no torrents are found in categories
if [ "${#torrent_hashes[@]}" -eq 0 ]; then
    [[ ${LOG_LEVEL} -ge 2 ]] && echo "$(date -u) - INFO: No torrents were found in your categories"
    exit 1
else
    [[ ${LOG_LEVEL} -ge 2 ]] && echo "$(date -u) - INFO: Found ${#torrent_hashes[@]} torrents matching your categories and in a stalledUP state"
fi

# Verify the torrent in the list defined above has an error
failed_torrent_hashes=()
for torrent_hash in "${torrent_hashes[@]}"
do
    has_error=$(${CURL_CMD} --fail --cookie "SID=${cookie}" "${api_url}/torrents/trackers?hash=${torrent_hash}" | jq -r '.[] | select(.msg | test("(not registered)|(unregistered)";"i"))')
    if [ "${has_error}" != "" ]; then
        failed_torrent_hashes+=("${torrent_hash}")
    fi
done

# # If torrents were found but the API hates us, die
if [ "${#failed_torrent_hashes[@]}" -eq 0 ]; then
    [[ ${LOG_LEVEL} -ge 2 ]] && echo "$(date -u) - INFO: No torrents matching 'registered' or 'unregistered' were found in your categories"
    exit 1
fi

# Delete the torrent
for failed_torrent_hash in "${failed_torrent_hashes[@]}"
do
    # Get the torrent name
    torrent_name=$(${CURL_CMD} --fail --cookie "SID=${cookie}" "${api_url}/torrents/files?hash=${failed_torrent_hash}" | jq -r '.[] | .name')

    # Delete the torrent
    if [ "${DRY_RUN}" == "false" ]; then
        http_response_code=$(${CURL_CMD} -X POST -o /dev/null -w "%{http_code}" --cookie "SID=${cookie}" -d "hashes=${failed_torrent_hash}&deleteFiles=${QB_DELETE_FILES}" "${api_url}/torrents/delete")
        valid_response_regex="(2|3)[0-9]{2}"
        if [[ ! "${http_response_code}" =~ ${valid_response_regex} ]]; then
            [[ ${LOG_LEVEL} -ge 1 ]] && echo "$(date -u) - ERROR: Unable to delete torrent ${torrent_name}"
            [[ ${LOG_LEVEL} -ge 1 ]] && echo "$(date -u) - ERROR: Invalid HTTP Status Code: ${http_response_code}"
        else
            [[ ${LOG_LEVEL} -ge 1 ]] && echo "$(date -u) - SUCCESS: Torrent ${torrent_name} deleted"
            
            # Send Pushover notification if enabled
            if [[ "${PUSHOVER_USER_KEY}" ]] && [[ "${PUSHOVER_TOKEN}" ]]; then
                title="Torrent deleted from qBittorrent"
                ${CURL_CMD} -X POST -d "token=${PUSHOVER_TOKEN}&user=${PUSHOVER_USER_KEY}&title=\"${title}\"&message=\"${torrent_name}\"&priority=${PUSHOVER_PRIORITY}" \
                    'https://api.pushover.net/1/messages.json'
            fi
        fi
    else
        [[ ${LOG_LEVEL} -ge 1 ]] && echo "$(date -u) - INFO: Found torrent '${torrent_name}' to delete but did not because of the DRY_RUN flag being set"
    fi
done

exit 0
