#############
#  GLOBALS  #
#############

# Instance of our BACKEND-utility class.
BACKEND = null

# Id of the last song. Used to identify
# the row that needs to be highlighed.
LAST_SONG_ID = -1

# Stupid hack to save the completion callback
# for the time when the result was retrieved
# from the server.
COMPLETION_HANDLER = null

#####################
# UTILITY FUNCTIONS #
#####################

# Show a modal window by name.
show_modal = (name) ->
  $('#modal-' + name).modal({
    'backdrop': 'static',
    'keyboard': true,
    'show': true
  })

# Guess websocket uri from the current url.
find_weboscket_url = ->
  # Misuse a <a> tag as url parser:
  parser = document.createElement('a')
  parser.href = window.location
  console.log(parser.host)
  return 'ws://' + parser.host + '/ws'

# Make entry/go-button usable via search.
# calls `callback` once input was made.
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

# Switch to a certain view by name.
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
      button.fadeTo(500, 0.4)
      button.parent().removeClass('active')

# Playlist utility table (a bit ugly, sorry.)
class PlaylistTable
  constructor: (
    table_id, @glyphicon='plus',
    @fn_row=null, @fn_menu=null, header=true) ->

    @old_table = $(table_id)
    @old_table.empty()
    @table = @old_table.clone(false)
    @header_row = document.createElement('tr')
    @table.append(@header_row)
    @aligns = []
    @row_count = 0

    if @glyphicon and header
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

update_play_modes = (status) ->
  states ={
    'repeat': status.repeat, 'random': status.random,
    'single': status.single, 'consume': status.consume
  }
  for name, state of states
    $('#btn-' + name).toggleClass('btn-info', state)

update_progressbar = (heartbeat) ->
  pg = $('#seekbar')
  pg.toggleClass('progress-bar-striped', heartbeat.perc < 0.00000001)

  pg.attr('aria-valuenow', heartbeat.perc)
  pg.css('width', heartbeat.perc + '%')
  $('#seekbar-label').html(heartbeat.repr)

update_progressbar_subtitle = (status) ->
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
  if not $.isEmptyObject(status.song) or status['song-id'] < 0
    song = status.song
    $('#view-playing-artist').html(song.artist or '')
    $('#view-playing-album').html(song.album or '🎝')
    $('#view-playing-title').html(song.title or 'Not playing')

    if status['song-changed']
      BACKEND.send_metadata_request('cover', song)
    
      # Set the default no cover:
      setTimeout(->
        cover_elem = $('#cover')
        unless cover_elem.attr('has-cover')
          $('#cover').attr('src', '/static/nocover.jpg')
      500)
      
      # Order a new badge of songs to display:
      BACKEND.send_query(
        "a:\"#{song.artist}\" b:\"#{song.album}\"", 'playing', false
      )

  # Update the statistics table:
  view = new PlaylistTable('#view-playing-stats', '')
  view.add_row(['Number of songs', status['number-of-songs']])
  view.add_row(['Number of artists', status['number-of-artists']])
  view.add_row(['Number of albums', status['number-of-albums']])
  view.add_row(['Kbit/s', status['kbit-rate']])
  view.finish()

update_view_playing_cover = (metadata) ->
  if metadata.results
    $('#cover').attr('src', metadata.results[0])

update_view_playing_list = (playlist) ->
  view = new PlaylistTable(
    '#view-playing-list', 'align-left',
    (song) ->
      BACKEND.send_mpd("('play-id', #{song.id})")
    (song) ->
      BACKEND.send_metadata_request('lyrics', song)
    header=false
  )
  for song, idx in playlist.songs
    row = view.add_row(["\##{idx + 1}", song.title], song)
    if song.id == LAST_SONG_ID
      $(row).addClass('text-primary')
    else if song.id < 0
      $(row).addClass('text-muted')

  view.finish()

update_view_queue = (status) ->
  if status['list-needs-update'] or status['song-changed']
    BACKEND.send_query(
      $('#view-queue-search').val(),
      'queue', queue_only=true
    )

update_view_database = (status) ->
  $('#view-database-total-songs').html(
    status['number-of-songs'] + ' total songs'
  )

  if status['list-needs-update']
    BACKEND.send_query(
      $('#view-database-search').val(),
      'database', queue_only=false
    )

