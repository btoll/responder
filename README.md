# Responder

This program gets the response times of a request sent to a specific domain.

Design goals:

- should be able to be used as a standalone program and also as part of a pipeline
- support both `GET` and `HEAD` requests
- multi-threaded where threads are immediately garbage collected when the response is returned
- recover gracefully from exceptions, that is, continue to make requests even after failures
- captures `SIGINT` and dumps the work that has been completed as `JSON` to `STDOUT`
- the following can be configured by passing parameters on the command line:
    + `HTTP` method (`GET`, `HEAD`)
    + the interval at which requests are made
    + whether an informative header is printed
    + the total running time (defaults to 5 minutes)
- support many modes:
    + verbose
    + debug
    + silent
        - when running in this mode, output results as `JSON`
        - useful for tooling
- have each function do only one thing to make testing easy

Possible nice-to-haves:

- Python has the [`argparse` library](https://docs.python.org/3/library/argparse.html) which allows for a callback to check the type of an argument.  It would be nice to have that here.  A quick search revealed that Ruby's `optparse` class has [support for type coercion](https://ruby-doc.org/stdlib-2.7.1/libdoc/optparse/rdoc/OptionParser.html#class-OptionParser-label-Type+Coercion).
- Could make the `read_timeout` property for requests configurable.
- Make the `hostname` and `port` configurable.

## Notes

Formats to three decimal places when printing to `STDOUT` but does not when used in a pipeline (the tool shouldn't make a decision for the user, let them format it however they want).

## Examples

Usage:

```bash
$ ruby responder.rb -h
Usage: responder.rb [options]
    -d, --debug
    -m, --http-method                Supports either GET or HEAD.  Defaults to GET.
    -i, --interval SECONDS           Defaults to 10 seconds.
        --no-header                  Don't print the header.
    -o, --outfile FILE               NOT IMPLEMENTED
    -t, --running_time SECONDS       Total time of test.  Defaults to 5 minutes.
    -s, --silent
    -v, --verbose                    Print every response time in ms.
    -h, --help
```

Get responses every five seconds:

```bash
$ ruby responder.rb --time 120 -i5
[INFO] Testing endpoint `gitlab.com:443`.
[INFO] HTTP method is GET.
[INFO] Calling `run_interval` every 5 seconds.
[INFO] Total running time is 120 seconds.
1..2..3..4..5..6..7..8..9..10..11..12..13..14..15..16..17..18..19..20..21..22..23..24..
===============
RESPONSE TIMES:
===============
Average: 44.837
Maximum: 108.600
Minimum: 35.369
```

Same example, but don't print the header:

```bash
$ ruby responder.rb --time 120 -i5 --no-header
1..2..3..4..5..6..7..8..9..10..11..12..13..14..15..16..17..18..19..20..21..22..23..24..
===============
RESPONSE TIMES:
===============
Average: 44.837
Maximum: 108.600
Minimum: 35.369
```

Get all response times:

```bash
$ ruby responder.rb --time 10 -si2 | jq ".response_times"
[
  38.878751,
  41.284411999999996,
  44.291852999999996,
  36.126304,
  37.143296
]
```

Get responses every 10 seconds with increased verbosity (will print the roundtrip time in milliseconds):

```bash
$ ruby responder.rb --time 120 -vi10
[INFO] Testing endpoint `gitlab.com:443`.
[INFO] HTTP method is GET.
[INFO] Calling `run_interval` every 10 seconds.
[INFO] Total running time is 120 seconds.
1..39.244ms
2..34.660ms
3..69.560ms
4..39.372ms
5..68.942ms
6..42.798ms
7..42.995ms
8..38.938ms
9..44.974ms
10..42.369ms
11..37.443ms
12..42.015ms

===============
RESPONSE TIMES:
===============
Average: 45.276
Maximum: 69.560
Minimum: 34.660
```

Make a `HEAD` request (note that `SIGINT` was handled by the program):

```bash
$ ruby responder.rb -vi3 -mHEAD
[INFO] Testing endpoint `gitlab.com:443`.
[INFO] HTTP method is HEAD.
[INFO] Calling `run_interval` every 3 seconds.
[INFO] Total running time is 300 seconds.
1..59.773ms
2..42.504ms
3..39.308ms
4..39.030ms
^C{
  "domain": "gitlab.com",
  "port": "443",
  "http_method": "HEAD",
  "running_time": 300,
  "response_times": [
    59.772682,
    42.503989,
    39.307683000000004,
    39.030084
  ],
  "maximum_response_time": 59.772682,
  "minimum_response_time": 39.030084
}
```

Make a `HEAD` request and turn on debugging (note the hash printed in the beginning with the captured values):

```bash
$ ruby responder.rb --running-time 30 -i3 -mHEAD -vd
{
  "debug": true,
  "http_method": "HEAD",
  "interval": 3,
  "no_header": false,
  "outfile": "#<IO:0x0000563af7db7968>",
  "running_time": 30,
  "silent": false,
  "verbose": true
}
[INFO] Testing endpoint `gitlab.com:443`.
[INFO] HTTP method is HEAD.
[INFO] Calling `run_interval` every 3 seconds.
[INFO] Total running time is 30 seconds.
1..36.590ms
2..36.867ms
3..37.875ms
4..36.564ms
5..35.427ms
6..35.890ms
7..38.160ms
8..36.195ms
9..37.031ms
10..37.529ms

===============
RESPONSE TIMES:
===============
Average: 36.813
Maximum: 38.160
Minimum: 35.427
```

Output for consumption by other tooling:

```bash
$ ruby responder.rb --time 120 -si10
{
  "domain": "gitlab.com",
  "port": "443",
  "http_method": "GET",
  "running_time": 120,
  "response_times": [
    36.613267,
    37.195397,
    37.668812,
    43.715484,
    36.727153,
    41.564607,
    34.628994000000006,
    42.55759,
    43.01035,
    44.842003999999996,
    40.525955,
    37.411227
  ],
  "maximum_response_time": 44.842003999999996,
  "minimum_response_time": 34.628994000000006
}
```

Get the number of responses:

```bash
$ ruby responder.rb --time 10 -si2 | jq ".response_times | length"
5
```

# References

- [class Net::HTTP](https://docs.ruby-lang.org/en/master/Net/HTTP.html)

