VIEWS = ['database', 'playing', 'queue']
SERVER_URL = "ws://localhost:8080/ws"

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
    

  console.log(elapsed_sec, total_sec, percent)
  pg.attr('aria-valuenow', percent)
  pg.css('width', percent + '%')

#####################
#  WEBSOCKET STUFF  #
#####################

on_socket_open = (msg) ->
  console.log(msg)

on_socket_close = (msg) ->
  console.log(status)

on_socket_message = (msg) ->
  update_data = JSON.parse msg.data
  update_play_modes update_data.status
  update_progressbar update_data.status


#######################################################
#  MAIN (or how main-y you can go with CoffeeScript)  #
#######################################################

$ ->
  $('#play-btn').click ->
    if $(this).hasClass('btn-info')
      $(this).removeClass('btn-info')
      $(this).animate
        opacity: 0.1, 500, () ->
    else
      $(this).addClass('btn-info')
      $(this).animate
        opacity: 1.0, 500, () ->

  # Hide the database and queue by default.
  $('#view-database').hide()
  $('#view-queue').hide()

  # Make views switchable:
  for view in VIEWS
    do (view) ->
      $('#switch-' + view + '-view').click -> view_switch(view)

  # Connect the event socket:
  # socket = create_websocket
  socket = new WebSocket SERVER_URL
  socket.onopen = on_socket_open
  socket.onclose = on_socket_close
  socket.onmessage = on_socket_message
