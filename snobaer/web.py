#!/usr/bin/env python3
# encoding:utf8

import os
import time
import pprint

import uptime
import psutil

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



def get_sysstats():
    stats = {}
    stats["cpu_load"] = psutil.cpu_percent()
    stats["cpu_count"] = psutil.cpu_count()
    stats["hostname"] = os.uname().nodename
    stats["system"] = os.uname().sysname + " " + os.uname().release

    mem = psutil.virtual_memory()
    stats["mem_total"] = mem.total
    stats["mem_free"] = mem.free

    swap = psutil.swap_memory()
    stats["swap_total"] = swap.total
    stats["swap_free"] = swap.free

    partitions = psutil.disk_partitions()
    stats["drives"] = []
    for partition in partitions:
        drive = {
            'dev': partition.device,
            'mountpoint': partition.mountpoint,
            'usage_percent' : psutil.disk_usage(partition.mountpoint).percent
        }
        stats["drives"].append(drive)

    stats["uptime_days"] = int(uptime.uptime() / (3600 * 24))
    stats["uptime_hours"] = int(uptime.uptime() / 3600)
    stats["uptime_mins"] = int(uptime.uptime() / 60 - stats["uptime_hours"] * 60)

    return stats


@flask_app.route('/')
def index():
    return render_template('index.html')


@flask_app.route('/sysinfo')
def sysinfo():
    return render_template('sysinfo.html', **get_sysstats())


@flask_app.route('/css/<path:name>')
def deliver_css(name):
    return send_from_directory('static/css', name)
