#!/usr/bin/env python
# encoding: utf8

import musicbrainzngs
import sys
import json
import pprint

def get_album_input():
    with open(sys.argv[1], 'r') as fd:
        return fd.read().splitlines()

def extract_tracklist_from_release(release):
    medium, *_ = release.get('medium-list')
    tracks = []
    for track in medium.get('track-list'):
        tracks.append((track.get('position'), track.get('recording').get('title')))
    return tracks

def album_to_jstruct(artist, tracks, album, genre):
    jstruct = []
    for position, trackname in tracks:
        entry = {
            "album": album,
            "album_artist": artist,
            "artist": artist,
            "composer": artist,
            "title": trackname,
            "track": position
        }
        jstruct.append(entry)
    return jstruct

if __name__ == '__main__':

    if len(sys.argv) < 3:
        print("Usage: tool inputfile outputfile")
        sys.exit(0)

    albums = get_album_input()
    liste = []
    for album in albums:
        artist, album, genre = album.split('|')

        musicbrainzngs.set_useragent('SimplePythonScript', '1.0')
        result = musicbrainzngs.search_releases(artist=artist, release=album)
        first_release, *_ = result.get('release-list')
        release_id = first_release.get('id')
        release = musicbrainzngs.get_release_by_id(release_id, includes=["artists", "recordings"]).get('release')

        title = release.get('title')
        artist = release.get('artist-credit')[0].get('artist').get('name')
        tracks = extract_tracklist_from_release(release)
        liste.extend(album_to_jstruct(artist, tracks, title, genre))

    with open(sys.argv[2], 'w') as fd:
        fd.write(json.dumps(liste, sort_keys=True, indent=4))
