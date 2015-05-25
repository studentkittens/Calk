#!/usr/bin/env python3
# encoding:utf8

import os

import uptime
import psutil

from flask import Flask, render_template, send_from_directory
from flask_bootstrap import Bootstrap


def create_app():
    app = Flask(__name__, static_folder='static')
    Bootstrap(app)

    # Default key is "echo | md5sum":
    app.config['SECRET_KEY'] = \
        os.environ.get('SNOBAER_SECRET') or '68b329da9893e34099c7d8ad5cb9c940'

    return app

FLASK_APP = create_app()


def get_sysinfo():
    stats = {}
    stats["cpu_load"] = psutil.cpu_percent()
    stats["cpu_count"] = psutil.cpu_count()
    stats["hostname"] = os.uname().nodename
    stats["system"] = os.uname().sysname + " " + os.uname().release

    mem = psutil.virtual_memory()
    stats["mem_total"] = to_human_readable(mem.total)
    stats["mem_free"] = to_human_readable(mem.free)
    stats["mem_used_perc"] = 100 - (100 / mem.total * mem.free)

    swap = psutil.swap_memory()
    stats["swap_total"] = to_human_readable(swap.total)
    stats["swap_free"] = to_human_readable(swap.free)
    stats["swap_used_perc"] = 100 - (100 / swap.total * swap.free)

    partitions = psutil.disk_partitions()
    stats["drives"] = []
    for partition in partitions:
        drive = {
            'dev': partition.device,
            'mountpoint': partition.mountpoint,
            'usage_percent': psutil.disk_usage(partition.mountpoint).percent
        }
        stats["drives"].append(drive)

    days = int(uptime.uptime() / (3600 * 24))
    hours = int(uptime.uptime() / 3600)
    mins = int(uptime.uptime() / 60 - hours * 60)
    stats['uptime'] = "{} days, {} hours, {}".format(days, hours, mins)

    return stats


def to_human_readable(value):
    for unit in ['B', 'KB', 'MB', 'GB', 'TB', 'PB', 'EB']:
        if value < 1024:
            break
        value /= 1024
    return "{:.2f} {}".format(value, unit)


@FLASK_APP.route('/')
def index():
    return render_template('index.html')


@FLASK_APP.route('/sysinfo')
def sysinfo():
    return render_template('sysinfo.html', **get_sysinfo())


@FLASK_APP.route('/css/<path:name>')
def deliver_css(name):
    return send_from_directory('static/css', name)
