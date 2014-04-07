smoke.sh
========

A minimal smoke testing framework in Bash.

Features:

- Response body checks
- Response code checks
- GET/POST on endpoints
- CSRF tokens
- Reporting and sane exit codes

![smoke sh](https://f.cloud.github.com/assets/657357/1238166/6f47f56a-29e4-11e3-9e19-394ca12b5fd0.png)

Example
-------

Checking if the Google Search home page works and contains the word "search":

```bash
#!/bin/bash

. smoke.sh

smoke_url_ok "http://google.com/"
    smoke_assert_body "search"
smoke_report
```

Running:

```bash
$ ./smoke-google
> http://google.com/
    [ OK ] 2xx Response code
    [ OK ] Body contains "search"
OK (2/2)
```

For a more advanced and complete example, see below.

Setup and usage
--------------

The recommended setup includes copying the `smoke.sh` file in the appropriate
place and creating a new file in the same directory that you will write your
tests in.

```bash
 $ tree -n
 .
 ├── smoke-google
 └── smoke.sh

```

In your file containing the tests, start with sourcing the `smoke.sh` file and
end with calling `smoke_report` if you want a final report + appropriate exit
code.

```bash
#!/bin/bash

. smoke.sh

# your test assertions go here

smoke_report
```

### GET a URL and check the response code

The minimal smoke test will check if a URL returns with a 200 response code:

```bash
smoke_url_ok "http://google.com"
```

### POST a URL and check the response code

A more advanced smoke test will POST data to a URL. Such a test can be used to
for example check if the login form is functional:

```bash
smoke_form_ok "http://example.org/login" path/to/postdata
```

And the POST data (`path/to/postdata`):
```
username=smoke&password=test
```

### Checking if the response body contains a certain string

By checking if the response body contains certain strings you can rule out that
your server is serving a `200 OK`, which seems fine, while it is actually
serving the apache default page:

```bash
smoke_assert_body "Password *"
```

### Configuring a base URL

It is possible to setup a base URL that is prepended for each URL that is
requested.

```bash
smoke_url_prefix "http://example.org"
smoke_url_ok "/"
smoke_url_ok "/login"
```

### CSRF tokens

Web applications that are protected with CSRF tokens will need to extract a
CSRF token from the responses. The CSRF token will then be used in each POST
request issued by `smoke.sh`.

Setup an after response callback to extract the token and set it. Example:

```bash
#!/bin/bash

. smoke.sh

_extract_csrf() {
    CSRF=$(smoke_response_body | grep OUR_CSRF_TOKEN | grep -oE "[a-f0-9]{40}")

    if [[ $CSRF != "" ]]; then
        smoke_csrf "$CSRF" # set the new CSRF token
    fi
}

SMOKE_AFTER_RESPONSE="_extract_csrf"
```

When the CSRF token is set, `smoke.sh` will replace the string
`__SMOKE_CSRF_TOKEN__` in your post data with the given token:

```
username=smoke&password=test&csrf=__SMOKE_CSRF_TOKEN__
```

To get data from the last response, three helper functions are available:

```bash
smoke_response_code    # e.g. 200, 201, 400...
smoke_response_body    # raw body (html/json/...)
smoke_response_headers # list of headers
```

Advanced example
----------------

More advanced example showing all features of `smoke.sh`:

```bash
#!/bin/bash

BASE_URL="$1"

if [[ -z "$1" ]]; then
    echo "Usage:" $(basename $0) "<base_url>"
    exit 1
fi

. smoke.sh

_extract_csrf() {
    CSRF=$(smoke_response_body | grep OUR_CSRF_TOKEN | grep -oE "[a-f0-9]{40}")

    if [[ $CSRF != "" ]]; then
        smoke_csrf "$CSRF" # set the new CSRF token
    fi
}

SMOKE_AFTER_RESPONSE="_extract_csrf"

smoke_url_prefix "$BASE_URL"

smoke_url_ok "/"
    smoke_assert_body "Welcome"
    smoke_assert_body "Login"
    smoke_assert_body "Password"
smoke_form_ok "/login" postdata/login
    smoke_assert_body "Hi John Doe"
smoke_report
```

API
---

| function                        | description                                          |
|---------------------------------|------------------------------------------------------|
|`smoke_assert_body <string>`     | assert that the body contains `<string>`             |
|`smoke_assert_code <code>`       | assert that there was a `<code>` response code       |
|`smoke_assert_code_ok`           | assert that there was a `2xx` response code          |
|`smoke_csrf <token>`             | set the csrf token to use in POST requests           |
|`smoke_form <url> <datafile>`    | POST data on url                                     |
|`smoke_form_ok <url> <datafile>` | POST data on url and check for a `2xx` response code |
|`smoke_report`                   | prints the report and exits                          |
|`smoke_response_body`            | body of the last response                            |
|`smoke_response_code`            | code of the last response                            |
|`smoke_response_headers`         | headers of the last response                         |
|`smoke_url <url>`                | GET a url                                            |
|`smoke_url_ok <url>`             | GET a url and check for a `2xx` response code        |
|`smoke_url_prefix <prefix>`      | set the prefix to use for every url (e.g. domain)    |
