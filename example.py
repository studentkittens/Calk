#!/usr/bin/env python3
# encoding:utf8

from flask import Flask, render_template, flash
from flask_appconfig import AppConfig
from flask_bootstrap import Bootstrap


def create_app(configfile=None):
    app = Flask(__name__)
    AppConfig(app, configfile)
    Bootstrap(app)

    # in a real app, these should be configured through Flask-Appconfig
    app.config['SECRET_KEY'] = 'devkey'
    app.config['RECAPTCHA_PUBLIC_KEY'] = '6Lfol9cSAAAAADAkodaYl9wvQCwBMr3qGR_PPHcw'

    @app.route('/')
    @app.route('/<name>')
    def index(name=None):
        flash('error message', 'error')
        return render_template('index.html', user=name)

    return app

if __name__ == '__main__':
    create_app().run(debug=True)
