#!/usr/bin/env python3
# encoding:utf8

from flask import Flask, render_template
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
def index(name=None):
    return render_template('index.html', user=name)