update_view_database_list = (playlist) ->
  view = new PlaylistTable(
    '#view-database-list',
    'plus',
    (song_uri) ->
      BACKEND.send_mpd("('queue-add', \"#{song_uri}\")")
    (song_uri) ->
      BACKEND.send_mpd("('queue-add', \"#{song_uri}\")")
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
      BACKEND.send_mpd("('play-id', #{song_id})")
    (song_id) ->
      BACKEND.send_mpd("('queue-delete-id', #{song_id})")
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

update_view_playlists = (status) ->
  list = $('#view-playlists-list')
  list.empty()

  for name in status.playlists
    button = $('<button type="button" class="btn btn-primary btn-block"/>')
    remove_button = $('<button type="button" class="btn btn-primary btn-sm"/>')

    remove_button
      .append($('<span class="glyphicon glyphicon-remove">'))

    remove_button.click (event) ->
      BACKEND.send_mpd("('playlist-rm', '#{name}')")
      event.stopPropagation()

    button
      .append(remove_button)
    button
      .append($("<span>&nbsp;&nbsp; Load playlist: <b>#{name}</b></span>"))

    list.append(button)

    button.click ->
      BACKEND.send_mpd_simple("queue-clear")
      BACKEND.send_mpd("('playlist-load', '#{name}')")

  if status.playlists.length == 0
    list.append($('<span class="text-muted">[No Playlists]</span>'))

update_outputs_dialog = (outputs) ->
  output_list = $('#view-outputs-list')
  output_list.empty()

  $.each(outputs, (name, enabled) ->
    ckbox = $('<input type="checkbox" class="toggle-switch"/>')
    ckbox.prop('checked', enabled)
    ckbox.prop('output-name', name)

    row = $('<tr></tr>')
    row.append($("<td class=\"text-primary\">#{name}</td>"))
    row.append(
      $("<td></td>")
        .append(ckbox)
    )

    output_list.append(row)
  )
    
  if output_list.is(':empty')
    output_list.append(
      $('<tr><td>No outputs. Cry for help.</td></tr>')
    )

  $('.toggle-switch').bootstrapSwitch({
    size: 'small',
    onColor: 'success',
    onSwitchChange: (event, state) ->
      name = $(this).prop('output-name')
      BACKEND.send_mpd("('output-switch', '#{name}', #{state})")
  })

#####################
#  BACKEND STUFF  #
#####################

class MPDSocket
  constructor: (url) ->
    @socket = new WebSocket(url)
    @socket.onopen = this.on_socket_open
    @socket.onclose = this.on_socket_close
    @socket.onmessage = this.on_socket_message

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
  
  send_metadata_request: (type, song) ->
    BACKEND.send(JSON.stringify({
      'type': 'metadata',
      'detail': type,
      'artist': song.artist,
      'album': song.album,
      'title': song.title
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
    # Make an initial update on the queue and database.
    this.send_query('*', 'queue', queue_only=true)
    this.send_query('*', 'database', queue_only=false)
  
  on_socket_close: (msg) ->
    show_modal('connection-lost')
  
  on_socket_message: (msg) ->
    data = JSON.parse msg.data

    switch data.type
      when 'status'  # Status update.
        status = data.status
        update_play_modes(status)
        update_progressbar_subtitle(status)
        update_play_buttons(status)
        update_view_playing(status)
        update_view_database(status)
        update_view_queue(status)
        update_view_playlists(status)
        update_outputs_dialog(data.outputs)

        LAST_SONG_ID = status.song.id if status.song
      when 'metadata'
        switch data.detail
          when 'cover'
            update_view_playing_cover(data)
          when 'lyrics'
            $('#lyrics-box').html(
              data.results[0] or 'Sorry, no lyrics found.'
            )
            show_modal('show-lyrics')
      when 'completion'
        if COMPLETION_HANDLER != null
          COMPLETION_HANDLER(data.result)
        COMPLETION_HANDLER = null
      when 'store'
        switch data.target
          when 'playing'
            update_view_playing_list(data)
          when 'queue'
            update_view_queue_list(data)
          when 'database'
            update_view_database_list(data)
      when 'hb'  # Heartbeat.
        update_progressbar(data)
      else
        console.log('Unknown message type: ', data.type)

  connect_autocomplete: (entry) ->
    entry.typeahead({
      hint: true,
      highlight: true,
      minLength: 1
    }, {
      name: 'songs',
      async: true,
      source: (frag, _, async) ->
        BACKEND.send_completion_request(frag)
        COMPLETION_HANDLER = (result) ->
          async([result])
    })

#######################################################
#  MAIN (or how main-y you can go with CoffeeScript)  #
#######################################################

$ ->
  views = ['database', 'playing', 'queue', 'playlists']

  # Hide the database and queue by default.
  view_switch(views, 'playing')

  # Make views switchable:
  for view in views
    do (view) ->
      $('#switch-' + view + '-view').click -> view_switch(views, view)

  # Connect the event socket:
  BACKEND = new MPDSocket find_weboscket_url()

  for [view, queue_only] in [['database', false], ['queue', true]]
    do (view, queue_only) ->
      connect_search(
        $('#view-'+view+'-search'),
        $('#view-'+view+'-exec'),
        (qry) ->
          BACKEND.send_query(qry, view, queue_only=queue_only)
      )

    BACKEND.connect_autocomplete($('#view-'+view+'-search'))

  for entry in ['about', 'sysinfo', 'outputs']
    do (entry) ->
      # Connect the menu entries:
      $('#menu-' + entry).click ->
        show_modal(entry)

  $('#view-database-rescan').click ->
    BACKEND.send_mpd('("database-rescan", "/")')

  $('#view-database-add-all').click ->
    BACKEND.send_mpd("('queue-add', '/')")

  $('#view-database-add-visible').click ->
    query = $('#view-database-search').val()
    BACKEND.send_query(query, 'database', false, true)

  $('#view-queue-clear').click ->
    show_modal('queue-clear')

  $('#view-queue-save').click ->
    show_modal('queue-save')

  $('#view-queue-apply-clear').click ->
    BACKEND.send_mpd_simple('queue-clear')

  $('#view-queue-apply-save').click ->
    playlist_name = $('#view-queue-save-input').val() or 'Last'
    BACKEND.send_mpd("('playlist-save', '#{playlist_name}')")
  
  for action in ['previous', 'stop', 'pause', 'next']
    do (action) ->
      $('#btn-' + action).click ->
        BACKEND.send_mpd_simple(action)

  # Also connect the state toggling buttons:
  for action in ['random', 'repeat', 'consume', 'single']
    do (action) ->
      $('#btn-' + action).click ->
        is_active = $(this).hasClass('btn-info')
        BACKEND.send_mpd("('#{action}', #{not is_active})")
