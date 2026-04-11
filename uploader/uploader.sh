#!/bin/bash

push_to_server() {
    RESOURCE_TYPE=$(jq -r '.resourceType // empty' "$@")

    if [ -z "$RESOURCE_TYPE" ]; then
        echo "Skipping file (no resourceType): $@"
        return
    fi

    if [ "$RESOURCE_TYPE" = "Bundle" ]; then
        ENDPOINT_URL="$SERVER_URL"
    else
        ENDPOINT_URL="$SERVER_URL/$RESOURCE_TYPE"
    fi

    echo
    echo "Resource File: $@"
    echo "Endpoint: $ENDPOINT_URL"

    curl --write-out "%{http_code}\n" \
      -X POST "$ENDPOINT_URL" \
      -H "Authorization: Bearer $ACCESS_TOKEN" \
      -H "Content-Type: application/fhir+json" \
      -d @"$@" --silent >> output.txt
}


main() {
    # Import configs
    . config.txt

    # Get access_token
    RESPONSE=$(curl -s -X POST \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=$CLIENT_ID" \
  -d "client_secret=$CLIENT_SECRET" \
  "$ACCESS_TOKEN_URL")

    if echo "$RESPONSE" | jq -e 'has("error")' >/dev/null; then
        echo "Error: Failed to obtain an access token."
        echo "Response: $RESPONSE"
        exit 1
    fi

    # Parse the response to extract the access token
    ACCESS_TOKEN=$(jq -r '.access_token' <<< $RESPONSE) 
    export ACCESS_TOKEN
    export SERVER_URL
    # Get the files in the resource folder and push to server
    find $RESOURCE_FOLDER -type f -exec bash -c 'push_to_server "$@"' bash {} \;
}

export -f push_to_server
main