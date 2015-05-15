#!/usr/bin/env python
# encoding: utf-8


"""IOLoop implementation for Tornado.

We use GLib's Mainloop internally, so we just build an adapter
that Tornado can understand.

This code is based on this Gist and was updated to PyGObject:

    https://gist.github.com/schlamar/8420193
"""

# Stdlib:
import datetime
import functools
import logging
import os
import time

LOGGER = logging.getLogger("ioloop")

# External:
from tornado import ioloop
from gi.repository import GLib


class GLibIOLoop(ioloop.IOLoop):
    READ = GLib.IO_IN
    WRITE = GLib.IO_OUT
    ERROR = GLib.IO_ERR | GLib.IO_HUP

    def initialize(self, time_func=None):
        super(GLibIOLoop, self).initialize()

        self.time_func = time_func or time.time
        self._handles = {}
        self._glib_loop = GLib.MainLoop()

    def close(self, all_fds=False):
        if all_fds:
            for fd in self._handles.keys():
                try:
                    os.close(fd)
                except Exception:
                    LOGGER.debug("error closing fd %s", fd, exc_info=True)

    def _handle_events(self, fd, events, callback):
        callback(fd, events)
        return True

    def add_handler(self, fd, callback, events):
        condition = GLib.IOCondition(events) | self.ERROR
        handle = GLib.io_add_watch(
            fd, 0, condition, self._handle_events, callback)
        self._handles[fd] = handle, callback

    def update_handler(self, fd, events):
        handle, callback = self._handles.pop(fd)
        GLib.source_remove(handle)
        self.add_handler(fd, callback, events)

    def remove_handler(self, fd):
        handle, _ = self._handles.pop(fd)
        GLib.source_remove(handle)

    def start(self):
        if not logging.getLogger().handlers:
            logging.basicConfig()
        self._glib_loop.run()

    def stop(self):
        self._glib_loop.quit()

    def time(self):
        return self.time_func()

    def add_timeout(self, deadline, callback):
        if isinstance(deadline, datetime.timedelta):
            seconds = ioloop._Timeout.timedelta_to_seconds(deadline)
        else:
            seconds = deadline - self.time()
        ms = max(0, int(seconds * 1000))
        handle = GLib.timeout_add(ms, self._run_callback, callback)
        return handle

    def remove_timeout(self, handle):
        GLib.source_remove(handle)

    def add_callback(self, callback, *args, **kwargs):
        callback = functools.partial(callback, *args, **kwargs)
        GLib.idle_add(self._run_callback, callback)

    add_callback_from_signal = add_callback


if __name__ == '__main__':
    import tornado.web

    # Internal:
    import logger
    logger.create_logger(None)


    class MainHandler(tornado.web.RequestHandler):
        def get(self):
            self.write("Hello, world\n")

    loop = GLibIOLoop()
    loop.install()

    application = tornado.web.Application([
        (r"/", MainHandler),
    ])

    def timeout_event():
        LOGGER.info("Hah, Im running!")
        return True

    from gi.repository import Moose
    from snobaer.heartbeat import Heartbeat

    def create_client():
        client = Moose.Client.new(Moose.Protocol.DEFAULT)
        client.props.timer_interval = 1.0
        client.timer_set_active(True)

        client.connect_to('localhost', 6666, 200)

        # Monkey patch some useful python side properties:
        client.heartbeat = Heartbeat(client)
        client.store = Moose.Store.new(client)
        return client

    c = create_client()
    c.connect('client-event', lambda *_: print(c.ref_status().get_current_song()))


    GLib.timeout_add(1000, timeout_event)

    application.listen(8888)

    try:
        loop.start()
    except KeyboardInterrupt:
        loop.close()
