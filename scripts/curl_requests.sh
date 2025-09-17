#!/bin/sh

echo "========= Begin $0"

requests_length=$(echo $REQUESTS_JSON | jq -r '. | length')
requests_encoded=$(echo $REQUESTS_JSON | sed -r 's/env/$/gI' | envsubst | jq -r '.[] | @base64')
CURL_OPTIONS="--write-out '%{http_code}' --silent --show-error --output /dev/null ${CURL_OPTS}"

_jq() {
    echo "${1}" | base64 -d | jq -r "${2}"
}

_processRow(){
    local encoded_row=$1

    method=$(_jq $encoded_row '.method')
    url=$(_jq $encoded_row '.url')
    
    # headers
    headers_length=$(_jq $encoded_row 'try (.headers | length)')
    echo "Number of headers:$headers_length"
    headers_cmd=""
    if [[ "$headers_length" != "" && "$headers_length" != "0" ]]; then
        headers_cmd=$(_jq $encoded_row '.headers | to_entries | map("-H \(.key):\(.value|tostring)") | join(" ")')
    fi
    
    # data key value pairs
    datakv_length=$(_jq $encoded_row 'try (.datakv | length)')
    echo "Number of datakv:$datakv_length"
    datakv_cmd=""
    if [[ "$datakv_length" != "" && "$datakv_length" != "0" ]]; then
        datakv_cmd=$(_jq $encoded_row '.datakv | to_entries | map("\(.key)=\(.value|tostring)") | join("&")')
        datakv_cmd="-d ${datakv_cmd}"
    fi

    # basic_auth
    basic_auth_cmd=""
    basic_auth_cmd_nopwd=""
    basic_auth_user=$(_jq $encoded_row 'try (.basic_auth .username)')
    basic_auth_pwd=$(_jq $encoded_row 'try (.basic_auth .password)')
    if [[ "$basic_auth_user" != "null" && "$basic_auth_user" != ""  ]]; then
        basic_auth_cmd="-u $basic_auth_user:$basic_auth_pwd"
        basic_auth_cmd_nopwd="-u $basic_auth_user:************"
    fi

    echo "Executing: curl ${CURL_OPTIONS} -X ${method} ${basic_auth_cmd_nopwd} ${headers_cmd} \"${url}\""
    curl ${CURL_OPTIONS} -X ${method} ${basic_auth_cmd} ${headers_cmd} ${datakv_cmd} "${url}"
}

if [ "$REQUESTS_SELECTION" == "random" ]; then
    index=`echo "$RANDOM % $requests_length + 1" | bc`
    pick=`echo $requests_encoded | cut -d" " -f $index`
    echo "Random request selection...Picked index = $index"
    _processRow $pick
elif [ "$REQUESTS_SELECTION" == "all" ]; then
    echo "Executing all requests in sequential order, as specified in the input REQUESTS_JSON content"
    for row in $requests_encoded; do
        _processRow $row
        if [ "x$REQUESTS_INTERVAL" != "x" ]; then
            sleep $REQUESTS_INTERVAL
        fi
    done
else
    echo "Unsupported request selection [$REQUESTS_SELECTION]"
fi

echo ""
echo "========= End $0 - Done!!"