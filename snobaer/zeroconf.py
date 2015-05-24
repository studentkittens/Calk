#!/usr/bin/env python
# encoding: utf-8

from gi.repository import Moose
from gi.repository import GLib

import sys
import logging

LOGGER = logging.getLogger('zeroconf')


def print_server(browser):
    LOGGER.info('-- SERVER LIST --')
    for server in browser:
        for attr, value in server:
            LOGGER.info('{:>10} : {}'.format(attr, value))
        LOGGER.info('')


def zeroconf_state_changed(browser):
    state = browser.get_state()
    if state is Moose.ZeroconfState.CHANGED:
        if browser.timeout_id is not None:
            GLib.source_remove(browser.timeout_id)
        browser.timeout_id = GLib.timeout_add(
            500, lambda: print_server(browser)
        )
    elif state is Moose.ZeroconfState.ERROR:
        LOGGER.error('Error', browser.get_error())
    elif state is Moose.ZeroconfState.ALL_FOR_NOW:
        LOGGER.info('-- ALL FOUND FOR NOW --')
    elif state is Moose.ZeroconfState.UNCONNECTED:
        LOGGER.error('-- CONNECTION LOST --')
    else:
        LOGGER.warning(
            'Unknown state. ZeroconfBrowser, you\'re drunk, go home.'
        )


def print_servers():
    browser = Moose.ZeroconfBrowser()
    if browser.get_state() is not Moose.ZeroconfState.CONNECTED:
        logging.critical('No avahi running, eh?')
        sys.exit(0)

    browser.timeout_id = None
    browser.connect('state-changed', zeroconf_state_changed)

    try:
        loop = GLib.MainLoop()
        GLib.timeout_add(2 * 1000, loop.quit)
        loop.run()
    except KeyboardInterrupt:
        logging.warning('[Ctrl-C]')


if __name__ == '__main__':
    print_servers()
