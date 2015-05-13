#!/usr/bin/env python3
# encoding:utf8

from flask import Flask, render_template, Response
from flask_appconfig import AppConfig
from flask_bootstrap import Bootstrap


def create_app(configfile=None):
    app = Flask(__name__)
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
@flask_app.route('/fonts/<name>')
def fonts_dummy(name=None):
    return Response('', mimetype='font/opentype')
