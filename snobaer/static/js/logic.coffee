#############
#  GLOBALS  #
#############

# TODO: Reduce visibility of some of those?
SERVER_URL = "ws://localhost:8080/ws"
WEBSOCKET = null
LAST_SONG_ID = -1

# Stupid hack to save the completion callback
# for the time when the result was retrieved
# from the server.
COMPLETION_HANDLER = null

class PlaylistTable
  constructor: (
    table_id, @glyphicon='plus',
    @fn_row=null, @fn_menu=null) ->
    @old_table = $(table_id)
    @old_table.html('')
    @table = @old_table.clone(false)
    @header_row = document.createElement('tr')
    @table.append(@header_row)
    @aligns = []
    @row_count = 0

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
      column.appendChild(document.createTextNode(value ? ''))
      $(column).click =>
        @fn_row(data) if @fn_row != null

      row.appendChild(column)
      @table.append(row)

    @row_count += 1
    return row
  
  length: ->
    @row_count

  finish: ->
    @old_table.replaceWith(@table)
    

#####################
#  STATUS UPDATING  #
#####################

format_minutes = (seconds) ->
  secs = Math.round(seconds % 60)
  secs = '0' + secs if secs < 10
  return Math.round(seconds / 60) + ':' + secs

update_play_modes = (status) ->
  states ={
    'repeat': status.repeat, 'random': status.random,
    'single': status.single, 'consume': status.consume
  }
  for name, state of states
    $('#btn-' + name).toggleClass('btn-info', state)

setprogressbar_value = (pg, percent, elapsed_sec, total_sec) ->
  pg.attr('aria-valuenow', percent)
  pg.attr('timestamp', new Date().getTime())
  pg.css('width', percent + '%')
  $('#seekbar-label').html(
    format_minutes(elapsed_sec) + '/' + format_minutes(total_sec)
  )

update_progressbar = (status) ->
  elapsed_sec = status['elapsed-ms'] / 1000.0
  total_sec = status['total-time']
  pg = $('#seekbar')

  if pg.attr('update-id')
    clearTimeout(parseInt(pg.attr('update-id')))

  percent = 0
  if total_sec == 0
    percent = 100
    pg.addClass('progress-bar-striped')
  else
    percent = (elapsed_sec / (total_sec * 1.0)) * 100
    pg.removeClass('progress-bar-striped')

  setprogressbar_value(pg, percent, elapsed_sec, total_sec)

  song = status.song

  $('#footer-song-title').html(
    '<em>' + (song.artist or '') + '</em> - ' + (song.title or '')
  )

  if status.state == 'playing'
    update_id = setInterval(->
      last_time = parseInt(pg.attr('timestamp'), 10)
      curr_time = new Date().getTime()
      passed_sec = (curr_time - last_time) / 1000

      last_percent = parseFloat(pg.attr('aria-valuenow'))

      next_offset = ((last_percent / 100.0) * total_sec) + passed_sec
      next_percent = (next_offset / total_sec) * 100

      setprogressbar_value(pg, next_percent, next_offset, total_sec)
    100)

    pg.attr('update-id', update_id)

update_play_buttons = (status) ->
  active = (status.state == 'playing')
  $('#btn-pause').toggleClass('btn-info', active)
  $('#btn-pause>span').toggleClass('glyphicon-play', active)
  $('#btn-pause>span').toggleClass('glyphicon-pause', not active)

update_view_playing = (status) ->
  if not $.isEmptyObject(status.song) or status['song-id'] < 0
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
      WEBSOCKET.send_query(
        "a:\"#{song.artist}\" b:\"#{song.album}\"", 'playing', false
      )

update_view_playing_cover = (metadata) ->
  if metadata.urls
    $('#cover').attr('src', metadata.urls[0])

update_view_playing_list = (playlist) ->
  view = new PlaylistTable(
    '#view-playing-list', '',
    (song_id) ->
      WEBSOCKET.send_mpd("('play-id', #{song_id})")
  )
  for song, idx in playlist.songs
    row = view.add_row(["\##{idx + 1}", song.title], song.id)
    if song.id == LAST_SONG_ID
      $(row).addClass('text-primary')
    else if song.id < 0
      $(row).addClass('text-muted')

  view.finish()


