#!/bin/bash
# Create a temporary directory that works on both Linux and Darwin
SMOKE_TMP_DIR=`mktemp -d 2>/dev/null || mktemp -d -t 'mytmpdir'`
SMOKE_AFTER_RESPONSE=""

SMOKE_CURL_CODE="$SMOKE_TMP_DIR/smoke_curl_code"
SMOKE_CURL_HEADERS="$SMOKE_TMP_DIR/smoke_curl_headers"
SMOKE_CURL_BODY="$SMOKE_TMP_DIR/smoke_curl_body"
SMOKE_CURL_COOKIE_JAR="$SMOKE_TMP_DIR/smoke_curl_cookie_jar"
SMOKE_CURL_FOLLOW="--location"
SMOKE_CURL_VERBOSE="--silent"
SMOKE_CURL_CREDENTIALS=""

SMOKE_CSRF_TOKEN=""
SMOKE_CSRF_FORM_DATA="$SMOKE_TMP_DIR/smoke_csrf_form_data"

SMOKE_TESTS_FAILED=0
SMOKE_TESTS_RUN=0
SMOKE_URL_PREFIX=""
SMOKE_HEADER_HOST=""

## "Public API"

smoke_csrf() {
    SMOKE_CSRF_TOKEN="$1"
}

smoke_debug() {
    SMOKE_CURL_VERBOSE="--verbose"
}

smoke_no_debug() {
    SMOKE_CURL_VERBOSE="--silent"
}

smoke_follow() {
    SMOKE_CURL_FOLLOW="--location"
}

smoke_no_follow() {
    SMOKE_CURL_FOLLOW=""
}

smoke_credentials() {
    USERNAME="$1"
    PASSWORD="$2"

    if [[ -z "${USERNAME// /}" ]]; then
        _smoke_print_failure "Username is unset or empty"
        _smoke_cleanup
        exit 1
    fi
    SMOKE_CURL_CREDENTIALS="-u $USERNAME"
    if [[ -n "$PASSWORD" ]]; then
        SMOKE_CURL_CREDENTIALS="$SMOKE_CURL_CREDENTIALS:$PASSWORD"
    fi
}

smoke_no_credentials() {
    USERNAME=""
    PASSWORD=""
    SMOKE_CURL_CREDENTIALS=""
}

smoke_form() {
    URL="$1"
    FORMDATA="$2"

    if [[ ! -f "$FORMDATA" ]]; then
        _smoke_print_failure "No formdata file"
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

smoke_tcp_ok() {
    URL="$1 $2"
    _smoke_print_url "$URL"
    echo EOF | telnet $URL > $SMOKE_CURL_BODY
    smoke_assert_body "Connected"
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

smoke_host() {
    SMOKE_HEADER_HOST="$1"
}

## Assertions

smoke_assert_code() {
    EXPECTED="$1"
    CODE=$(smoke_response_code)

    if [[ $CODE == $EXPECTED ]]; then
        _smoke_success "$EXPECTED Response code"
    else
        _smoke_fail "$EXPECTED Response code ($CODE)"
    fi
}

smoke_assert_code_ok() {
    CODE=$(smoke_response_code)

    if [[ $CODE == 2* ]]; then
        _smoke_success "2xx Response code"
    else
        _smoke_fail "2xx Response code ($CODE)"
    fi
}

smoke_assert_no_response() {
    CODE=$(smoke_response_code)
    if [[ -z "${CODE// }" ]]; then
        _smoke_success "No response from server"
    else
        _smoke_fail "Got a response from server"
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

smoke_assert_headers() {
    STRING="$1"

    smoke_response_headers | grep --quiet "$STRING"

    if [[ $? -eq 0 ]]; then
        _smoke_success "Headers contain \"$STRING\""
    else
        _smoke_fail "Headers do not contain \"$STRING\""
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
_curl() {
  local opt=(--cookie $SMOKE_CURL_COOKIE_JAR --cookie-jar $SMOKE_CURL_COOKIE_JAR $SMOKE_CURL_FOLLOW --dump-header $SMOKE_CURL_HEADERS $SMOKE_CURL_VERBOSE $SMOKE_CURL_CREDENTIALS)
  if [[ -n "$SMOKE_HEADER_HOST" ]]; then
    opt+=(-H "Host: $SMOKE_HEADER_HOST")
  fi
  curl "${opt[@]}" "$@" > $SMOKE_CURL_BODY
}

_curl_get() {
    URL="$1"

    SMOKE_URL="$SMOKE_URL_PREFIX$URL"
    _smoke_print_url "$SMOKE_URL"

    _curl $SMOKE_URL

    grep -oE 'HTTP[^ ]+ [0-9]{3}' $SMOKE_CURL_HEADERS | tail -n1 | grep -oE '[0-9]{3}' > $SMOKE_CURL_CODE

    $SMOKE_AFTER_RESPONSE
}

_curl_post() {
    URL="$1"
    FORMDATA="$2"
    FORMDATA_FILE="@"$(_smoke_prepare_formdata $FORMDATA)

    SMOKE_URL="$SMOKE_URL_PREFIX$URL"
    _smoke_print_url "$SMOKE_URL"

    _curl --data "$FORMDATA_FILE" $SMOKE_URL

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
    echo "    [ ${green}${bold}OK${normal} ] $TEXT"
}

_smoke_print_url() {
    TEXT="$1"
    local url_to_print="> $TEXT"
    if [[ -n "${SMOKE_CURL_CREDENTIALS}" ]]; then
        url_to_print="$url_to_print (authenticate as ${USERNAME})"
    fi
    echo "$url_to_print"
}
