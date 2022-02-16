#!/bin/bash
#
# This script must fetch and compare the public keys returned from the web3signer api
# with the public keys in the public_keys.txt file used to start the validator
# if the public keys are different, the script will kill the process 1 to restart the process
# if the public keys are the same, the script will do nothing

ERROR="[ ERROR-cronjob ]"
WARN="[ WARN-cronjob ]"
INFO="[ INFO-cronjob ]"
DEBUG="[ DEBUG-cronjob ]"

# This var must be set here and must be equal to the var defined in the compose file
PUBLIC_KEYS_FILE="/opt/teku/public-keys/public_keys.txt"
HTTP_WEB3SIGNER="http://web3signer.web3signer-prater.dappnode:9000"

# Get public keys in format: string[]
function get_public_keys() {
    if PUBLIC_KEYS=$(curl -s -X GET \
    -H "Content-Type: application/json" \
    --max-time 10 \
    --retry 5 \
    --retry-delay 2 \
    --retry-max-time 40 \
    "${HTTP_WEB3SIGNER}/eth/v1/keystores"); then
        if PUBLIC_KEYS_PARSED=$(echo ${PUBLIC_KEYS} | jq -r '.data[].validating_pubkey'); then
            if [ ! -z "$PUBLIC_KEYS_PARSED" ]; then
                echo "${INFO} found public keys: $PUBLIC_KEYS_PARSED"
            else
                echo "${WARN} no public keys found"
            fi
        else
            { echo "${ERROR} something wrong happened parsing the public keys"; exit 1; }
        fi
    else
        { echo "${ERROR} web3signer not available"; exit 1; }
    fi
}

# Reads public keys from file by new line separated and converts to string array
function read_public_keys() {
    if [ -f ${PUBLIC_KEYS_FILE} ]; then
        echo "${INFO} reading public keys from file"
        PUBLIC_KEYS_OLD=$(cat ${PUBLIC_KEYS_FILE} | tr '\n' ' ')
    else
        { echo "${WARN} file ${PUBLIC_KEYS_FILE} not found"; exit 1; }
    fi
}

# Compares the public keys from the file with the public keys from the api
#   - kill main process if public keys from web3signer api does not contain the public keys from the file
#   - kill main process if public keys from file does not contain the public keys from the web3signer api
#   - kill main process if bash array length different
function compare_public_keys() { 
    echo "${DEBUG} comparing public keys"
    echo "${DEBUG} public keys from file: $PUBLIC_KEYS_OLD"
    echo "${DEBUG} public keys from api: $PUBLIC_KEYS_PARSED"

    # Check if  PUBLIC_KEYS_OLD or PUBLIC_KEYS_PARSED are empty
    if [ -z "$PUBLIC_KEYS_OLD" ] && [ ! -z "$PUBLIC_KEYS_PARSED" ]; then
        echo "${WARN} public keys from file and api are different. Killing process to restart"
        kill 1
        exit 0
    fi
    if [ ! -z "$PUBLIC_KEYS_OLD" ] && [ -z "$PUBLIC_KEYS_PARSED" ]; then
        echo "${WARN} public keys from file and api are different. Killing process to restart"
        kill 1
        exit 0
    fi

    # check public key from file exists in public keys from api
    if [ ! -z "$PUBLIC_KEYS_OLD" ]; then
        for PUBLIC_KEY_OLD in ${PUBLIC_KEYS_OLD[@]}; do
            if [[ ! "${PUBLIC_KEYS_PARSED[*]}" =~ "${PUBLIC_KEY_OLD}" ]]; then
                echo "${WARN} public keys from file and api are different. Killing process to restart"
                kill 1
                exit 0
            else
                echo "${INFO} public key ${PUBLIC_KEY_OLD} exists in api"
            fi
        done
    fi

    # check public key parsed exists in file
    if [ ! -z "$PUBLIC_KEYS_PARSED" ]; then
        for PUBLIC_KEY_PARSED in ${PUBLIC_KEYS_PARSED[@]}; do
            if [[ ! "${PUBLIC_KEYS_OLD[*]}" =~ "${PUBLIC_KEY_PARSED}" ]]; then
                echo "${WARN} public keys from file and api are different. Killing process to restart"
                kill 1
                exit 0
            else
                echo "${INFO} public key ${PUBLIC_KEY_PARSED} exists in file"
            fi
        done
    fi

    # compare array lentghs
    if [ ${#PUBLIC_KEYS_OLD[@]} -ne ${#PUBLIC_KEYS_PARSED[@]} ]; then
        echo "${WARN} public keys from file and api are different. Killing process to restart"
        kill 1
        exit 0
    else
        echo "${INFO} same number of public keys"
    fi
}

########
# MAIN #
########

echo "${INFO} starting cronjob"
get_public_keys
read_public_keys
compare_public_keys
echo "${INFO} finished cronjob"
exit 0