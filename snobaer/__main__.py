#!/usr/bin/env python3
# encoding:utf8

from flask import Flask, render_template, flash
from flask_appconfig import AppConfig
from flask_bootstrap import Bootstrap

from tornado.wsgi import WSGIContainer
from tornado.ioloop import IOLoop
from tornado.web import FallbackHandler, RequestHandler, Application
from tornado.websocket import WebSocketHandler


def create_app(configfile=None):
    app = Flask(__name__)
    AppConfig(app, configfile)
    Bootstrap(app)

    # in a real app, these should be configured through Flask-Appconfig
    app.config['SECRET_KEY'] = 'devkey'

    return app


flask_app = create_app()


@flask_app.route('/')
def index(name=None):
    flash('critical message', 'critical')
    flash('error message', 'error')
    flash('warning message', 'warning')
    flash('info message', 'info')
    flash('debug message', 'debug')
    flash('different message', 'different')
    flash('uncategorized message')
    return render_template('index.html', user=name)


class MainHandler(RequestHandler):
    def get(self):
        self.write("Why would you want to know?")


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
    (r"/version", MainHandler),
    (r"/ws", EchoWebSocket),
    (r".*", FallbackHandler, dict(fallback=WSGIContainer(flask_app)))
])


if __name__ == "__main__":
    tornado_app.listen(8080, address='0.0.0.0')

    try:
        IOLoop.instance().start()
    except KeyboardInterrupt:
        print('[interrupted]')
