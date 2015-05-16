#!/usr/bin/env python3
# encoding:utf8

from flask import Flask, render_template, Response, send_from_directory, abort, url_for
from flask_appconfig import AppConfig
from flask_bootstrap import Bootstrap


def create_app(configfile=None):
    app = Flask(__name__, static_folder='static')
    AppConfig(app, configfile)
    Bootstrap(app)

    # in a real app, these should be configured through Flask-Appconfig
    app.config['SECRET_KEY'] = 'devkey'

    return app

flask_app = create_app()


@flask_app.route('/')
def index():
    return render_template('index.html')


# TODO: Dummy handler for fixing "missing" fonts.
## @flask_app.route('/static/fonts/<name>')
## def fonts_dummy(name=None):
##     return Response('', mimetype='font/opentype')


@flask_app.route('/css/<path:name>')
def deliver_css(name):
    return send_from_directory('static/css', name)
