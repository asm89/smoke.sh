#!/bin/bash
SMOKE_TMP_DIR=$(mktemp -d)

SMOKE_AFTER_RESPONSE=""

SMOKE_CURL_CODE="$SMOKE_TMP_DIR/smoke_curl_code"
SMOKE_CURL_HEADERS="$SMOKE_TMP_DIR/smoke_curl_headers"
SMOKE_CURL_BODY="$SMOKE_TMP_DIR/smoke_curl_body"
SMOKE_CURL_COOKIE_JAR="$SMOKE_TMP_DIR/smoke_curl_cookie_jar"

SMOKE_CSRF_TOKEN=""
SMOKE_CSRF_FORM_DATA="$SMOKE_TMP_DIR/smoke_csrf_form_data"

SMOKE_TESTS_FAILED=0
SMOKE_TESTS_RUN=0
SMOKE_URL_PREFIX=""

SMOKE_USER_AGENT="SmokeTestAgent1.0"
SMOKE_TIME_CONNECT=0 #Time taken by cUrl to connect to the site ( dependent on your client Server’s bandwidth and Network )
SMOKE_TIME_TTFP=0 #Time taken to receive first byte after connect ( How quick your Apache is , lower the value the better )
SMOKE_TIME_TOTAL=0 #The last data is the total time for the site to finish loading. (Largely due to your PHP/ any other server side language performance )

## "Public API"

smoke_csrf() {
    SMOKE_CSRF_TOKEN="$1"
}

smoke_form() {
    URL="$1"
    FORMDATA="$2"

    if [[ ! -f "$FORMDATA" ]]; then
        _smoke_print_fail "No formdata file"
        _smoke_cleanup
        exit 1
    fi

    _curl_post $URL $FORMDATA
}

smoke_form_ok() {
    URL="$1"
    FORMDATA="$2"

    smoke_form "$URL" "$FORMDATA"
    smoke_assert_code_ok
}

smoke_report() {
    _smoke_cleanup
    if [[ $SMOKE_TESTS_FAILED -ne 0 ]]; then
        _smoke_print_report_failure "FAIL ($SMOKE_TESTS_FAILED/$SMOKE_TESTS_RUN)"
        exit 1
    fi
    _smoke_print_report_success "OK ($SMOKE_TESTS_RUN/$SMOKE_TESTS_RUN)"
}

smoke_response_code() {
    cat $SMOKE_CURL_CODE
}

smoke_response_body() {
    cat $SMOKE_CURL_BODY
}

smoke_response_headers() {
    cat $SMOKE_CURL_HEADERS
}

smoke_url() {
    URL="$1"
    _curl_get $URL
}

smoke_url_ok() {
    URL="$1"
    smoke_url "$URL"
    smoke_assert_code_ok
}

smoke_url_prefix() {
    SMOKE_URL_PREFIX="$1"
}

## Assertions

smoke_assert_code_ok() {
    CODE=$(cat $SMOKE_CURL_CODE)

    if [[ $CODE == 2* ]]; then
        _smoke_success "2xx Response code"
    else
        _smoke_fail "2xx Response code"
    fi
}

smoke_assert_body() {
    STRING="$1"

    smoke_response_body | grep --quiet "$STRING"

    if [[ $? -eq 0 ]]; then
        _smoke_success "Body contains \"$STRING\""
    else
        _smoke_fail "Body does not contain \"$STRING\""
    fi
}

## Smoke "private" functions

_smoke_after_response() {
    $SMOKE_AFTER_RESPONSE
}

_smoke_cleanup() {
    rm -rf $SMOKE_TMP_DIR
}

_smoke_fail() {
    REASON="$1"
    (( SMOKE_TESTS_FAILED++ ))
    (( SMOKE_TESTS_RUN++ ))
    _smoke_print_failure "$REASON"
}

_smoke_prepare_formdata() {
    FORMDATA="$1"

    if [[ "" != $SMOKE_CSRF_TOKEN ]]; then
        cat $FORMDATA | sed "s/__SMOKE_CSRF_TOKEN__/$SMOKE_CSRF_TOKEN/" > $SMOKE_CSRF_FORM_DATA
        echo $SMOKE_CSRF_FORM_DATA
    else
        echo $FORMDATA
    fi
}

