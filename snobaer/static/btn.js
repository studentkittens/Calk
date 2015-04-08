$().ready(function() {
    $('#danger').click(function() {
        if($(this).hasClass('btn-info') == true) {
            $(this).removeClass('btn-info');
            $(this).animate({
                opacity: 0.1,
            }, 500, function() {});
        } else {
            $(this).addClass('btn-info');
            $(this).animate({
                opacity: 1.0,
            }, 500, function() {});
        }
        ws = new WebSocket("ws://localhost:8080/ws");
        ws.onmessage = function(e) {
            alert('message received: ' + e.data);
        };
        ws.onopen = function(e) {
            ws.send('Hein blöd')
        }
    });

});
