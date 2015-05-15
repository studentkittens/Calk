# TODO: Reduce visibility of some of those?
VIEWS = ['database', 'playing', 'queue']
SERVER_URL = "ws://localhost:8080/ws"
WEBSOCKET = null

view_switch = (name) ->
  class_name = '#view-' + name
  for view in VIEWS
    view_name = ('#view-' + view)
    elem = $(view_name)
    if view_name == class_name then elem.show() else elem.hide()

#####################
#  STATUS UPDATING  #
#####################

update_play_modes = (status) ->
  states ={
    'repeat': status.repeat, 'random': status.random,
    'single': status.single, 'consume': status.consume
  }
  for name, state of states
    $('#btn-' + name).toggleClass('btn-info', state)

update_progressbar = (status) ->
  elapsed_sec = status['elapsed-ms'] / 1000.0
  total_sec = status['total-time']
  pg = $('#progressbar>div')

  percent = 0
  if total_sec == 0
    percent = 100
    pg.addClass('progress-bar-striped')
  else
    percent = (elapsed_sec / (total_sec * 1.0)) * 100
    pg.removeClass('progress-bar-striped')

  pg.attr('aria-valuenow', percent)
  pg.css('width', percent + '%')

  song = status.song
  $('#footer-song-title').html('<em>' + song.artist + '</em> - ' + song.title)

update_play_buttons = (status) ->
  active = (status.state == 'playing')
  $('#btn-pause').toggleClass('btn-info', active)
  $('#btn-pause>span').toggleClass('glyphicon-play', active)
  $('#btn-pause>span').toggleClass('glyphicon-pause', not active)

update_view_playing = (status) ->
  if status.song != {}
    song = status.song
    $('#view-playing-artist').html(song.artist or 'None')
    $('#view-playing-album').html(song.album or 'None')
    $('#view-playing-title').html(song.title or 'Not playing')

    # TODO: add song-changed flag.
    if status.events != undefined and 'player' in status.events
      console.log("Sending cover request")
      WEBSOCKET.send(JSON.stringify({
        'type': 'metadata',
        'get_type': 'cover',
        'detail': 'view-playing',
        'artist': song.artist,
        'album': song.album,
      }))
    
      # Set the default no cover:
      $('#cover').attr('src', '/static/nocover.jpg')

update_view_cover = (metadata) ->
  if metadata.urls
    $('#cover').attr('src', metadata.urls[0])

#####################
#  WEBSOCKET STUFF  #
#####################

on_socket_open = (msg) ->
  console.log(msg)

on_socket_close = (msg) ->
  console.log(status)

on_socket_message = (msg) ->
  console.log('receive', msg)
  update_data = JSON.parse msg.data

  switch update_data.type
    when 'status'  # Status update.
      status = update_data.status
      update_play_modes(status)
      update_progressbar(status)
      update_play_buttons(status)
      update_view_playing(status)
    when 'metadata'
      update_view_cover(update_data)
    else
      console.log('Unknown message type: ', update_data.type)

#########################
#  MPD COMMAND HELPERS  #
#########################

mpd_send = (command) ->
  WEBSOCKET.send(JSON.stringify({
    'type': 'mpd',
    'detail': command
  }))


mpd_send_simple = (command) ->
  mpd_send "('#{command}', )"

#######################################################
#  MAIN (or how main-y you can go with CoffeeScript)  #
#######################################################

$ ->
  # Hide the database and queue by default.
  $('#view-database').hide()
  $('#view-queue').hide()

  # Make views switchable:
  for view in VIEWS
    do (view) ->
      $('#switch-' + view + '-view').click -> view_switch(view)

  # Connect the menu entries:
  $('#menu-about').click ->
    # TODO
    bootbox.confirm("Are you sure?", (result) ->
      Example.show("Confirm result: "+result)
    )
  
  for action in ['previous', 'stop', 'pause', 'next']
    do (action) ->
      $('#btn-' + action).click ->
        mpd_send_simple(action)

  # Also connect the state toggling buttons:
  for action in ['random', 'repeat', 'consume', 'single']
    do (action) ->
      $('#btn-' + action).click ->
        is_active = $(this).hasClass('btn-info')
        mpd_send("('#{action}', #{not is_active})")

  # Connect the event socket:
  # socket = create_websocket
  WEBSOCKET = new WebSocket SERVER_URL
  WEBSOCKET.onopen = on_socket_open
  WEBSOCKET.onclose = on_socket_close
  WEBSOCKET.onmessage = on_socket_message
