// Copyright 2013 Ville Misaki <ville@misaki.fi>. All right reserved.

function show_month(id) {
	if (id == 'first') {
		id = $('#months').children().first().attr('id')
	}
	else if (id == 'last') {
		id = $('#months').children().last().attr('id')
	}
	if (! $("#" + id).is(":visible")) {
		var curr_month = get_curr_month();
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
				var filters = get_url_filters();
                history.pushState(null, 'Lenni', window.location.pathname + (filters.length > 0 ? '?' + filters : ''));
            }
		}
		else {
			$(".month_nav span.next").css("visibility", "").attr("title", $(next_month).attr("title"));
			$(".month_nav span.last").css("visibility", "");
			if (curr_month != null && history != null && typeof history.pushState == 'function') {
				var filters = get_url_filters();
                history.pushState(null, 'Lenni', window.location.pathname + '?m=' + id.substr(1) + (filters.length > 0 ? '&' + filters : ''));
            }
		}
		
		$("#" + id + " a.photo").each(function(i) {
			var imgsrc = $(this).attr("href");
			$(this).find("span.photo").css("background-image", "url('thumbs/" + imgsrc + "')")
		});
		$("#" + id +" .block h3").each(function(i) {
			var date_parts = /^d(\d\d\d\d)-(\d\d)-(\d\d)$/.exec($(this).attr("id"));
			if (date_parts.length > 0) {
				var cmpd = new Date(Date.UTC(parseInt(date_parts[1], 10), parseInt(date_parts[2], 10) - 1, parseInt(date_parts[3], 10), 23, 59, 59));
				$(this).attr("title", getDateDiffStr(epochd, cmpd, "date"));
				$(this).find("span.age").html(getDateDiffStr(epochd, cmpd, "date_short"));
			}
		});
		
		$("#" + id).show();
	}
	
	return false;
}

function is_last_month() {
    return $("div.month_block:visible").next().length == 0;
}

function get_curr_month() {
    var item = $("div.month_block:visible");
    if (item.length > 0) {
	   return item.attr("id").substr(1);
    }
    else {
        return null;
    }
}

function show_prev_month() {
	var item = $("div.month_block:visible").prev();
	if (item.length > 0) {
	   return show_month(item.attr("id"));
	}
	return false;
}

function show_next_month() {
	var item = $("div.month_block:visible").next();
	if (item.length > 0) {
	   return show_month(item.attr("id"));
	}
	return false;
}

function show_month_containing(id) {
	var month = get_month_containing(id);
	if (month != null) {
		show_month(month);
	}
	
	return false;
}

function get_month_containing(id) {
	return $("#" + id).parent().parent().attr("id");
}

function get_url_filters() {
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
}
