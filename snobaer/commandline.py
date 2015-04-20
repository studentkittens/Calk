#!/usr/bin/env python3
# encoding:utf8

'''Snobaer is a versatile web mpd client.

This is the server side application.

Usage:
    snobaer
    snobaer [options] [-v...] [-q...]
    snobaer -H | --help
    snobaer -V | --version

Options:
    -h --host=<addr>     Define the server to connect to [default: localhost]
    -p --port=<port>     Define the server's port. [default: 6666]
    -P --password=<pwd>  Authenticate with this password on the server.
    -t --timeout=<sec>   Wait sec seconds for a timeout. [default: 200.0]

Misc Options:
    -H --help            Show this help text.
    -V --version         Show a summary about snobaer's version.

Examples:

    snobaer list -h localhost -p 6600 -vvv
'''

try:
    import docopt
except ImportError:
    import sys
    print('-- docopt not found. Please run:')
    print('-- pip install docopt           ')
    sys.exit(-1)


def parse_arguments(cfg):
    args = docopt.docopt(__doc__, version='0.1')

    cfg['mpd.host'] = args['--host']
    cfg['mpd.port'] = int(args['--port'])
    cfg['mpd.timeout'] = float(args['--timeout'])

    password = args['--password']
    if password != '':
        cfg['mpd.password'] = password