_smoke_success() {
    REASON="$1"
    _smoke_print_success "$REASON"
    (( SMOKE_TESTS_RUN++ ))
}

## Curl helpers
_curl_get() {
    URL="$1"

    SMOKE_URL="$SMOKE_URL_PREFIX$URL"
    _smoke_print_url "$SMOKE_URL"

    curl -w "\n%{time_connect}:%{time_starttransfer}:%{time_total}" -A $SMOKE_USER_AGENT --cookie $SMOKE_CURL_COOKIE_JAR --cookie-jar $SMOKE_CURL_COOKIE_JAR --location --dump-header $SMOKE_CURL_HEADERS --silent $SMOKE_URL > $SMOKE_CURL_BODY

    SMOKE_TIME_CONNECT=`tail -n1 $SMOKE_CURL_BODY | cut -f1 -d:`
    SMOKE_TIME_TTFP=`tail -n1 $SMOKE_CURL_BODY | cut -f2 -d:`
    SMOKE_TIME_TOTAL=`tail -n1 $SMOKE_CURL_BODY | cut -f3 -d:`

    grep -oE 'HTTP[^ ]+ [0-9]{3}' $SMOKE_CURL_HEADERS | tail -n1 | grep -oE '[0-9]{3}' > $SMOKE_CURL_CODE

    $SMOKE_AFTER_RESPONSE
}

_curl_post() {
    URL="$1"
    FORMDATA="$2"
    FORMDATA_FILE="@"$(_smoke_prepare_formdata $FORMDATA)

    SMOKE_URL="$SMOKE_URL_PREFIX$URL"
    _smoke_print_url "$SMOKE_URL"

    curl -w "\n%{time_connect}:%{time_starttransfer}:%{time_total}" -A $SMOKE_USER_AGENT --cookie $SMOKE_CURL_COOKIE_JAR --cookie-jar $SMOKE_CURL_COOKIE_JAR --location --data "$FORMDATA_FILE" --dump-header $SMOKE_CURL_HEADERS --silent $SMOKE_URL > $SMOKE_CURL_BODY

    SMOKE_TIME_CONNECT=`tail -n1 $SMOKE_CURL_BODY | cut -f1 -d:`
    SMOKE_TIME_TTFP=`tail -n1 $SMOKE_CURL_BODY | cut -f2 -d:`
    SMOKE_TIME_TOTAL=`tail -n1 $SMOKE_CURL_BODY | cut -f3 -d:`

    grep -oE 'HTTP[^ ]+ [0-9]{3}' $SMOKE_CURL_HEADERS | tail -n1 | grep -oE '[0-9]{3}' > $SMOKE_CURL_CODE

    $SMOKE_AFTER_RESPONSE
}

## Print helpers

# test for color support, inspired by:
# http://unix.stackexchange.com/questions/9957/how-to-check-if-bash-can-print-colors
if [ -t 1 ]; then
    ncolors=$(tput colors)
    if test -n "$ncolors" && test $ncolors -ge 8; then
        bold="$(tput bold)"
        normal="$(tput sgr0)"
        red="$(tput setaf 1)"
        redbg="$(tput setab 1)"
        green="$(tput setaf 2)"
        greenbg="$(tput setab 2)"
    fi
fi

_smoke_print_failure() {
    TEXT="$1"
    echo "    [${red}${bold}FAIL${normal}] $TEXT"
}

_smoke_print_report_failure() {
    TEXT="$1"
    echo -e "${redbg}$TEXT${normal}"
}
_smoke_print_report_success() {
    TEXT="$1"
    echo -e "${greenbg}$TEXT${normal}"
}

_smoke_print_success() {
    TEXT="$1"
    echo "    [ ${green}${bold}OK${normal} ] [$SMOKE_TIME_CONNECT] [$SMOKE_TIME_TTFP] [$SMOKE_TIME_TOTAL] $TEXT "
}

_smoke_print_url() {
    TEXT="$1"
    echo "> $TEXT"
}
