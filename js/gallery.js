// Copyright 2013-2014 Ville Misaki <ville@misaki.fi>. All right reserved.

if (typeof vlumi === 'undefined')
    vlumi = {};

vlumi.Gallery = {
    show_month: function(id) {
        if (id == 'first') {
            id = $('#months').children().first().attr('id')
        }
        else if (id == 'last') {
            id = $('#months').children().last().attr('id')
        }
        if (! $("#" + id).is(":visible")) {
            var curr_month = vlumi.Gallery.get_curr_month();
            $("div.month_block").hide();
            
            var title = $("#" + id).attr("title");
            $(".month_nav span.title").html(title);
            
            // Hide navigation links if first/last month.
            var prev_month = $("#" + id).prev();
            if (prev_month.length == 0) {
                $(".month_nav span.first").css("visibility", "hidden");
                $(".month_nav span.prev").css("visibility", "hidden");
            }
            else {
                $(".month_nav span.first").css("visibility", "");
                $(".month_nav span.prev").css("visibility", "").attr("title", $(prev_month).attr("title"));
            }
            var next_month = $("#" + id).next();
            if (next_month.length == 0) {
                $(".month_nav span.next").css("visibility", "hidden");
                $(".month_nav span.last").css("visibility", "hidden");
                if (curr_month != null && history != null && typeof history.pushState == 'function') {
                    var filters = vlumi.Gallery.get_url_filters();
                    history.pushState(null, 'Lenni', window.location.pathname + (filters.length > 0 ? '?' + filters : ''));
                }
            }
            else {
                $(".month_nav span.next").css("visibility", "").attr("title", $(next_month).attr("title"));
                $(".month_nav span.last").css("visibility", "");
                if (curr_month != null && history != null && typeof history.pushState == 'function') {
                    var filters = vlumi.Gallery.get_url_filters();
                    history.pushState(null, 'Lenni', window.location.pathname + '?m=' + id.substr(1) + (filters.length > 0 ? '&' + filters : ''));
                }
            }
            
            $("#" + id + " a.photo").each(function(i) {
                var imgsrc = $(this).attr("href").replace(/^i\//,"");
                $(this).find("span.photo").css("background-image", "url('thumbs/" + imgsrc + "')")
            });
            $("#" + id +" .block h3").each(function(i) {
                var date_parts = /^d(\d\d\d\d)-(\d\d)-(\d\d)$/.exec($(this).attr("id"));
                if (date_parts.length > 0) {
                    var cmpd = new Date(Date.UTC(parseInt(date_parts[1], 10), parseInt(date_parts[2], 10) - 1, parseInt(date_parts[3], 10), 23, 59, 59));
                    if (show_age) $(this).attr("title", vlumi.Age.getDateDiffStr(epochd, cmpd, "date"));
                    if (show_age) $(this).find("span.age").html(vlumi.Age.getDateDiffStr(epochd, cmpd, "date_short"));
                }
            });
            
            $("#" + id).show();
        }
        
        return false;
    },

    is_last_month: function() {
        return $("div.month_block:visible").next().length == 0;
    },

    get_curr_month: function() {
        var item = $("div.month_block:visible");
        if (item.length > 0) {
            return item.attr("id").substr(1);
        }
        else {
            return null;
        }
    },

    show_prev_month: function() {
        var item = $("div.month_block:visible").prev();
        if (item.length > 0) {
            return vlumi.Gallery.show_month(item.attr("id"));
        }
        return false;
    },

    show_next_month: function() {
        var item = $("div.month_block:visible").next();
        if (item.length > 0) {
            return vlumi.Gallery.show_month(item.attr("id"));
        }
        return false;
    },

    show_month_containing: function(id) {
        var month = vlumi.Gallery.get_month_containing(id);
        if (month != null) {
            vlumi.Gallery.show_month(month);
        }
        
        return false;
    },

    get_month_containing: function(id) {
        return $("#" + id).parent().parent().attr("id");
    },

    get_url_filters: function() {
        var filters = [];
        
        var url = $.url();
        if (url.param('country') != null) {
            filters.push('country=' + encodeURIComponent(url.param('country')).replace(/%20/g, '+'));
        }
        if (url.param('camera') != null) {
            filters.push('camera=' + encodeURIComponent(url.param('camera')).replace(/%20/g, '+'));
        }
        if (url.param('author') != null) {
            filters.push('author=' + encodeURIComponent(url.param('author')).replace(/%20/g, '+'));
        }
        
        return filters.join("&");
    },
};
