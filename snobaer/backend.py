#!/usr/bin/env python3
# encoding:utf8

# Stdlib:
import sys
import json
import logging

# Internal:
from snobaer.fs import create_file_structure
from snobaer.web import flask_app
from snobaer.mainloop import GLibIOLoop
from snobaer.heartbeat import Heartbeat
from snobaer.protocol import \
    serialize_status, \
    serialize_heartbeat, \
    parse_message

LOGGER = logging.getLogger('backend')

# External:
from gi.repository import Moose
from gi.repository import GLib

from tornado.wsgi import WSGIContainer
from tornado.web import FallbackHandler, Application
from tornado.websocket import WebSocketHandler, WebSocketClosedError


class FrontedWSHandler(WebSocketHandler):
    def initialize(self, client):
        LOGGER.debug('Setting up WebsocketHandler')

        # Make sure we get notified on client events.
        # On each client event we'll push an status update.
        client.connect('client-event', self.on_client_event)

        # Trigger a heartbeat every second
        # (because a pulse of 60 is considered healthy.)
        GLib.timeout_add(1000, self.on_heartbeat, client.heartbeat)
        self.client = client
        self.last_song_id = None

    def open(self):
        LOGGER.debug("WebSocket opened")

        # Trigger an initial update event (a player event to be exact)
        self.on_client_event(self.client, Moose.Idle.PLAYER)

    def on_message_processed(self, json_doc):
        try:
            self.write_message(json_doc)
        except Exception as err:
            LOGGER.error(
                "Unable to write back message:" + str(json_doc) + str(err)
            )

    def on_message(self, message):
        parse_message(self.client, message, self.on_message_processed)

    def on_heartbeat(self, heartbeat):
        hb = serialize_heartbeat(heartbeat)
        try:
            self.write_message(json.dumps(hb))
        except WebSocketClosedError:
            self.close()
        return True

    def on_client_event(self, client, event):
        with client.reffed_status() as status:
            if status is None:
                return

            serialized_data = serialize_status(client, status, event)

            current_song = status.get_current_song()
            if current_song is not None or self.last_song_id is None:
                if self.last_song_id != current_song.props.id:
                    serialized_data['status']['song-changed'] = True
                    if current_song:
                        self.last_song_id = current_song.props.id

            try:
                self.write_message(json.dumps(serialized_data))
            except WebSocketClosedError:
                self.close()

    def on_close(self):
        LOGGER.debug("WebSocket closed")
        self.client.disconnect_by_func(self.on_client_event)


def log_client_event(client, events):
    LOGGER.debug('client event: {}'.format(Moose.Idle(events)))


def log_connection_event(client, server_changed, cfg):
    LOGGER.warning('connection changed: connected={} server-changed={}'.format(
        "yes" if client.is_connected() else "no",
        "yes" if server_changed else "no"
    ))

    # Schedule a reconnect if needed:
    if client.is_connected() is False:
        LOGGER.warning('Attempting reconnect in 2 seconds.')
        host, port = cfg['mpd.host'], cfg['mpd.port']
        GLib.timeout_add(2000, lambda: not client.connect_to(host, port, 200))


def create_client(cfg):
    client = Moose.Client.new(Moose.Protocol.DEFAULT)
    client.connect('connectivity', log_connection_event, cfg)
    client.connect('client-event', log_client_event)
    client.props.timer_interval = 1.0
    client.timer_set_active(True)

    client.connect_to(cfg['mpd.host'], cfg['mpd.port'], 200)

    # Monkey patch some useful python side properties:
    client.heartbeat = Heartbeat(client)
    client.store = Moose.Store.new(client)
    client.metadata = Moose.Metadata(database_location=cfg['fs.cache_dir'])
    return client


def run_backend(cfg):
    LOGGER.critical('Hello, Im Herbert.')
    LOGGER.error('Im a logger..')
    LOGGER.warning('...and will guide you...')
    LOGGER.info('...through the various logging levels.')
    LOGGER.debug('Oh, you can see debug messages too?')

    create_file_structure(cfg)
    client = create_client(cfg)

    loop = GLibIOLoop()
    loop.install()

    tornado_app = Application([
        (r"/ws", FrontedWSHandler, {'client': client}),
        (r".*", FallbackHandler, dict(fallback=WSGIContainer(flask_app)))
    ])

    try:
        tornado_app.listen(cfg['backend.port'], address='0.0.0.0')
    except OSError as exc:
        LOGGER.critical('Unable to start tornado. Is the port free?')
        LOGGER.critical('Exact error was: ' + str(exc))
        return False

    LOGGER.info('Running on :8080')

    try:
        loop.start()
    except KeyboardInterrupt:
        # Hack to hide the '^C' displayed in the cmdline.
        sys.stderr.write('  \r')
        LOGGER.warning('[interrupted]')
        loop.close()

    return True
