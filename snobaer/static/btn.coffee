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
