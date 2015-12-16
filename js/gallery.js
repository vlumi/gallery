"use strict";
// Copyright 2013-2015 Ville Misaki <ville@misaki.fi>. All right reserved.

var vlumi;
if (typeof vlumi === 'undefined') {
    vlumi = {};
}

vlumi.gallery = (function () {
    var update_prev_nav = function (curr_month, month_id) {
        var filters;
        var prev_month = $("#" + month_id).prev();

        if (prev_month.length === 0) {
            $(".month_nav span.first").css("visibility", "hidden");
            $(".month_nav span.prev").css("visibility", "hidden");
            if (curr_month !== null && history !== null && typeof history.pushState === 'function') {
                filters = vlumi.gallery.get_url_filters();
                history.pushState(null, $('title').text(), window.location.pathname + (filters.length > 0 ? '?' + filters : ''));
            }
        } else {
            $(".month_nav span.first").css("visibility", "");
            $(".month_nav span.prev").css("visibility", "").attr("title", $(prev_month).attr("title"));
            if (curr_month !== null && history !== null && typeof history.pushState === 'function') {
                filters = vlumi.gallery.get_url_filters();
                history.pushState(null, $('title').text(), window.location.pathname + '?m=' + month_id.substr(1) + (filters.length > 0 ? '&' + filters : ''));
            }
        }
    };

    var update_next_nav = function (curr_month, month_id) {
        var filters;
        var next_month = $("#" + month_id).next();

        if (next_month.length === 0) {
            $(".month_nav span.next").css("visibility", "hidden");
            $(".month_nav span.last").css("visibility", "hidden");
            if (curr_month !== null && history !== null && typeof history.pushState === 'function') {
                filters = vlumi.gallery.get_url_filters();
                history.pushState(null, $('title').text(), window.location.pathname + (filters.length > 0 ? '?' + filters : ''));
            }
        } else {
            $(".month_nav span.next").css("visibility", "").attr("title", $(next_month).attr("title"));
            $(".month_nav span.last").css("visibility", "");
            if (curr_month !== null && history !== null && typeof history.pushState === 'function') {
                filters = vlumi.gallery.get_url_filters();
                history.pushState(null, $('title').text(), window.location.pathname + '?m=' + month_id.substr(1) + (filters.length > 0 ? '&' + filters : ''));
            }
        }
    };

    var reveal_thumbnails = function (month_id) {
        var imgsrc;

        $("#" + month_id + " a.photo").each(function (i) {
            imgsrc = $(this).attr("href").replace(/^i\//, "");
            $(this).find("span.photo").css("background-image", "url('thumbs/" + imgsrc + "')")
        });
    };

    var update_date_age = function (month_id) {
        var date_parts;

        $("#" + month_id + " .block h3").each(function (i) {
            date_parts = /^d(\d\d\d\d)-(\d\d)-(\d\d)$/.exec($(this).attr("id"));
            if (date_parts.length > 0) {
                var cmpd = new Date(Date.UTC(parseInt(date_parts[1], 10), parseInt(date_parts[2], 10) - 1, parseInt(date_parts[3], 10), 23, 59, 59));
                    if (show_age)
                    $(this).attr("title", vlumi.age.getDateDiffStr(epochd, cmpd, "date"));
                if (show_age)
                    $(this).find("span.age").html(vlumi.age.getDateDiffStr(epochd, cmpd, "date_short"));
            }
        });
    };

    var get_month_containing = function (month_id) {
        return $("#" + month_id).parent().parent().attr("id");
    };

    return {
        show_month: function (month_id) {
            var curr_month, title;

            if (!$("#" + month_id).is(":visible")) {
                curr_month = vlumi.gallery.get_curr_month();
                $("div.month_block").hide();

                title = $("#" + month_id).attr("title");
                $(".month_nav span.title").html(title);

                update_prev_nav(curr_month, month_id);
                update_next_nav(curr_month, month_id);

                reveal_thumbnails(month_id);
                update_date_age(month_id);

                $("#" + month_id).show();
            }

            return false;
        },
        is_last_month: function () {
            return $("div.month_block:visible").next().length === 0;
        },
        get_curr_month: function () {
            var item = $("div.month_block:visible");

            if (item.length > 0) {
                return item.attr("id").substr(1);
            } else {
                return null;
            }
        },
        show_first_month: function () {
            var month_id = $('#months').children().first().attr('id')

            vlumi.gallery.show_month(month_id);
        },
        show_prev_month: function () {
            var item = $("div.month_block:visible").prev();

            if (item.length > 0) {
                return vlumi.gallery.show_month(item.attr("id"));
            }
            return false;
        },
        show_next_month: function () {
            var item = $("div.month_block:visible").next();

            if (item.length > 0) {
                return vlumi.gallery.show_month(item.attr("id"));
            }
            return false;
        },
        show_last_month: function () {
            var month_id = $('#months').children().last().attr('id')

            vlumi.gallery.show_month(month_id);
        },
        show_month_containing: function (id) {
            var month_id = get_month_containing(id);

            if (month_id !== null) {
                vlumi.gallery.show_month(month_id);
            }

            return false;
        },
        get_url_filters: function () {
            var url = $.url();
            var filters = [];

            var sections = ["country", "camera", "author"];
            var i, param;

            for (i in sections) {
                param = url.param(sections[i]);
                if (param && typeof param !== 'undefined' && param !== null) {
                    filters.push(sections[i] + '=' + encodeURIComponent(param).replace(/%20/g, '+'));
                }
            }

            return filters.join("&");
        }
    };
}());
