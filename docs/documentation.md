---
documentclass: scrartcl
title: Der Webmpd-Client Snøbær
author: Christopher Pahl und Christoph Piechula
toc: yes
date: \today
---

# Vorwort

## Einleitung

Das Ziel der der Studienarbeit ist es eine Software mit einem Python
Webframework umzusetzen. Aus persönlichen Interesse haben wir uns für einen
Music Player Client (kurz MPC) entschieden. 

Der Music Player Daemon (kurz MPD) ist eine unter unixoiden Betriebssystemen
beliebte Software um Musik mittels einer Client/Server--Architektur abzuspielen.
Der Server verwaltet dabei die komplette Datenbank samt Metadaten, der Client
hingegen dient lediglich als ,,Fernbedienung'' und zeigt oft noch Coverart und
weitere Daten an. 

Auf der offiziellen MPD--Seite (TODO: link) gibt es eine Liste aller verfügbaren
MPD--Clients --- es sind mittlerweile über 200. Darunter sind auch einige
Webbasierte Clients, wie ympd, Volumino (Debian basierend) oder RuneOS
(Archlinux basierend). Die beiden letzteren sind sogar vollwertige
HiFi-Audioplayer Linux--Distrubitionen mit den Raspberry Pi als
Hauptzielplattform. Leider sind diese relativ groß und komplex und auch noch in
PHP geschrieben. ympd ist hingegen in C geschrieben und kommuniziert mittels
Websockets mit dem auf Bootstrap basierten Javascript Frontend. 

## Zielsetzung

Das Ziel unseres Projekt ist es nun eine Mischung beider Welten herzustellen.
Zum einen soll der Client in C geschrieben sein, zudem groß und fett. Nein,
Scherzle macht. Das eigentliche Ziel der Arbeit ist es einen MPD-Client zu
schaffen welcher leichtgewichtig wie ympd ist und den Komfort von Volumio/RuneOS
bietet und zusätzlich plattformunabhängig ist.

Da der Audiosetup in unserer Wohngemeinschaft auf einem Raspberry PI basiert,
ist es zudem wünschenswert, dass das Backend relativ ressourcenschonend ist um
den recht begrenzten Arbeitsspeicher des Rechners (256MB) nicht zu überfüllen. 

## Namensgebung und Logo

Da es in letzter Zeit hipp ist, Früchte in technische Produktnamen zu
integrieren (Raspberry Pi, Bananna Pi, ...) springen wir nun auf diesen Zug auf
und bedienen uns diesem Schema. Da es um Musik geht und die Software
auf einem Raspberry Pi laufen soll haben wir uns hier für ,,Knallerbsen'',
hochdeusch Schneebeeren, entschieden. Um parallel den Unicode--Support in der
Welt zu verbessern und nördig zu wirken bedienten wir uns zudem der nordischen
Sprache und übersetzten Schneebeere auf Norwegisch: Snøbær.

# Grundlagen: Music Player Daemon und seine Clients

Um einen Musicplayer zu entwickeln eignet sich ein MPC besonders, da man nicht
das Rad neu erfinden muss. Der MPD bringt bereits die meisten Funktionalitäten
und Konzepte aus anderen Musicplayern mit. Er kann bereits alle gebräuchlichen
Formate einlesen und auf viele Audiobackends ausgeben. Zudem ist er sehr robust
und spielt auch zuverlässig bei hoher Systemlast noch Musik ab --- im Gegensatz
zu Amarok wo die Systemlast durch das Abspielen erst generiert wird.

TODO: MPD Architektur Bild.

Die meisten MPD-Konzepte sind bereits aus anderen Musikplayern bekannt, werden
aber hier noch kurz erwähnt:

* Sämtliche Songs werden in der *Database* gespeichert.
* Songs werden zum abspielen in die *Queue* geladen, wo sie der Reihe nach
  abgespielt werden.
* Der Inhalt der *Queue* kann als *Stored Playlist* unter einem Namen
  abgespeichert werden und zu einem späteren Zeitpunkt wieder geladen werden.
* Clients sprechen mit dem MPD über ein definiertes Textprotokoll (TODO: Link) 
* Es sind mehrere Audioausgaben möglich, darunter ALSA, Pulseaudio oder auch ein
  HTTP Stream. Zudem lassen sich die Qualitätseinstellungen detailiert anpassen
  (libsamplerate etc) weswegen er bei audiophilem Publikum sehr beliebt ist.

Da der MPD netzwerkfähig ist können sich mehrere Clients auf ihn schalten und
den ,,Zustand" des Servers ändern (wie beispielsweise das aktuell spielende
Lied). Man hat pro Server einen gemeinsamen Zustand, welcher von den Clients
widergespiegelt wird. Sollten mehrere  Zustände gewünscht sein, so kann man seit
MPD 0.19 zusätzlich Proxy--Server einrichten, die selbst als Clients des
Haupt--,,Servers'' fungieren, aber einen eigenen Zustand besitzen:

TODO: Grafik

Dieses Prinzip wird beispielsweise in unserer Wohngemeinschaft genutzt um die
Metadaten der Musiksammlung durch einen Hauptserver zu verwalten, der selbst
keine Audioausgabe besitzt, dafür aber Zugriff auf die Musikdaten hat. Auf jedem
abspielfähigem Gerät befindet sich dann ein Proxyserver, welcher die Metadaten
des Hauptservers spiegelt und vom Nutzer des Rechners mittels eines MPD--Clients
gesteuert werden kann. 