update_view_database_list = (playlist) ->
  view = new PlaylistTable(
    '#view-database-list',
    'plus',
    (song_uri) ->
      WEBSOCKET.send_mpd("('queue-add', \"#{song_uri}\")")
    (song_uri) ->
      WEBSOCKET.send_mpd("('queue-add', \"#{song_uri}\")")
  )
  view.add_header('#')
  view.add_header('Artist', 'left')
  view.add_header('Album', 'left')
  view.add_header('Title', 'right')
  view.add_header('', 'right')

  for song, idx in playlist.songs
    queued = if song.id >= 0 then '✓' else ''
    view.add_row(
      ["\##{idx + 1}", song.artist, song.album, song.title, queued],
      song.uri
    )

  $('#view-database-shown-songs').html(view.length() + ' shown songs')
  view.finish()


update_view_queue_list = (playlist) ->
  view = new PlaylistTable(
    '#view-queue-list',
    'remove',
    (song_id) ->
      WEBSOCKET.send_mpd("('play-id', #{song_id})")
    (song_id) ->
      WEBSOCKET.send_mpd("('queue-delete-id', #{song_id})")
  )

  view.add_header('#')
  view.add_header('Artist', 'left')
  view.add_header('Album', 'left')
  view.add_header('Title', 'right')
  view.add_header('Genre', 'right')
  for song, idx in playlist.songs
    row = view.add_row([
        "\##{idx + 1}", song.artist, song.album, song.title, song.genre
    ], song.id)

    if song.id == LAST_SONG_ID
      $(row).addClass('text-primary')

  $('#view-queue-shown-songs').html(view.length() + ' songs shown')
  view.finish()


update_outputs_dialog = (outputs) ->
  console.log(outputs)
  if $.isEmptyObject(outputs)
    return

  output_list = $('#view-outputs-list')

  # TODO
  html = ""
  for name, info in outputs
    console.log('  ', name, info)
    color = if info.on then 'success' else 'warning'
    html += """<tr><td><label class="btn checkbutton btn-#{color} active">
        <input type="checkbox" autocomplete="off" checked>
        <span class="glyphicon glyphicon-ok">#{name}</span>
      </label></td></tr>"""

  console.log('html', html, outputs)
  output_list.html(html)

#####################
#  WEBSOCKET STUFF  #
#####################

class SnobaerSocket
  constructor: (url) ->
    @socket = new WebSocket url
    @socket.onopen = this.on_socket_open
    @socket.onclose = this.on_socket_close
    @socket.onmessage = this.on_socket_message

    # Needed for autocompletion:
    @completion_handler = null

  send: (msg) ->
    @socket.send(msg)

  send_mpd: (command) ->
    @socket.send(JSON.stringify({
      'type': 'mpd',
      'detail': command
    }))
  
  send_mpd_simple: (command) ->
    this.send_mpd "('#{command}', )"

  send_completion_request: (query) ->
    @socket.send(JSON.stringify({
      'type': 'completion',
      'detail': query
    }))
  
  send_query: (query, target, queue_only=true, add_matches=false) ->
    @socket.send(JSON.stringify({
      'type': 'store',
      'detail': if queue_only then 'queue' else 'database',
      'target': target,
      'query': query,
      'add-matches': add_matches
    }))

  on_socket_open: (msg) =>
    console.log(msg, this)

    # Make an initial update on the queue and database.
    this.send_query('*', 'queue', queue_only=true)
    this.send_query('*', 'database', queue_only=false)
  
  on_socket_close: (msg) ->
    console.log(status)
  
  on_socket_message: (msg) ->
    update_data = JSON.parse msg.data

    switch update_data.type
      when 'status'  # Status update.
        status = update_data.status
        update_play_modes(status)
        update_progressbar(status)
        update_play_buttons(status)
        update_view_playing(status)
        update_outputs_dialog(update_data.outputs)

        $('#view-database-total-songs').html(
          status['number-of-songs'] + ' total songs'
        )

        LAST_SONG_ID = status.song.id if status.song

        if status['list-needs-update'] or status['song-changed']
          WEBSOCKET.send_query(
            $('#view-queue-search').val(),
            'queue', queue_only=true
          )

        if status['list-needs-update']
          WEBSOCKET.send_query(
            $('#view-database-search').val(),
            'database', queue_only=false
          )

        view = new PlaylistTable('#view-playing-stats', '')
        view.add_row(['Number of songs', status['number-of-songs']])
        view.add_row(['Number of artists', status['number-of-artists']])
        view.add_row(['Number of albums', status['number-of-albums']])
        view.add_row(['Kbit/s', status['kbit-rate']])
        view.finish()
      when 'metadata'
        update_view_playing_cover(update_data)
      when 'completion'
        console.log(update_data.result, COMPLETION_HANDLER)
        if COMPLETION_HANDLER != null
          COMPLETION_HANDLER(update_data.result)
        COMPLETION_HANDLER = null
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

  connect_autocomplete: (entry) ->
    entry.typeahead({
      hint: true,
      highlight: true,
      minLength: 1
    }, {
      name: 'songs',
      async: true,
      source: (frag, _, async) =>
        WEBSOCKET.send_completion_request(frag)
        COMPLETION_HANDLER = (result) ->
          async([result])

        console.log('REQ', frag, async, this, COMPLETION_HANDLER)
        
    })
    entry.removeClass('dropdown-menu');

