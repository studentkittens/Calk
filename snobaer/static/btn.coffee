VIEWS = ['database', 'playing', 'queue']

view_switch = (name) ->
  class_name = '#view-' + name
  for view in VIEWS
    view_name = ('#view-' + view)
    elem = $(view_name)
    if view_name == class_name then elem.show() else elem.hide()

on_socket_open = (msg) ->
  console.log(msg)

on_socket_close = (msg) ->
  console.log(msg)

on_socket_message = (msg) ->
  console.log(msg)

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
  socket = new WebSocket "ws://localhost:8080/ws"
  socket.onopen = on_socket_open
  socket.onclose = on_socket_close
  socket.onmessage = on_socket_message
