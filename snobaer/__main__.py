#!/usr/bin/env python3
# encoding:utf8

# Stdlib:
import sys
import logging

# Internal:
from snobaer.fs import create_file_structure
from snobaer.web import flask_app
from snobaer.config import Config
from snobaer.logger import InternalLogCatcher, create_logger
from snobaer.mainloop import GLibIOLoop
from snobaer.heartbeat import Heartbeat
from snobaer.commandline import parse_arguments

# Make sure logging is initialized early.
ROOT_LOGGER = create_logger(None)
INTERNAL_LOGCATCHER = InternalLogCatcher()
LOGGER = logging.getLogger('server')

# External:
from gi.repository import Moose
from gi.repository import GLib

from tornado.wsgi import WSGIContainer
from tornado.ioloop import IOLoop
from tornado.web import FallbackHandler, Application
from tornado.websocket import WebSocketHandler


class EchoWebSocket(WebSocketHandler):
    def open(self):
        print("WebSocket opened")

    def on_message(self, message):
        self.write_message(u"You said: " + message)
        self.repeat()

    def repeat(self):
        self.write_message("Annoy you!")
        IOLoop.instance().call_later(1, self.repeat)

    def on_close(self):
        print("WebSocket closed")


tornado_app = Application([
    (r"/ws", EchoWebSocket),
    (r".*", FallbackHandler, dict(fallback=WSGIContainer(flask_app)))
])


def log_client_event(client, events):
    LOGGER.debug('client event: {}'.format(Moose.Idle(events)))


def reconnect_client(client):
    if client.connect_to(cfg['mpd.host'], cfg['mpd.port'], 200):
        client.reconnect_id = None
        return False

    return True


def log_connection_event(client, server_changed):
    LOGGER.warning('connection changed: connected={} server-changed={}'.format(
        "yes" if client.is_connected() else "no",
        "yes" if server_changed else "no"
    ))

    if client.is_connected() is False:
        LOGGER.warning('Attempting reconnect in 2 seconds.')
        if client.reconnect_id is None:
            client.reconnect_id = GLib.timeout_add(
                2000, reconnect_client, client
            )


def create_client(cfg):
    client = Moose.Client.new(Moose.Protocol.DEFAULT)
    client.reconnect_id = None
    client.connect('connectivity', log_connection_event)
    client.connect('client-event', log_client_event)

    client.connect_to(cfg['mpd.host'], cfg['mpd.port'], 200)

    # Monkey patch some useful python side properties:
    client.heartbeat = Heartbeat(client)
    client.store = Moose.Store.new(client)
    return client


if __name__ == "__main__":
    cfg = Config()
    cfg.add_defaults({
        'mpd': {
            'host': 'localhost',
            'port': 6666,
            'timeout': 200.0
        }
    })
    parse_arguments(cfg)

    LOGGER.critical('Hello, Im Herbert.')
    LOGGER.error('Im a logger..')
    LOGGER.warning('...and will guide you...')
    LOGGER.info('...through the various logging levels.')
    LOGGER.debug('Oh, you can see debug messages too?')

    create_file_structure(cfg)
    client = create_client(cfg)

    loop = GLibIOLoop()
    loop.install()
    tornado_app.listen(8080, address='0.0.0.0')

    try:
        LOGGER.info('Running on localhost:8080')
        loop.start()
    except KeyboardInterrupt:
        # Hack to hide the '^C' displayed in the cmdline.
        sys.stderr.write('  \r')
        LOGGER.warning('[interrupted]')
        loop.close()
