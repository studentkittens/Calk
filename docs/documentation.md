---
documentclass: scrartcl
title: Der Webmpd-Client Snøbær
author: Christopher Pahl und Christoph Piechula
fontsize: 11pt
lang: german
sections: yes
toc: yes
date: \today
---

# Vorwort

## Einleitung

Das Ziel der Studienarbeit ist es eine Software mit einem Python
Webframework umzusetzen. Aus persönlichen Interesse haben wir uns für einen
Music Player Client (kurz MPC) entschieden. 

Der Music Player Daemon (kurz MPD) ist eine unter unixoiden Betriebssystemen
beliebte Software um Musik mittels einer Client/Server--Architektur abzuspielen.
Der Server verwaltet dabei die komplette Datenbank samt Metadaten, der Client
hingegen dient lediglich als ,,Fernbedienung'' und zeigt oft noch Coverart und
weitere Daten an. 

Auf der offiziellen MPD--Seite[^mpdclientspage] gibt es eine Liste aller verfügbaren
MPD--Clients --- es sind mittlerweile über 200. Darunter sind auch einige
Webbasierte Clients, wie ympd, Volumio[^volumiopage] (Debian basierend) oder RuneAudio
[^runeaudiopage] (Archlinux basierend). Die beiden letzteren sind sogar vollwertige
HiFi-Audioplayer Linux--Distributionen mit den Raspberry Pi als
Hauptzielplattform. Leider sind diese relativ groß und komplex und auch noch in
PHP geschrieben. ympd[^ympdpage] ist hingegen in C geschrieben und kommuniziert mittels
Websockets mit dem auf Bootstrap basierten Javascript Frontend. 

