#!/usr/bin/env python
# encoding: utf-8

"""General filesystem utilties
"""

# Stdlib:
import os

# External:
from xdg import BaseDirectory


def _check_or_mkdir(path):
    if not os.path.exists(path):
        os.makedirs(path)


def create_file_structure(cfg):
    config_dir = os.path.join(BaseDirectory.xdg_config_dirs[0], 'snobaer')
    _check_or_mkdir(config_dir)
    cfg['fs.config_dir'] = config_dir

    cache_dir = os.path.join(BaseDirectory.xdg_cache_home, 'snobaer')
    _check_or_mkdir(cache_dir)
    cfg['fs.cache_dir'] = cache_dir

    config_file = os.path.join(config_dir, 'config.yaml')
    cfg['fs.config_file'] = config_file

    log_file = os.path.join(config_dir, 'app.log')
    cfg['fs.log_file'] = log_file


if __name__ == '__main__':
    from config import Config

    config = Config()
    create_file_structure(config)
