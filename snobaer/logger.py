#!/usr/bin/env python
# encoding: utf-8

# Stdlib:
import logging
import logging.handlers

# External:
from gi.repository import GObject
from gi.repository import Moose


COLORED_FORMAT = "%(asctime)s%(reset)s %(log_color)s[logsymbol] \
%(levelname)-8s%(reset)s \
%(bold_black)s%(name)s:%(lineno)d:%(reset)s %(message)s"

SIMPLE_FORMAT = "%(asctime)s %(levelname)-8s [%(filename)s:%(lineno)3d] \
%(name)s: %(message)s"

DATE_FORMAT = "%H:%M:%S"
UNICODE_ICONS = {
    logging.DEBUG: '⚙',
    logging.INFO: '⚐',
    logging.WARNING: '⚠',
    logging.ERROR: '⚡',
    logging.CRITICAL: '☠'
}


def create_logger(name=None, path=None, verbosity=logging.DEBUG):
    '''Create a new Logger configured with moosecat's defaults.

    :name: A user-define name that describes the logger
    :path: Path to store a log file.
    :return: A new logger .
    '''
    logger = logging.getLogger(name)

    # This is hack to see if this function was already called
    if len(logging.getLogger(None).handlers) is 2:
        return logger

    # Defaultformatter, used for File logging,
    # and for stdout if colorlog is not available
    formatter = logging.Formatter(
        SIMPLE_FORMAT,
        datefmt=DATE_FORMAT
    )

    # Try to load the colored log and use it on success.
    # Else we'll use the SIMPLE_FORMAT
    try:
        import colorlog

        class SymbolFormatter(colorlog.ColoredFormatter):
            def format(self, record):
                result = colorlog.ColoredFormatter.format(self, record)
                return result.replace(
                    '[logsymbol]',
                    UNICODE_ICONS[record.levelno]
                )

    except ImportError:
        print('Could not import colorlog')
        col_formatter = formatter
    else:
        col_formatter = SymbolFormatter(
            COLORED_FORMAT,
            datefmt=DATE_FORMAT,
            reset=False
        )

    # Stdout-Handler
    stream = logging.StreamHandler()
    stream.setFormatter(col_formatter)

    # Rotating File-Handler
    file_stream = logging.handlers.RotatingFileHandler(
        filename=path or '/tmp/app.log',
        maxBytes=(1024 ** 2 * 10),  # 10 MB
        backupCount=2,
        delay=True
    )
    file_stream.setFormatter(formatter)

    # Create the logger and configure it.
    logger.addHandler(file_stream)
    logger.addHandler(stream)
    logger.setLevel(verbosity)
    return logger


MOOSE_TO_PYTHON_LOGLEVEL = {
    "Critical": logging.Logger.critical,
    "Error": logging.Logger.error,
    "Warning": logging.Logger.warning,
    "Message": logging.Logger.info,
    "Info": logging.Logger.info,
    "Debug": logging.Logger.debug,
    "Unknown": logging.Logger.warning,
}


class InternalLogCatcher(GObject.Object):
    """Routes libmoosecat's inernal log messages to python's logging module. """
    __gsignals__ = {
        'log-message': (
            GObject.SIGNAL_RUN_FIRST,
            None,
            (str, str, str)
        )
    }

    def __init__(self):
        GObject.Object.__init__(self)
        self._loggers = {}
        self.connect('log-message', InternalLogCatcher._on_log_message)
        Moose.misc_catch_external_logs(self)

    def _on_log_message(self, domain, level, msg):
        logger = self._loggers.get(domain)
        if logger is None:
            logger = self._loggers[domain] = logging.getLogger(domain)

        MOOSE_TO_PYTHON_LOGLEVEL[level](logger, msg)


if __name__ == '__main__':
    LOGGER = create_logger('Bärbel')
    LOGGER.setLevel(logging.DEBUG)

    LOGGER.critical('Hello, Im Herbert.')
    LOGGER.error('Im a logger..')
    LOGGER.warning('...and will guide you...')
    LOGGER.info('...through the various logging levels.')
    LOGGER.debug('Oh, you can see debug messages too?')