[^mpdclientspage]: Liste mit MPD--Clients: \url{http://mpd.wikia.com/wiki/Clients}
[^volumiopage]: Volumio Webpage: \url{https://volumio.org/}
[^runeaudiopage]: RuneAudio Webpage: \url{http://www.runeaudio.com/}
[^ympdpage]: ympd Webpage: \url{http://www.ympd.org/}

## Zielsetzung

Das Ziel unseres Projekt ist es nun eine Mischung beider Welten herzustellen.
Zum einen soll der Client in C geschrieben sein, zudem groß und fett. Nein,
Scherzle macht. Das eigentliche Ziel der Arbeit ist es einen MPD-Client zu
schaffen welcher leichtgewichtig wie ympd ist und den Komfort von
Volumio/RuneAudio bietet und zusätzlich plattformunabhängig ist.

Da der Audiosetup in unserer Wohngemeinschaft auf einem Raspberry PI basiert,
ist es zudem wünschenswert, dass das Backend relativ ressourcenschonend ist um
den recht begrenzten Arbeitsspeicher des Rechners (256MB) nicht zu überfüllen. 

## Namensgebung und Logo

Da es in letzter Zeit hipp ist, Früchte in technische Produktnamen zu
integrieren (Raspberry Pi, Bananna Pi, ...) springen wir nun auf diesen Zug auf
und bedienen uns diesem Schema. Da es um Musik geht und die Software
auf einem Raspberry Pi laufen soll haben wir uns hier für ,,Knallerbsen'',
hochdeutsch Schneebeeren, entschieden. Um parallel den Unicode--Support in der
Welt zu verbessern und nördig zu wirken bedienten wir uns zudem der nordischen
Sprache und übersetzten Schneebeere auf Norwegisch: Snøbær.

![Logo von Snøbær](docs/pics/logo.png) {#fig:snobaerlogo}

Das Logo in Abbildung {@fig:snobaerlogo} zeigt eine Schneebeere, es wurde
mittels Inkscape für Snøbær erstellt.

# Grundlagen: Music Player Daemon und seine Clients

Um einen Music Player zu entwickeln eignet sich ein MPC besonders, da man nicht
das Rad neu erfinden muss. Der MPD bringt bereits die meisten Funktionalitäten
und Konzepte aus anderen Music Playern mit. Er kann bereits alle gebräuchlichen
Formate einlesen und auf viele Audio--Backends ausgeben. Zudem ist er sehr robust
und spielt auch zuverlässig bei hoher Systemlast noch Musik ab --- im Gegensatz
zu Amarok wo die Systemlast durch das Abspielen erst generiert wird.

![MPD-Architecture Overview, Quelle: http://mpd.wikia.com/](docs/pics/mpd-overview.png){#fig:mpdarchitecture}

Die meisten MPD-Konzepte sind bereits aus anderen Musikplayern bekannt, werden
aber hier noch kurz erwähnt:

* Sämtliche Songs werden in der *Database* gespeichert.
* Songs werden zum abspielen in die *Queue* geladen, wo sie der Reihe nach
  abgespielt werden.
* Der Inhalt der *Queue* kann als *Stored Playlist* unter einem Namen
  abgespeichert werden und zu einem späteren Zeitpunkt wieder geladen werden.
* Clients sprechen mit dem MPD über ein definiertes Textprotokoll[^mpdprotocol] 
* Es sind mehrere Audioausgaben möglich, darunter ALSA, PulseAudio oder auch ein
  HTTP Stream. Zudem lassen sich die Qualitätseinstellungen detailiert anpassen
  (libsamplerate etc) weswegen er bei audiophilem Publikum sehr beliebt ist.

[^mpdprotocol]: MPD Textprotokoll: \url{http://www.musicpd.org/doc/protocol/}

Da der MPD netzwerkfähig ist können sich mehrere Clients auf ihn schalten und
den ,,Zustand" des Servers ändern (wie beispielsweise das aktuell spielende
Lied). Man hat pro Server einen gemeinsamen Zustand, welcher von den Clients
widergespiegelt wird. Sollten mehrere  Zustände gewünscht sein, so kann man seit
MPD 0.19 zusätzlich Proxy--Server einrichten, die selbst als Clients des
Haupt--,,Servers'' fungieren, aber einen eigenen Zustand besitzen:

![MPD-Proxy Konzept](docs/pics/proxy.png) {#fig:mpdproxy}

Dieses Prinzip wird beispielsweise in unserer Wohngemeinschaft genutzt um die
Metadaten der Musiksammlung durch einen Hauptserver zu verwalten, der selbst
keine Audioausgabe besitzt, dafür aber Zugriff auf die Musikdaten hat. Auf jedem
abspielfähigen Gerät befindet sich dann ein Proxy--Server, welcher die Metadaten
des Hauptservers spiegelt und vom Nutzer des Rechners mittels eines MPD--Clients
gesteuert werden kann. 

# Aufbau von Snøbær

Snøbær folgt generell den Konzepten von MPD. Das Grundkonzept bedient sich zwei
Navigationsbars welche fest in jeder Ansicht immer sichtbar sind. Die obere
Navigationsleiste ermöglicht das Durchschalten der verschiedenen Ansichten
(Views) und bietet Zugriff auf die Einstellungen (Settings). Die einzelnen
Ansichten sind einzelne `<div>`--Elemente von denen jeweils nur eins sichtbar
ist.

Die untere Navigationsleiste beheimatet die typischen `previous`, `stop`, `play`,
`pause` und `next`--Buttons. In der Mitte dieser Leiste befindet sich ein
Fortschrittsbalken mit Songinformation, welcher die Position des aktuell
spielenden Liedes anzeigt. Rechts sind Steuerelemente für den Abspielmodus (in
dieser Reihenfolge): 

* *Random*: Folgelied wird zufällig aus Queue ausgewählt.
* *Repeat*: Queue wird nach Abspielende wiederholt (Endlosschleife).
* *Consume*: Nach dem Abspielen wird das Lied aus der Queue entfernt.
* *Single*: Beendet Abspielen nach dem aktuellen Lied.

## Ansichten:

Es bietet folgenden Ansichten:

### *Now Playing* 

![Now Playing View](docs/pics/playing.png) {#fig:playingview}

Die Ansicht (Abbildung @fig:playingview) stellt die Standardansicht dar. Hier werden Informationen zum
aktuell spielenden Lied und dem aktuellen Album angezeigt. Desweiteren sind
unter dem Cover aktuelle Statistiken. Die Tracklist neben dem Cover zeigt alle
weiteren Lieder auf dem selben Album. Das aktuell spielende Lied ist dabei
bläulich hervorgehoben. Lieder die nicht in der Queue sind werden ausgegraut
angezeigt.

![Now Playing Ansicht mit Lyrics](docs/pics/lyrics.png) {#fig:playingviewlyrics}

In der Ansicht (Abbildung @fig:playingviewlyrics) ist die Lyrics-Funktionalität sichtbar. Drückt man auf einen
,,gestreiften Button'' neben einem Lied in der Trackliste, so werden beim
Backend die entsprechenden Lyrics abgefragt und im erfolgsfall in einem Modalen
Dialog angezeigt. 

### *Queue*

![Queue View](docs/pics/queue.png) {#fig:queueview}

Die Queue (Abbildung @fig:queueview) stellt eine Abspielliste dar. In dieser
Liste befinden sich Lieder die aktuell angespielt werden sollen. Die Queue wird
bei anderen Musikplayern oft als ,,Playlist'' bezeichnet. 

Die Queue bietet die Möglichkeit der Volltextsuche. Zusätzlich kann die aktuelle
Queue als als *Stored Playlist* unter einem bestimmten Namen gespeichert
werden. Daneben gibt es noch einen ,,Clear all''--Button, welcher die gesamte
Queue leert.

Die Suche unterstützt Autovervollständigung. Nach Eingabe mindestens zweiten
Buchstaben wird versucht die Suchanfrage zu vervollständigen. Dies geschieht
indem ein Completion--Request an das Backend gesendet wird. Falls eine
Vervollständigung möglich ist antwortet dieser mit der vervollständigten
Suchanfrage.

Über die erweiterte Suchsyntax (TODO: ref) ist es möglich nur bestimmte
Attribute wie Titel, Genre, Artist oder Releasedate zu vervollständigen. So kann
man einfach ,,t:Nich'' eintippen und erhält als Vervollständigung
,,t:Nichtimgriff'' von Farin Urlaub.


### *Database*

![Database View](docs/pics/database.png) {#fig:databaseview}

Die Database View (Abbildung @fig:databaseview) zeigt alle dem MPD bekannten
Lieder an. Mittels der Suchfunktion kann die Datenbank gefiltert werden. Mittels
des ,,add visible''--Buttons (Auge--Icon) kann die gefilterte Liste direkt in
die Queue geladen werden. Mit dem ,,Plus''--Button können alle Lieder in die
Queue zum Abspielen geladen werden. Der Button ganz rechts (,,Circle--Arrow'')
bittet den MPD seine Datenbank, falls nötig, zu aktualisieren. Dies geschieht in
der Regel nur wenn neue Lieder der Datenbank hinzugefügt wurden.


### *Playlists*

![Playlist view](docs/pics/playlist.png) {#fig:playlistview}

Diese sehr einfache Ansicht (Abbildung @fig:playlistview) zeigt eine Liste von
vorhandenen *Stored Playlists*. Jede Playlist wird dabei als Button
dargestellt. Beim Drücken dieses wird die Playlist in die Queue geladen. Der
,,X''--Button bei jeder Playlist löscht diese.

### *Modale Dialoge*

![Modale Dialoge](docs/pics/modal_overview.png) {#fig:modaldialogs}

Zur weiteren Übersicht zeigt der Screenshot (Abbildung @fig:modaldialogs) die in
Snøbær vorhandenen Modalen Dialoge. 


# Architektur

![Grobübersicht Architektur](docs/pics/architektur.png) {#fig:architecture}

Die Abbildung @fig:architecture zeigt eine Grobübersicht der Architektur von Snøbær. Das
Backend spaltet sich in die zwei Teile auf. Das MPD--Backend erledigt die
Kommunikation mit dem MPD-Server, das Web--Backend implementiert das Protokoll
zwischen Frontend und Backend. Zudem leitet es Nutzereingaben vom Frontend an
das MPD--Backend weiter.

## Frontend

### Libraries

Das Frontend ist gänzlich in CoffeeScript geschrieben. Da wir vorher nur sehr
wenig mit Webprogrammierung zu tun hatten, hatten wir keine direkten Präferenzen
und entschieden uns für CoffeeScript aufgrund der einfachen, Python-ähnlichen
Syntax. Zudem eilte der Sprache der Ruf voraus viele problematische Aspekte von
JavaScript hinter einer angenehmen Syntax zu verstecken. Als Beispiel wäre hier
der *,,fat arrow''* von CoffeeScript zu nennen der im Hintergrund dafür sorgt
dass eine Variable die an eine Closure gebunden wird den Wert zur Zeit der
Bindung behält. In JavaScript ist dies oft umständlich und benötigt stets
Boilerplate--Code.

Für das Frontend wurde das Bootstrap CSS Framework mit jQuery verwendet.
Bootstrap erachten wir für unser Projekt als sinnvoll, da es viele Widgets und
Utility--CSS Regeln mit sich bringt,  die man sonst mühevoll per Hand selbst
designen müsste. Besonders die Möglichkeit von Bootstrap ,,Responsive Designs''
zu erstellen ist für unser Projekt wichtig, da die Zielplattform hier ein PC,
Tablet oder auch ein Smartphone sein könnte. 

Sollte das Display keine ausreichende Größe besitzen skaliert Snøbær (bzw.
Bootstrap) die Anwendung entsprechend. Die unteren Navigationsbarelemente werden
auch entsprechend neu geordnet, siehe dazu Abbildung @fig:small_screenshot.

![Snøbær auf mobilen Geräten](docs/pics/screenshot_small.png) {#fig:small_screenshot}

JQuery ist eine Abhängigkeit von Bootstrap, bietet aber für unsere Zwecke auch
gewisse Vorteile. So bietet es angenehmere Möglichkeiten zur DOM--Manipulation
und ermöglicht es einige ,,unschönen'' Seiten von JavaScript zu umgehen. 

Der Optik wegen wird statt des normalen Bootstrap--CSS das *,,Readable''*--Theme
von *Bootswatch* [^bootswatch_readable] eingesetzt.

[^bootswatch_readable]: `bootswatch-readable`: \url{https://bootswatch.com/readable/}

### Logik und Ablauf

Nachdem die Webseite vollständig per GET / ausgeliefert wurde, läuft der
JavaScript--Teil los. Hierbei wird neben allgemeiner Initialisierungsarbeit ein
Websocket zum Backend geöffnet. Beim Öffnen des Websockets wird automatisch ein
initiales Status--Update vom Backend ans Frontend geschickt. Das Frontend hat im
momentanen Prototypen weitestgehend keinen eigenen Zustand, das heißt, momentan
zeigt es relativ stupide die Daten an, welche es empfängt.

Ein großer Teil der Funktionalität steckt in der Klasse `MPDSocket`. Diese
erledigt das Verbinden zum Backend und das Entgegennehmen und Versenden von
Nachrichten. Die meiste Update--Logik ist an das Empfangen einer
Status--Nachricht gebunden. Diese wird initial beim Öffnen der Verbindung und
bei jeder Statusänderung des MPD vom Backend geschickt. Ereignisse die
Statusupdates bedingen sind beispielsweise: Das Weiterschalten des aktuellen
Liedes, das Ändern der Lautstärke (momentan noch nicht in Snøbær integriert)
oder das Verändern der Queue. Eine vollständige Liste dieser Events findet sich
in der MPD--Dokumentation[^mpddoc_eventspage]. 

[^mpddoc_eventspage]: MPD Eventliste bei `idle`: \url{http://www.musicpd.org/doc/protocol/command_reference.html}

Jedes Statusupdate aktualisiert die respektiven Widgets in allen Ansichten. Das
Aktualisieren kann unter Umständen weitere Nachrichten nach sich ziehen. So wird
nach dem Ändern des aktuellen Liedes eine Anfrage über ein Cover an das Backend
geschickt. (`BACKEND` ist die Instanz von `MPDSocket`).

```coffee
    if status['song-changed']
      BACKEND.send_metadata_request('cover', song)
```

Nach einiger Zeit führt dies zu einer `metadata` Nachricht, die wiederum eine
Änderung bestimmter Widgets verursacht. Die einzelnen Nachrichten die
ausgetauscht werden sind im nächsten Kapitel noch näher erklärt.

Die `Queue`, `Database` und `Playing` Ansicht nutzen beide die `PlaylistTable`--Klasse zur
Darstellung der Daten. Diese kapselt die gemeinsame Darstellung von Songs in
einer HTML--Table die dynamisch generiert wird. Zudem bietet sie Möglichkeiten
um die Clicks auf eine Row, bzw. das dazugehörige Icon, abzufangen und
weiterzureichen. 

Der Rest der Frontendlogik [^coffeescript_github] besteht aus relativ einfach nachvollziehbaren Update-
und Utilityfunktionen die hier nicht näher erklärt werden.

[^coffeescript_github]: CoffeeScript Source: \url{https://github.com/studentkittens/snobaer/blob/master/snobaer/static/js/logic.coffee}

## Websocket--Protokoll

Die Kommunikation über Websockets als Standard wurde gewählt weil, sich
hierdurch für unseren Einsatzzweck einige Vorteile gegenüber reinem HTTP
ergeben. Um beispielsweise die Liedposition auf dem Client ,,live'' darzustellen
müsste man bei HTTP permanent GET--Anfragen an den Server schicken. Websockets
hingegen bleiben permanent aktiv und ermöglichen eine direkte Kommunikation
zwischen Client und Server. Ein weiterer Vorteil ist, dass auch
Push--Notifications möglich sind und somit auf Polling verzichtet werden kann.

Die Kommunikation zwischen Frontend und Backend erfolgt über simple JSON
Nachrichten. Diese Nachrichten haben als gemeinsamen Nenner folgenden Header:


```coffee
{
  'type': 'command-name',
  'detail': 'subcommand'
}
```

Wo nötig kommen noch weitere Felder dazu. Wir entschieden uns gegen eine
umfangreichere Lösung wie JSON--RPC (bzw. vergleichbare Lösungen) um weitere
Abstraktion (und damit möglicherweise Performanceprobleme) sowie zusätzliche
Abhängigkeiten zu vermeiden. In Retrospektive wäre JSON--RPC allerdings
möglicherweise eine gute Ergänzung gewesen um ein gutes Stück unnötige
Fehlerbehandlung im Backend zu vermeiden.

### Frontend → Backend

Das Frontend kann prinzipiell vier verschiedene Nachrichten an das Backend
abschicken. Diese Nachrichtentypen sind im Einzelnen:

* **MPD:** Alle MPD Steuerkommandos wie `next`, `pause` etc.

```coffee
    # `command` is a libmoosecat client command.
    # Examples "('next', )" or "('play-id', 42)"
    {'type': 'mpd', 'detail': command}
```
    
Die Kommandos die im `detail` Feld angegeben sind haben ein spezielles String
Format, welches von ``libmoosecat`` (einer MPD--Client--Bibliothek, TODO ref)
vorgegeben wird. Das Format entspricht einem Python Tupel, bei dem der erste
Wert stets der Name des Kommandos ist. Falls nötig folgen noch weitere Parameter
mit bestimmten Typen. Die Signatur der einzelnen Kommandos muss momentan mangels
Dokumentation im Quellcode nachgesehen werden: [^moose_client]. 

``libmoosecat`` nutzt ``GVariant`` [^gvariant] zum Entpacken der einzelnen
Kommandos. Sollte die Signatur nicht passen wird eine Warnung im Log ausgegeben und das
Kommando ignoriert.

[^moose_client]: http://tinyurl.com/p5w3ljl
[^gvariant]: https://developer.gnome.org/glib/stable/gvariant-format-strings.html

TODO: Momentan wird kein escaping der commands im client betrieben

* **Completion:** Vervollständigung einer Suchanfrage.

```coffee
    # `query` is a user given query. 
    # Example: `t:Nich` should be completed to `t:Nichtimgriff`
    {'type': 'completion', 'detail': query}
```

* **Metadata:** Abfrage von Coverart, Lyrics oder prinzipiell auch anderen Metadaten.

```coffee
    {
        # type may be <cover>, <lyrics>, ... (See `glyrc -L` for a list)
        'type': 'metadata', 'detail': type,
        'artist': song.artist, 'album': song.album, 'title': song.title
    }
```

* **Store:** Abfrage der `libmoosecat` Datenbank mittels Volltextsuche.

```coffee
    {
        # `queue-only`: 
        # `detail`: Which resource to query.
        # `target`: Copied to the response by the backend.
        # `query`: The query.
        # `add-matches`: If true, do not respond, but add 
        #                those songs directly to the queue.
        'type': 'store',
        'detail': if queue_only then 'queue' else 'database',
        'target': target,
        'query': query,
        'add-matches': add_matches
    }
```

### Backend → Frontend

Das Backend kann prinzipiell vier verschiedene Nachrichten an das Frontend
abschicken. Diese Nachrichtentypen sind im Einzelnen:

* Heartbeat: Zeitansage für das Frontend. Gibt an wieviel Zeit im aktuellen Lied
  vergangen ist.

```coffee
    {
        'type': 'hb',
        'perc': 66,
        'repr': '1:06/1:40'
    }
```

  Diese Nachricht wird (momentan) alle 500ms gesendet. Zwar könnte das Frontend
  diese Zeitinformationen selbst interpolieren, doch stellte sich in der Praxis
  dabei raus, dass sich immer eine gewisser *,,Lag''* in die Berechnung mit
  einschlich. Daher wurde mit ``Heartbeat`` eine Python--Klasse implementiert, die
  auf Anfrage die vergangene Zeit recht genau abschätzt[^snobaer_heartbeat]. 

  [^snobaer_heartbeat]: `heartbeat.py`: \url{https://github.com/studentkittens/snobaer/blob/master/snobaer/heartbeat.py}

* **Status**:  Allgemeine Statusinformationen zu allen MPD Funktionen. Diese Nachricht ist relativ umfangreich, umfasst aber alle Informationen die das
  Frontend (in Zukunft) benötigt. Um Bandbreite zu sparen wird die Statusnachricht nur
  ausgelöst wenn ein MPD--Event passiert ist.

```coffee
    {
      "type" : "status",
      "status" : {
        # Playing state: paused, playing, stopped.
        "state" : "playing",
        # Id of a song is unique, pos is the song's index in the queue.
        "song-id" : 328, "song-pos" : 109,
        "next-song-id" : -1, "next-song-pos" : -1,
        # Did the song changed compared to last status?
        "song-changed" : true, 
        # Does the queue/database need an update?
        "list-needs-update" : false,
        # Events that happened:
        "events" : [
          "player"
        ],
        # Current song:
        "song" : {
          "artist" : "In Extremo", "album" : "7", "title" : "Erdbeermund",
          "genre" : " Medieval Rock",
          "id" : 328, "uri" : "In_Extremo_7_Erdbeermund.ogg"
        },
        # List of playlist names:
        "playlists" : [
          "test1", "test2", "Neu"
        ],
        # Current song information:
        "total-time" : 122, "queue-length" : 110,
        "kbit-rate" : 0, "elapsed-ms" : 33, "crossfade" : 0, "volume" : -1,
        # Statistics:
        "number-of-artists" : 7, "number-of-albums" : 8, "number-of-songs" : 109,
        "db-update-time" : 1432976371, "uptime" : 156, "update-id" : 0,
        # Playback settings:
        "random" : false, "single" : false, "consume" : false, "repeat" : false,
        "mixrampdb" : 0, "mixrampdelay" : -1, "replay-gain-mode" : "",
        # Audio information:
        "audio-sample-rate" : 44100, "audio-bits" : 0, "audio-channels" : 0,
      },
      # Table of output names and if they're enabled:
      "outputs" : {
          "alsa": true
      }
    }
```

* **Completion Answer:** Antwort auf ein Completion Request (falls erfolgreich).
  Falls nicht erfolgreich, wird die Anfrage nicht beantwortet um Bandbreite zu
  sparen. Die Antwort entspricht dem Request, nur mit zusätzlichen ``'result'``
  Feld.

```coffee
    {
        'type': 'completion', 'detail': query, 'result': query + completion
    }
```

* **Playlist:** Liste aus Songs. Diese Antwort ist die Rückgabe der
  ``store``--Anfragen. Nicht alle möglichen und vorhandenen Song--Metadaten (wie
  Musicbrainz--ID etc.) werden mitgeliefert um Bandbreite bei großen Playlisten
  zu sparen.

```coffee
    {
        'type': 'store',
        'detail': 'database',
        'target': 'playing-view',
        'songs': [{
            'artist': 'Udo Jürgens',
            'album': 'Aber bitte mit Sahne 1+2',
            'title': 'Aber bitte mit CoffeeScript',
            'genre': 'Schlager',
            'id', 42,
            'uri' 'file://Udo/BestOf/song1.mp3'
        }, {
            # ...
        }]
    }
```

* **Metadata:** Antwort auf ein Metadata-Request. Bei Songtexten werden Texte in
  der ``results``--Liste mitgeliefert, bei Coverart werden die Links zu den
  Bildern mitgeliefert. Eine Verbesserung wäre hier einen lokalen Link
  zurückgeben, damit Snøbær auch ohne Internetzugang Coverart anzeigen kann ---
  sofern das Cover bereits gecached wurde.

```coffee
    {
        'type': 'metadata',
        'detail': type,
        'results': ['text_or_imagelink_2', 'text_or_imagelink_2']
    }
```

## Backend

Das Backend besteht aus zwei Teilen. Zum einen der Kommunikationsteil der mit
dem Frontend spricht und der ,,hintere'' Teil des Backends, welcher die
Verbindung zum MPD betreut.

### Web--Backend

TODO: pip requirements.

Das Kernstück zur Kommunikation bildet `Tornado`, der asynchrone Python
Webserver. Dieser eignet sich für unsere Zwecke vor allem aufgrund der
Python3--Kompatibilität und seiner relativ hohen Performance. 

`Flask` wird aufgrund seiner Modularität und Erweiterbarkeit als allgemeines
Web--Framework verwendet. Damit `Tornado` (asynchron) und `Flask` (synchron)
zusammenarbeiten können, bietet `Tornado` einen WSGI--Container um alle Anfragen
die nicht direkt von `Tornado` bearbeitet worden an `Flask` weiterzuleiten.
Konkret behandelt `Tornado` bei uns nur alle Websocketanfragen, alle anderen
Anfragen werden über WSGI direkt an `Flask` weitergeleitet. 

Als problematisch stellte sich noch die Existenz zweier verschiedener Mainloops
heraus. `libmoosecat` nutzt den weit verbreiteten GLib--Mainloop (TODO: Link)
während Tornado einen eigenen Mainloop nutzt. Letzterer bietet zwar eine
Integration für viele andere Mainloops--Implementationen, GLib ist aber nicht
dabei. Daher wurde nach kurzer Suche der Code unter
TODO https://gist.github.com/schlamar/8420193 unseren Zwecken angepasst. Er wurde zu
PyGObject portiert und ein paar kleinere Bugfixes wurden eingebracht.
Dieser Mainloop ist ein Adapter der kompatibel zur `Tornado`--IOLoop API, nutzt
aber intern den `GLIb`--Mainloop.

**Sourcecode--Layout:**

```bash
    snobaer
    +-- templates        # Jinja2 templates.
    |   +-- index.html   # Main player page.
    |   \-- sysinfo.html # Sysinfo modal dialog.
    +-- static           # Static content.
    |   +-- css          # css files (symlink to bower package files).
    |   +-- fonts        # fonts (glyphicons for bootstrap).
    |   \-- js           # js files (logic.coffee + symlinks to bower files).
    +-- config.py        # General purpose YAML-Config.
    +-- protocol.py      # Frontend<->Backend protocol.
    +-- heartbeat.py     # Heartbeat (Time interpolation).
    +-- backend.py       # Tornadoserver and intitialization.
    +-- mainloop.py      # Tornado-compatible GLib mainloop.
    +-- logger.py        # Colorful logging with nice unicode symbols.
    +-- metadata.py      # Metadata retrieval helpers.
    +-- web.py           # All Flask related code.
    +-- zeroconf.py      # Discovery code for MPD servers on the network.
    +-- fs.py            # Utilities for creating .config/.cache dirs.
    +-- __main__.py      # Main methods and commandline parsing.
    \__ __init__.py      # It's a package.
```

### MPD--backend

Da Herr Pahl bereits als Nebenprojekt eine freie C--Bibliothek zur einfachen
Kommunikation mit dem MPD geschrieben hat bot es sich an diese, trotz des
relativ frühen Entwicklungsstandes, zu nutzen. 

Die meisten Client--Bibliotheken für den MPD (Beispiele: ``libmpdclient``,
``python-mpd2``) implementieren nur das eigentliche Protokoll. Sie stellen also
eine Bibliothek bereit um MPD--Clients zu schreiben, während ``libmoosecat``
eine Bibliothek ist, die einen MPD--Client implementiert. Das hat den Vorteil,
dass die gesamte, doch recht komplizierte, Fehlerbehandlung und Kommunikation in
auf gemeinsamen Code-Basis basiert die definierte Schnittstellen nach außen
bietet.

``libmoosecat`` baut auf ``libmpdclient`` auf um folgende Features zu ermöglichen:

- Konsistente API zu den wichtigsten MPD--Funktionen ohne sich mit dem
  historisch gewachsenen Protokoll auseinander setzen zu müssen (TODO: link)
- Synchrone und asynchrone Kommunikation mit dem Server.
- SQLite Zwischenspeicher der Datenbank um Daten nur einmal im Speicher halten
  zu müssen und um das erneute Starten zu beschleunigen.
- Eine erweitere Syntax zum Abfragen der Ergebnisse (ermöglicht einfache
  Volltextsuche).
- Effiziente Autovervollständigung mittels Patricia-Tries.
- Integration von ``libglyr`` (Eine weitere Bibliothek von Herrn Pahl TODO)
- Zeroconf search: MPD Server können automatisch im Netz gefunden werden, ohne
- In Arbeit: Gtk+-3.0 Integration um eine sehr schnelles Playlistwidget zum
  Darstellen großer Datenbanken bereitzustellen, welches sich bereits beim
  Eintippen der Suchanfrage aktualisiert.

Für dieses Projekt musste allerdings noch ein Python--Wrapper realisiert werden
um das in C geschrieben ``libmoosecat`` komfortabel von Python aus nutzen zu
können. Vorher existierte bereits ein rudimentärer Cython--Wrapper, der
allerdings viel Handarbeit und Fehlersuche benötigte. Daher begann Herr Pahl 
``libmoosecat`` vor einiger Zeit auf ``GObject`` (TODO: Erklärung) Basis
umzuschreiben. ``GObject`` ist ein Objektsystem für die eigentlich nicht
objektorientierte Programmiersprache ``C``. Der Umbau zu ``GObject`` wurde
jedoch durch andere Projekte und Tätigkeiten unterbrochen, daher bot Snøbær eine
gute Gelegenheit die Arbeit wieder aufzunehmen.

Das hat nicht nur den Vorteil, dass die Bibliothek jetzt
konsistent Objekte nutzt, sondern diese Objekte können auch mittels
,,Introspection'' von anderen Sprachen benutzt werden. Dazu bedarf es pro
Sprache nur ein gemeinsames Modul welches zwischen ``GObject`` und den
Sprachinternas vermittelt. Bei Python ist dieses Modul ``PyGobject``. Die eigentlichen Bindings
zu ``libmoosecat`` können dann auf sehr einfache Art aus den C-Headerdateien
generiert werden [^Introspection_header].

Diese daraus gelesen Informationen (ein sogenanntes
``gi-repository``)  können dann von ``pygobject`` gelesen werden. Diese
Informationen umfassen beispielsweise welche Funktionen und Methoden exportiert
werden sollen und ob der Aufrufer eine Referenz auf den Rückgabewert hält oder
ob er eine volle Kopie davon hat.

[^introspection_header]: https://github.com/studentkittens/moosecat/blob/master/lib/mpd/moose-mpd-client.h#L201

Auch viele andere ``GObject`` basierte Bibliotheken sind über diese
Schnittstelle angebunden. Ein prominentes Beispiel ist ``Gtk+``.

**Einsatz:** Ist ``libmoosecat`` installiert kann man es von Python aus benutzt werden: 

```python
>>> from gi.repository import Moose
>>> client = Moose.Client.new(Moose.Protocol.DEFAULT)
>>> client.connect_to(port=6666)
>>> client.send_simple('next')  # Actually sends "('next', )"
```

``Introspection`` ist sehr angenehm, aber nicht perfekt. So nutzen noch manche Teile
der API noch `C`--Idiome die in `Python` unüblich sind (*Outparameter*
beispielsweise). Um diesen Misstand zu beheben wurde auch ein
``override``--Modul entwickelt[^override_module], das diese Teile der API *,,Pythonic''* macht
indem es bestimmte Methoden überschreibt.

[^override_module]: https://github.com/studentkittens/moosecat/blob/master/lib/Moose.py

## Suchsyntax

Die freie SQL--Datenbank ``SQLite3`` unterstützt Volltextsuche. Dazu
implementiert die mitgelieferte ``fts3``--Erweiterung (*f*ull *t*ext *s*earch) eine spezielle
``MATCH``--Klausel. Als Argument übergibt man dieser einen String in einer
bestimmten Syntax. Diese Syntax entspricht im einfachsten Falle einen simplen
Suchbegriff der dann in allen Spalten der Datenbank gesucht wird. Zudem können
spezielle Spalten ausgewählt werden und verschiedene Ausdrücke mit den `` AND ``, 
`` OR `` und `` NOT `` verbunden werden. Auch können Ausdrücke geklammert
werden um doppeldeutige Reihenfolgen eindeutig zu machen. Auch sind Wildcards
möglich um nur den Anfang eines Strings zu matchen.

Die genaue Beschreibung der Syntax findet sich hier: 

    https://www.sqlite.org/fts3.html

Am Beispiel einer Musikdatenbank kann ein Ausdruck etwa so aussehen:

```bash
    (artist:Knorkator OR album:"Hasen*") AND (artist:knor OR album:knor OR
    album_artist:knor OR title:knor) AND genre:rock AND NOT (date:2001 OR
    date:2002 OR date:2003)
```

Das ist natürlich für einen normalen Anwender eher schwer zu tippen oder zu
lesen. Daher verwendet ``libmoosecat`` eine alternative Syntax, die einfacher
zu tippen ist. Vor einer Datenbankabfrage wird diese dann automatisch in eine
kompatible `MATCH`--Klausel kompiliert.

Der obige Ausdruck kann mit dieser Syntax von oben so umgeschrieben werden:

```bash
    (a:Knorkator | b:"Hasen*") + knor g:rock ! d:2001-2003
```

Im Detail wird ``AND`` mit ,,``+``'', ``OR`` mit ,,``|``'' ersetzt und ``NOT`` mit
,,``!``''. Die Spaltennamen erhalten jeweils Abkürzungen, so wird beispielsweise aus
den längeren ``artist:SomeArtist`` das kürzere ``a:SomeArtist``. 
Einzelne Begriffe wie ``a`` werden zu ``(artist:a OR album:a OR album_artist:a
OR )`` ersetzt, da eine Suche in anderen Spalten wenig Sinn macht oder
ungewollte Ergebnisse liefert. Bei der ``date:`` Spalte soll es zudem möglich
sein einen Bereich anzugeben. Eine Bereichsuche ist zwar in der Volltextsuche
nicht vorgesehen, kann aber (ineffizient) emuliert werden indem für jede Zahl in
diesem Bereich ein ``date:<zahl>`` Begriff eingefügt wird. Siehe dazu das
Beispiel oben.

| **Attribut**   | **Abkürzung** | **Beschreibung**             |
|----------------|---------------|------------------------------|
| `artist`       | `a`           | Künstler                     |
| `album`        | `b`           | Albumtitel                   |
| `album_artist` | `c`           | Künstler des gesamten Albums |
| `title`        | `t`           | Songtitel                    |
| `genre`        | `g`           | Genre                        |
| `disc`         | `s`           | Disknummer                   |
| `duration`     | `d`           | Dauer in Sekunden            |
| `date`         | `y`           | Releasedatum                 |
| `track`        | `r`           | Tracknummer                  |
| uri            | u             | Songpfad                     |

# Entwicklungsumgebung

## Tests

test mpd server.

## Inbetriebnahme via Docker

Da ``libmoosecat`` momentan nur mit Insiderwissen ordnungsgemäß kompiliert
werden kann haben wir einen Docker--Container vorbereitet in dem das Backend
bereits vorinstalliert ist. Aufgrund einiger unglücklicher Umstände ist die
Größe des Containers auf 2GB gestiegen. Wir bitten dies zu entschuldigen.

Der Container kann folgendermaßen in Betrieb genommen werden: 

```bash
$ docker pull sahib/snobaer
$ docker run -p 6666:6666 -p 8080:8080 sahib/snobaer /bin/sh /start.sh
```

Sollte alles geklappt haben kann die Weboberfläche unter
``http://localhost:8080`` aufgerufen werden. Im Container ist ebenfalls der
MPD--Testserver enthalten, der mit einem gewöhnlichen MPD--Client ihrer Wahl
gesteuert werden kann. Eine Änderung im einen Client sollte wie gesagt auch eine
Änderung in Snøbær bewirken und umgekehrt.

Da der Testserver immer die selbe leere Audiodatei abspielt (und noch zusätzlich
der Audio-Output nicht aus dem Container geleitet wird) wird man beim Rumspielen
mit Snøbær keinen Sound hören.

Unter Umständen müssen nach dem Starten noch Songs aus der Datenbank zur Queue
hinzugefügt werden bevor etwas abgespielt werden kann.

## Developement Tools

bower, make file, coffee lint

# Fazit

## Known Bugs
    
- Einige Memory leaks (hauptsächlich durch Python Wrapper bedingt, da
  falsches refcounting). Momentan werden etwa 10kb bei einer Suchoperation
  verloren da der Container mit den Songreferenzen nicht bereinigt wird.
    
  Lösung: Umfangreiches Leaktesting ()

- Noch relativ langsam, da bei jedem Songwechsel die Queue refresht wird.
  Für einen Prototypen sollte die Performance allerdings ausreichen.

  Lösung: Updates der Queue nach Möglichkeit vermeiden. Beispielsweise beim
  Songwechsel einfach einen anderen Song highlighten und die highlight
  Klasse des alten Songs entfernen.

- Sollte ein Song doppelt in der Queue doppelt vorhanden sein, wird er auch
  doppelt gehighlighted falls er abgespielt wird.

  Lösung: die zu highlightende row anhand der queue position bestimmten,
  nicht der song id.

- Gelegentliche crashes, ebenfalls durch reference counting verursacht.

  Lösung: Viele Stunden Debugging und Tests.
      
## Mögliche Erweiterungen und Verschönerungen

Liste der Erweiterungen fast länger als die restliche Arbeit.
Moosecat und co. bieten prinzipiell weitaus mehr Features als im Frontend
realisiert wurden.

- Tests. 
- Filterbare *stored playlists*.
- Einbau von *libmunin*
- Dateibrowser für die Datenbankansicht.
- Support um zu mehreren MPD Servern zu connecten.
  Momentan muss der MPD Server beim Starten des Backends angegeben werden. 
  Stattdessen könnte man im Frontend erst eine Auswahlmaske zeigen und dann
  jeweils einen Worker im Backend für einen bestimmtes Backend zu instanziieren.
  Zudem wäre etwas Locking--Arbeit vonnöten um zwei separate Zugriffe auf den
  gleichen MPD--Server zu erlauben (momentan eine gemeinsame sqlite datenbank)

- Momentan gibt das backend nur den link zur coverart zurück, um auch
  offline arbeiten zu können sollte es aber einen link in der art von
  ``<Snøbær-host>/metadata/cover/<artist>/<title>`` zurückgeben. Bei einem
  GET auf diesen Link holt der Flask Teil das Coverart aus dem Cache und
  liefert es aus.

## Abschliessendes Resume

Snøbær war unser erster ,,richtiger'' Ausflug in die Webprogrammierung. Vorher
hatten wir mit dem Web nur am Rande zu tun (Katzen auf Imgur anschauen). Auch
wenn wir den Eindruck hatten dass die Webprogrammierung oft leicht chaotisch und
,,hacky'' wirkt (häufiges CSS--Gefrickel etc.) ließ sich in recht kurzer Zeit
ein funktionierender Prototyp entwickeln. Dank des modularen Ansatzes von Flask,
ließ sich das Framework um die gewünschte Funktionalität ,,recht einfach''
erweitern. Die Kombination für das Backend mit Tornado funktioniert soweit gut,
jedoch wäre an dieser Stelle womöglich eine ,,simplere'' Lösung wünschenswert
die sich mit nur einem Framework realisieren lässt. 

TODO: GObject vs. Cython, hohe Lernkurve aber sehr performante Kombination.
