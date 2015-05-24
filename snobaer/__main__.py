#!/usr/bin/env python3
# encoding:utf8

'''Snøbær is a neat web mpd client.

This is the server side application.

Usage:
    snobaer
    snobaer [options] [-v...] [-V...]
    snobaer -H | --help
    snobaer -? | --version
    snobaer -l | --list-servers

Options:
    -h --host=<addr>         Define the MPD to connect to [default: localhost]
    -p --port=<mpdport>      Define the MPD's port. [default: 6666]
    -b --backend-port=<port> Define the backend's port [default: 8080]
    -l --list-servers        List all reachable MPD servers via Zeroconf.

Misc Options:
    -H --help            Show this help text.
    -? --version         Show a summary about Snøbær's version.
    -v --louder          Be more verbose (can be given more than once)
    -V --quieter         Be less verbose (can be given more than once)

Examples:

    snobaer -l
    snobaer -h localhost -p 6600 -v -b 8080
'''

# Stdlib:
import logging

# Internal:
from snobaer.config import Config
from snobaer.logger import InternalLogCatcher, create_logger
from snobaer.backend import run_backend
from snobaer.zeroconf import print_servers

# External:
try:
    import docopt
except ImportError:
    import sys
    print('-- docopt not found. Please run:')
    print('-- pip install docopt           ')
    sys.exit(-1)


def configure_loglevel(logger, count):
    level = {
        -3: logging.CRITICAL,
        -2: logging.ERROR,
        -1: logging.WARNING,
        +0: logging.INFO,
        +1: logging.DEBUG
    }.get(count, logging.WARNING)
    logger.setLevel(level)


def parse_arguments(cfg, logger):
    args = docopt.docopt(__doc__, version='0.1')

    if args['--list-servers']:
        print_servers()
        return False

    if args['--version']:
        print('Snøbær pre-release version. Look at GitHub for more info:')
        print('https://github.com/studentkittens/snobaer')
        return False

    cfg['mpd.host'] = args['--host']
    cfg['mpd.port'] = int(args['--port'])
    cfg['backend.port'] = int(args['--backend-port'])
    cfg['backend.verbosity'] = configure_loglevel(
        logger, args['--louder'] - args['--quieter']
    )
    return True


if __name__ == '__main__':
    # Make sure logging is initialized early.
    root_logger = create_logger(None)

    # Make sure internal messages land on the same logging "bus"
    internal_logcatcher = InternalLogCatcher()

    # actual logger for this module.
    logger = logging.getLogger('commandline')

    # Create the config and add the defaults.
    cfg = Config({
        'mpd': {
            'host': 'localhost',
            'port': 6666,
            'timeout': 200.0
        },
        'backend': {
            'port': 8080
        }
    })

    try:
        if parse_arguments(cfg, root_logger):
            run_backend(cfg)
    finally:
        cfg.save()
