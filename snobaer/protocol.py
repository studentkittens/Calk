#!/usr/bin/env python
# encoding: utf-8

"""Protocol definiton which is used between this backend and the frontend. This
only describes the data which is exchanged on the websocket. We try to keep
this as small as possible in order to reduce complexity in the frontend.

The data format is json due to the easy parsing on client side.

General Message format:

    {
        'type': (cmd|info)
        'name': [cmd]
        'params': [p1, p2, p3, ...]
    }

Client -> Server types:
=======================

mpd
---

* [actual_command]   # See moose-mpd-client.c:1030 for [actual_command]
* close              # Close the connection from client.

store
-----

* query-queue [query]
* query-database [query]
* query-directories [depth] [query]
* query-spl [name] [query]

Server -> Client types:
=======================

* status            # include MooseStatus and MooseSong
* outputs           # list of MooseOutputs
* playlist          # json list of of MooseSongs with context id

"""

import json
import logging

LOGGER = logging.getLogger('proto')


from gi.repository import Moose

########################
#   CLIENT -> SERVER   #
########################


def parse_mpd_command(document):
    # get command and params[0]
    # send to moose_client_send
    pass


def parse_store_command(document):
    pass


def parse_doc(document):
    doc_type = document.get('type')
    detail = document.get('detail')

    # Valid documents have at least a type and detail.
    if doc_type is None or detail is None:
        LOGGER.error('document is malformed:\n' + str(document))
        return


def parse_message(message):
    try:
        return parse_doc(json.loads(mesage))
    except ValueError as err:
        LOGGER.error('Unable to parse json message:\n' + message)



########################
#   SERVER -> CLIENT   #
########################

def serialize_song(song):
    if song is not None:
        # Only serialize the most needed data for now.
        keys = ['artist', 'album', 'title', 'id']
        return {key: getattr(song.props, key) for key in keys}

    return {}


def serialize_state(state):
    # This cast is for safety.
    return Moose.State(state).value_nick


def serialize_status(status, detail='timer'):
    # Just serialize all the status data
    status_data = {
        'type': 'status',
        'detail': detail,
        'status': {
            i.name: status.get_property(i.name) for i in Moose.Status.props
        }
    }

    status_data['status']['state'] = serialize_state(status.props.state)
    status_data['status']['song'] = serialize_song(status.get_current_song())
    return status_data


def serialize_playlist(playlist, detail='queue'):
    return {
        'type': 'playlist',
        'detail': detail,
        'songs': [serialize_song(song) for song in playlist]
    }


if __name__ == '__main__':
    from gi.repository import Moose
    import time

    client = Moose.Client.new(Moose.Protocol.DEFAULT)
    client.connect_to()
    client.force_sync(Moose.Idle(0xffffffff))
    time.sleep(0.5)
    client.wait()

    with client.reffed_status() as status:
        print(json.dumps(serialize_status(status), indent=4))
