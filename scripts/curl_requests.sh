#!/bin/sh

echo "========= Begin $0"

requests_length=$(echo $REQUESTS_JSON | jq -r '. | length')
requests_encoded=$(echo $REQUESTS_JSON | sed -r 's/env/$/gI' | envsubst | jq -r '.[] | @base64')
CURL_OPTIONS="--write-out '%{http_code}' --silent --show-error --output /dev/null ${CURL_OPTS}"

_jq() {
    echo "${1}" | base64 -d | jq -r "${2}"
}

# this is for compact formatting
_jqc() {
    echo "${1}" | base64 -d | jq -rc "${2}"
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
        datakv_cmd="-d '${datakv_cmd}'"
    fi

    # data json block
    datajson_length=$(_jq $encoded_row 'try (.datajson | length)')
    echo "Number of datajson:$datajson_length"
    datajson_cmd=""
    if [[ "$datajson_length" != "" && "$datajson_length" != "0" ]]; then
        datajson_cmd=$(_jqc $encoded_row '.datajson')
        datajson_cmd="-d '${datajson_cmd}'"
    fi

    # basic_auth
    basic_auth_user=$(_jq $encoded_row 'try (.basic_auth .username)')
    basic_auth_curl=""
    if [[ "$basic_auth_user" != "null" && "$basic_auth_user" != ""  ]]; then
        # basic_auth_encoded=$(_jqc $encoded_row '"\(.basic_auth.username):\(.basic_auth.password)"' | base64)
        # basic_auth_header=$(printf "%s" "Authorization: Basic ${basic_auth_encoded}")
        # basic_auth_header_encoded=$(printf "%s" "Basic ${basic_auth_encoded}" | jq -sRr '@uri')
        # basic_auth_header="-H Authorization:${basic_auth_header_encoded}"
        # basic_auth_header_echo="-H Authorization: Basic ${basic_auth_user}:*************"
        
        basic_auth=$(_jqc $encoded_row '"\(.basic_auth.username):\(.basic_auth.password)"')
        basic_auth_curl=$(printf "--user %s" ${basic_auth})
    fi

    # basic_auth_cmd=""
    # basic_auth_cmd_nopwd=""
    # basic_auth_user=$(_jq $encoded_row 'try (.basic_auth .username)')
    # basic_auth_pwd=$(_jq $encoded_row 'try (.basic_auth .password)')
    # if [[ "$basic_auth_user" != "null" && "$basic_auth_user" != ""  ]]; then
    #     basic_auth_encoded=$(echo -n "$basic_auth_user:$basic_auth_pwd" | base64)
    #     basic_auth_encoded_nopwd=$(echo -n "$basic_auth_user:************" | base64)

    #     basic_auth_cmd="-H 'Authorization: Basic $(echo -n "$basic_auth_user:$basic_auth_pwd" | base64)"
    #     basic_auth_cmd_nopwd="-H 'Authorization: Basic ${basic_auth_encoded_nopwd}'"
    # fi

    echo "Executing: curl ${CURL_OPTIONS} ${basic_auth_curl} -X ${method} ${headers_cmd} ${datajson_cmd} ${datakv_cmd} \"${url}\""
    curl ${CURL_OPTIONS} ${basic_auth_curl} -X ${method} ${headers_cmd} ${datajson_cmd} ${datakv_cmd} "${url}"
}

if [ "$REQUESTS_SELECTION" == "random" ]; then
    index=`echo "$RANDOM % $requests_length + 1" | bc`
    pick=`echo $requests_encoded | cut -d" " -f $index`
    echo "Random request selection...Picked index = $index"
    _processRow $pick
elif [ "$REQUESTS_SELECTION" == "sequential" ]; then
    echo "Executing all requests in sequential order, as specified in the input REQUESTS_JSON content"
    for row in $requests_encoded; do
        _processRow $row
        if [ "x$REQUESTS_SEQUENTIAL_INTERVAL" != "x" ]; then
            echo "Sequential sleep time requested - Waiting $REQUESTS_SEQUENTIAL_INTERVAL seconds"
            sleep $REQUESTS_SEQUENTIAL_INTERVAL
        else
            echo ""
        fi
    done
else
    echo "Unsupported request selection [$REQUESTS_SELECTION]"
fi

echo ""
echo "========= End $0 - Done!!"