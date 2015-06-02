# encoding: utf-8

# Stdlib:
import time

# External:
from gi.repository import Moose
from gi.repository import GObject

# Internal:
from tests.mpd import MpdTestProcess

CLIENT = None
MPD_PROC = None
DO_PRINT = True

####################################
# Make sure that the log is silent #
####################################


class InternalLogCatcher(GObject.Object):
    __gsignals__ = {
        'log-message': (
            GObject.SIGNAL_RUN_FIRST,
            None,
            (str, str, str)
        )
    }


def log_message(catcher, domain, level, msg):
    if DO_PRINT:
        print(domain, msg)


catcher = InternalLogCatcher()
catcher.connect('log-message', log_message)
Moose.misc_catch_external_logs(catcher)


##############################
# Setup and teardown helpers #
##############################

def start_mpd(do_print=DO_PRINT):
    global MPD_PROC
    if MPD_PROC is None:
        MPD_PROC = MpdTestProcess(do_print=do_print)
        MPD_PROC.start()
        time.sleep(2)


def client():
    return CLIENT


def setup_client():
    # start_mpd()

    global CLIENT
    CLIENT = Moose.Client.new(Moose.Protocol.DEFAULT)
    CLIENT.connect_to(port=6666)
    return CLIENT


def teardown_client():
    if CLIENT.is_connected:
        CLIENT.disconnect()
