#!/usr/bin/env bash
set -e
#=======================================
# Functions
#=======================================
RESTORE='\033[0m'
RED='\033[00;31m'
YELLOW='\033[00;33m'
BLUE='\033[00;34m'
GREEN='\033[00;32m'

function color_echo {
    color=$1
    msg=$2
    echo -e "${color}${msg}${RESTORE}"
}

function echo_fail {
    msg=$1
    echo
    color_echo "${RED}" "${msg}"
    exit 1
}

function echo_warn {
    msg=$1
    color_echo "${YELLOW}" "${msg}"
}

function echo_info {
    msg=$1
    echo
    color_echo "${BLUE}" "${msg}"
}

function echo_details {
    msg=$1
    echo "  ${msg}"
}

function echo_done {
    msg=$1
    color_echo "${GREEN}" "  ${msg}"
}


#=======================================
# Main
#=======================================

if [ -z "$binary_path" ]; then
	echo "binary path is needed"
	exit 1
fi

if [ -z "$project_id" ]; then 
	echo "project id is needed"
	exit 1
fi

if [ -z "$access_key" ]; then
	echo "apptest ai access key is needed"
	exit 1
fi

if [ -z "$waiting_for_test_results" ]; then
	waiting_for_test_results=true
fi

serviceHost=https://api.apptest.ai

# store the whole response with the status at the and
apk_file_d='apk_file=@'\"${binary_path}\" 
data_d='data={"pid":'${project_id}',"test_set_name":"Bitrise_Test"}'
testRunUrl=${serviceHost}/test_set/queuing?access_key=${access_key}

echo ${apk_file_d}
echo ${testRunUrl}
echo ${data_d}
HTTP_RESPONSE=$(curl --write-out "HTTPSTATUS:%{http_code}" -X POST -F $apk_file_d -F $data_d ${testRunUrl})

# extract the body
HTTP_BODY=$(echo ${HTTP_RESPONSE} | sed -e 's/HTTPSTATUS\:.*//g')

# extract the status
HTTP_STATUS=$(echo ${HTTP_RESPONSE} | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')

# HTTP Status Check
if [ ! ${HTTP_STATUS} -eq 200  ]; then
  echo_fail "Error [HTTP status: ${HTTP_STATUS}]"
fi

# apptest.ai Test Run Result Check
create_test_result=$(echo $HTTP_BODY | jq -r .result)
if [ $create_test_result == 'fail' ]; then
  echo_fail "apptest.ai Test Run Fail : $(echo $HTTP_BODY | jq -r .reason)"
fi


#=============================================
# Test Complete Check by polling
#=============================================

TEST_RUN_RESULT='false'

# Get tsid from Test Run api's HTTP_BODY
tsid=$(echo $HTTP_BODY | jq -r .data.tsid)
echo 'Your test request is accepted - Test Run id : '$tsid

# Get the Test Result Data
# Refer to 1. API Spec
testCompleteCheckUrl=${serviceHost}/test_set/${tsid}/ci_info?access_key=${access_key}

while [ ! "$TEST_RUN_RESULT" == "true" ] && [ "$waiting_for_test_results" == "true" ]; do
    HTTP_RESPONSE=$(curl --silent --write-out "HTTPSTATUS:%{http_code}" ${testCompleteCheckUrl})

    # extract the body
    HTTP_BODY=$(echo ${HTTP_RESPONSE} | sed -e 's/HTTPSTATUS\:.*//g')

    # extract the status
    HTTP_STATUS=$(echo ${HTTP_RESPONSE} | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')

    # print the body
    # echo "HTTP BODY : {$HTTP_BODY}"

    # HTTP Status Check
    if [ ! ${HTTP_STATUS} -eq 200  ]; then
      echo_fail "Error [HTTP status: ${HTTP_STATUS}]"
    fi

    TEST_RUN_RESULT=$(echo $HTTP_BODY | jq -r .complete)

    if [ "$TEST_RUN_RESULT" == "true" ]; then
        RESULT_DATA=$(echo $HTTP_BODY | jq -r .data)
        break
    fi
   
    echo_details "Waiting for Test Run(${tsid}) completed"
    sleep 20s
done

if [ "$waiting_for_test_results" == "true" ]; then 
	echo '========================================='
	echo $(echo $RESULT_DATA | jq -r .result_json)
	TMP_DIR=$(mktemp -d)
	touch ${TMP_DIR}/apptest_results.json
	echo $(echo $RESULT_DATA | jq -r .result_json > ${TMP_DIR}/apptest_results.json)
	APPTEST_AI_TEST_RESULT=TMP_DIR/apptest_results.json
	echo_details 'Test completed and saved ${APPTEST_AI_TEST_RESULT}'
fi
