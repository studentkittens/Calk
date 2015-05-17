#############
#  GLOBALS  #
#############

# TODO: Reduce visibility of some of those?
VIEWS = ['database', 'playing', 'queue']
SERVER_URL = "ws://localhost:8080/ws"
WEBSOCKET = null

class PlaylistTable
  constructor: (
    table_id, @glyphicon='align-justify',
    @fn_row=null, @fn_menu=null) ->
    @old_table = $(table_id)
    @old_table.html('')
    @table = @old_table.clone(false)
    @header_row = document.createElement('tr')
    @table.append(@header_row)
    @aligns = []

    if @glyphicon
      this.add_header('')

  add_header: (name, align='left') ->
    header = document.createElement('th')
    header.className = ' text-' + align
    header.appendChild(document.createTextNode(name))
    @header_row.appendChild(header)
    @aligns.push align
    
  add_row: (values, data=undefined) ->
    row = document.createElement('tr')
    if @glyphicon
      icon = document.createElement('td')
      icon.innerHTML = "
        <a href=\"#\" class=\"dropdown-toggle\" data-toggle=\"dropdown\"
            role=\"button\" aria-expanded=\"false\">
          <span class=\"glyphicon glyphicon-#{@glyphicon}\">
        </a>
      "
      $(icon).click =>
        @fn_menu(data) if @fn_menu

      row.appendChild(icon)

    for value, idx in values
      align = @aligns[idx + 1] ? 'left'
      column = document.createElement('td')
      column.className = 'text-' + align
      column.appendChild(document.createTextNode(value))
      $(column).click =>
        @fn_row(data) if @fn_row != null

      row.appendChild(column)
      @table.append(row)
    
  finish: ->
    @old_table.replaceWith(@table)

view_switch = (name) ->
  class_name = '#view-' + name
  for view in VIEWS
    view_name = ('#view-' + view)
    elem = $(view_name)
    button = $('#switch-' + view + '-view')
    if view_name == class_name
      elem.show()
      button.fadeTo(500, 1.0)
      button.parent().addClass('active')
    else
      elem.hide()
      button.fadeTo(500, 0.5)
      button.parent().removeClass('active')

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


mpd_query = (query, target, queue_only=true) ->
  WEBSOCKET.send(JSON.stringify({
    'type': 'store',
    'detail': if queue_only then 'queue' else 'database',
    'target': target,
    'query': query
  }))

#####################
#  STATUS UPDATING  #
#####################

format_minutes = (seconds) ->
  secs = Math.round(seconds % 60)
  if secs < 10
    secs = '0' + secs
  return Math.round(seconds / 60) + ':' + secs

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
  pg = $('#seekbar')

  percent = 0
  if total_sec == 0
    percent = 100
    pg.addClass('progress-bar-striped')
  else
    percent = (elapsed_sec / (total_sec * 1.0)) * 100
    pg.removeClass('progress-bar-striped')

  pg.attr('aria-valuenow', percent)
  pg.css('width', percent + '%')
  $('#seekbar-label').html(
    format_minutes(elapsed_sec) + '/' + format_minutes(total_sec)
  )

  song = status.song

  $('#footer-song-title').html(
    '<em>' + (song.artist or '') + '</em> - ' + (song.title or '')
  )

update_play_buttons = (status) ->
  active = (status.state == 'playing')
  $('#btn-pause').toggleClass('btn-info', active)
  $('#btn-pause>span').toggleClass('glyphicon-play', active)
  $('#btn-pause>span').toggleClass('glyphicon-pause', not active)