#######################################################
#  MAIN (or how main-y you can go with CoffeeScript)  #
#######################################################

connect_search = (textbox, button, callback) ->
  textbox.keypress (ev) ->
    if ev.keyCode == 13
      callback(textbox.val())

  button.click ->
    callback(textbox.val())

  textbox.on('input propertychange paste', ->
    unless textbox.val()
      callback('*')
  )

view_switch = (views, name) ->
  class_name = '#view-' + name
  for view in views
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


show_modal = (name) ->
  $('#modal-' + name).modal({
    'backdrop': 'static',
    'keyboard': true,
    'show': true
  })


$ ->
  views = ['database', 'playing', 'queue', 'playlists']

  # Hide the database and queue by default.
  view_switch(views, 'database')

  # Make views switchable:
  for view in views
    do (view) ->
      $('#switch-' + view + '-view').click -> view_switch(views, view)

  # Connect the event socket:
  WEBSOCKET = new SnobaerSocket SERVER_URL

  for [view, queue_only] in [['database', false], ['queue', true]]
    do (view, queue_only) ->
      connect_search(
        $('#view-'+view+'-search'),
        $('#view-'+view+'-exec'),
        (qry) ->
          WEBSOCKET.send_query(qry, view, queue_only=queue_only)
      )

    WEBSOCKET.connect_autocomplete($('#view-'+view+'-search'))


  for entry in ['about', 'sysinfo', 'outputs']
    do (entry) ->
      # Connect the menu entries:
      $('#menu-' + entry).click ->
        show_modal(entry)

  $('#view-database-rescan').click ->
    WEBSOCKET.send_mpd('("database-rescan", "/")')

  $('#view-database-add-all').click ->
    WEBSOCKET.send_mpd("('queue-add', '/')")

  $('#view-database-add-visible').click ->
    query = $('#view-database-search').val()
    WEBSOCKET.send_query(query, 'database', false, true)

  # TODO show_modal function
  $('#view-queue-clear').click ->
    show_modal('queue-clear')

  $('#view-queue-save').click ->
    show_modal('queue-save')

  $('#view-queue-apply-clear').click ->
    WEBSOCKET.send_mpd_simple('queue-clear')
  
  for action in ['previous', 'stop', 'pause', 'next']
    do (action) ->
      $('#btn-' + action).click ->
        WEBSOCKET.send_mpd_simple(action)

  # Also connect the state toggling buttons:
  for action in ['random', 'repeat', 'consume', 'single']
    do (action) ->
      $('#btn-' + action).click ->
        is_active = $(this).hasClass('btn-info')
        WEBSOCKET.send_mpd("('#{action}', #{not is_active})")

  $('.toggle-switch').bootstrapSwitch({
    size: 'small',
    onColor: 'success'
  })