# Aufbau von Snøbær

Snøbær folgt generell den Konzepten von MPD. Es bietet verschiedene Ansichten
die in der oberen Navigationsbar umgeschaltet werden können:

## Ansichten:

### *Now Playing* 

* Screenshot

### *Queue*

* Screenshot

### *Database*

* Screenshot

### *Playlists*

* Screenshot

### *Menu*

* Screenshot

# Architektur


* Diagramme mit Onlinetool

## Frontend

Das Frontend ist gänzlich in CoffeeScript geschrieben. Da wir vorher nur sehr
wenig mit Webprogrammierung zu tun hatten, hatten wir keine direkten Präferenzen
und entschieden uns für CoffeeScript aufgrund der einfachen, Python-ähnlichen
Syntax. Zudem eilte der Sprache der Ruf voraus viele problematischen Aspekte von
JavaScript hinter einer angenehmen Syntax zu verstecken. Als Beispiel wäre hier
der *,,fat arrow''* von CoffeeScript zu nennen der im Hintergrund dafür sorgt
dass eine Variable die an eine Closure gebunden wird den Wert zur Zeit der
Bindung behält. In JavaScript wird dies etwas umständlich

* Views
* JS
* Weitestgehend keinen eigenen Zustand/Spiegelt nur Zustand des Servers wieder

## Backend

Das Backend besteht aus zwei Teilen. Zum einen der Kommunikationsteil der mit
dem Frontend spricht und der ,,hintere'' Teil des Backends, welcher die
Verbindung zum MPD betreut.

Da Herr Pahl bereits als freies Nebenprojekt eine C--Bibliothek zur einfachen
Kommunikation mit dem MPD geschrieben hat bot es sich an diese zu nutzen. Die
meisten Client--Bibliotheken für den MPD (Beispiele: ``libmpdclient``,
``python-mpd2``) implementieren nur das eigentliche Protokoll. Sie stellen also
eine Bibliothek bereit um MPD--Clients zu schreiben, während ``libmoosecat``
eine Bibliothek ist, die einen MPD--Client implementiert. Das hat den Vorteil
die gesamte, doch recht komplizierte, Fehlerbehandlung und Kommunikation in
einer gemeinsamen Code-Basis zu haben die definierte Schnittstellen nach außen
bietet.

``libmoosecat`` baut auf ``libmpdclient`` um folgende Features zu ermöglichen:

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
umzuschreiben. Das hat nicht nur den Vorteil, dass die Bibliothek jetzt
konsistent Objekte nutzt, sondern diese Objekte können auch mittels
,,Introspection'' von anderen Sprachen benutzt werden. Dazu bedarf es pro
Sprache nur ein gemeinsames Modul welches zwischen ``GObject`` und der Sprache
vermittelt. Bei Python ist dieses Modul ``pygobject``. Die eigentlichen Bindings
zu ``libmoosecat`` können dann auf sehr einfache Art aus den C-Headerdateien
generiert werden. Diese daraus gelesen Informationen (ein sogenanntes
``gi-repository``)  können dann von ``pygobject`` gelesen werden. Diese
Informationen umfassen beispielsweise welche Funktionen und Methoden exportiert
werden sollen und wem der allokierte Speicher gehört bzw. ob der Aufrufer eine
Referenz auf das Objekt hält (sowohl GObject als auch Python besitzen ein
referenzzähler-basiertes Speichermodell).

Auch viele andere ``GObject`` basierte Bibliotheken sind über diese
Schnittstelle angebunden. Ein prominentes Beispiel ist ``Gtk+``.

Ist ``libmoosecat`` installiert kann so von Python aus benutzt werden: 

```python
>>> from gi.repository import Moose
>>> client = Moose.Client.new(Moose.Protocol.DEFAULT)
>>> client.connect_to(port=6666)
>>> client.send_simple('next')
```

Für diese Arbeit wurde die Portierung auf ``GObject``, welche durch andere
Projekte unterbrochen wurde, vervollständigt und es wurden entsprechende
Header--Kommentare hinzugefügt (TODO: Beispiellink). Zudem wurde ein sogenanntes
``override``--Modul bereitgestellt, welches die API ,,Pythonic" macht und
typische C--Konstrukte wie Output--Parameter versteckt.

# Python Anteil


* Python
* C

## Verwendete Bibiotheken

    * Tornado, Flask, Bootstrap
    * libmoosecat, glyrc

Warum diese Bibiotheken? 

# Entwicklungsumgebung

* Verwendete Tools
* Tests
* Inbetriebnahme (Docker)

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
      
## Mögliche Erweiterungen und Verschönerungen

Liste der Erweiterungen fast länger als die restliche Arbeit.
Moosecat und co. bieten prinzipiell weitaus mehr Features als im Frontend
realisiert wurden.

- Tests. 
- Filterbare stored playlists.
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

## Abschliessendes Resume (Aufteilung in 3 Codebasen sinnvoll? Nein doch oh!)

Snøbær war unser erster ,,richtiger'' Ausflug in die Webprogrammierung. Vorher
hatten wir mit dem Web nur am Rande zu tun.
Auch wenn wir den Eindruck hatten dass die Webprogrammierung oft leicht
chaotisch und ,,hacky'' wirkt (häufiges CSS Gefrickel etc.) ließ sich in recht
kurzer Zeit ein funktionierender Prototyp entwickeln.