update_view_playing = (status) ->
  if status.song != {}
    song = status.song
    $('#view-playing-artist').html(song.artist or '')
    $('#view-playing-album').html(song.album or '🎝')
    $('#view-playing-title').html(song.title or 'Not playing')

    if status['song-changed']
      WEBSOCKET.send(JSON.stringify({
        'type': 'metadata',
        'get_type': 'cover',
        'detail': 'view-playing',
        'artist': song.artist,
        'album': song.album,
      }))
    
      # Set the default no cover:
      setTimeout(->
        cover_elem = $('#cover')
        unless cover_elem.attr('has-cover')
          $('#cover').attr('src', '/static/nocover.jpg')
      500)
      
      # Order a new badge of songs to display:
      mpd_query("a:\"#{song.artist}\" b:\"#{song.album}\"", 'playing', false)

update_view_playing_cover = (metadata) ->
  if metadata.urls
    $('#cover').attr('src', metadata.urls[0])

update_view_playing_list = (playlist) ->
  view = new PlaylistTable('#view-playing-list', '', (song_id) ->
    mpd_send("('play-id', #{song_id})")
  )
  for song, idx in playlist.songs
    view.add_row(["\##{idx + 1}", song.title], song.id)

  view.finish()


update_view_database_list = (playlist) ->
  view = new PlaylistTable('#view-database-list')
  view.add_header('#')
  view.add_header('Artist', 'left')
  view.add_header('Album', 'left')
  view.add_header('Title', 'right')

  for song, idx in playlist.songs
    view.add_row(["\##{idx + 1}", song.artist, song.album, song.title])

  view.finish()


queue_row_clicked = (song_id) ->
  console.log('ID', song_id)

queue_menu_clicked = (song_id) ->
  console.log('Menu', song_id)

update_view_queue_list = (playlist) ->
  view = new PlaylistTable(
    '#view-queue-list', 'align-left',
    queue_row_clicked, queue_menu_clicked
  )

  view.add_header('#')
  view.add_header('Artist', 'left')
  view.add_header('Album', 'left')
  view.add_header('Title', 'right')
  for song, idx in playlist.songs
    view.add_row(["\##{idx + 1}", song.artist, song.album, song.title], song.id)

  view.finish()

#####################
#  WEBSOCKET STUFF  #
#####################

on_socket_open = (msg) ->
  console.log(msg)
  mpd_query('*', 'queue', queue_only=true)
  mpd_query('*', 'database', queue_only=false)

on_socket_close = (msg) ->
  console.log(status)

on_socket_message = (msg) ->
  # console.log('receive', msg)
  update_data = JSON.parse msg.data

  switch update_data.type
    when 'status'  # Status update.
      status = update_data.status
      update_play_modes(status)
      update_progressbar(status)
      update_play_buttons(status)
      update_view_playing(status)
    when 'metadata'
      update_view_playing_cover(update_data)
    when 'store'
      switch update_data.target
        when 'playing'
          update_view_playing_list(update_data)
        when 'queue'
          update_view_queue_list(update_data)
        when 'database'
          update_view_database_list(update_data)
    else
      console.log('Unknown message type: ', update_data.type)

#######################################################
#  MAIN (or how main-y you can go with CoffeeScript)  #
#######################################################

connect_search = (textbox, button, callback) ->
  textbox.keypress (ev) ->
    console.log(ev)
    if ev.keyCode == 13
      callback(textbox.val())

  button.click ->
    callback(textbox.val())

  textbox.on('input propertychange paste', ->
    unless textbox.val()
      callback('*')
  )


$ ->
  # Hide the database and queue by default.
  view_switch('database')

  # Make views switchable:
  for view in VIEWS
    do (view) ->
      $('#switch-' + view + '-view').click -> view_switch(view)


  for view in ['database', 'queue']
    do (view) ->
      connect_search(
        $('#view-'+view+'-search'),
        $('#view-'+view+'-exec'), (qry) ->
          mpd_query(qry, view, queue_only=false)
      )

  for entry in ['about', 'sysinfo']
    do (entry) ->
      # Connect the menu entries:
      $('#menu-' + entry).click ->
        $('#modal-' + entry).modal({
          'backdrop': 'static',
          'keyboard': true,
          'show': true
        })
  
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
