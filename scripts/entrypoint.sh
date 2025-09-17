#!/bin/sh

#get request json input
if [ "x$REQUESTS_JSON_FILE" != "x" ]; then
    if [ ! -f $REQUESTS_JSON_FILE ]; then
        echo "File $REQUESTS_JSON_FILE cannot be found...fatal!"
        exit 2;
    fi
    REQUESTS_JSON=$(cat $REQUESTS_JSON_FILE)
fi

if [ "x$REQUESTS_JSON" == "x" ]; then
    echo "REQUESTS_JSON env is not set...fatal!"
    exit 2;
fi

# check that REQUESTS_JSON has valid json
echo "$REQUESTS_JSON" | jq empty
isvalidreturn="$?"
if [ $isvalidreturn -gt 0 ]; then
    echo "REQUESTS_JSON array is not valid...nothing to do."
    exit $isvalidreturn;
fi

# make sure array is not empty
requests_length=$(echo "$REQUESTS_JSON" | jq -r '. | length')
if [ "$requests_length" == "0" ]; then
    echo "REQUESTS_JSON array is empty...nothing to do."
    exit 2;
fi

echo "REQUESTS_JSON array contains $requests_length elements! Ready to curl!"
if [ "x$REQUESTS_INTERVAL" != "x" ]; then
    echo "Continuous loop requested, with REQUESTS_INTERVAL=$REQUESTS_INTERVAL seconds in between each curl loop."
    while true; do ./curl_requests.sh; sleep $REQUESTS_INTERVAL; done
else
    ./curl_requests.sh
fi