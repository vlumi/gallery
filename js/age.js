// Copyright 2012-2014 Ville Misaki <ville@misaki.fi>. All rights reserved.

// A function for creating a string representation for the difference of two Date objects.
// Outputs the time difference in years, months, weeks and days. Optionally can also
// include the time decision as HH:MM:SS, if the parameter show_time is set.

// The date format is in English, as a natural string of format with numbers as numerals,
// each segment separated by commas, and the last two segments separated by an "and". All
// zero-values are left out from the date, except in the special case when the time is not
// shown and the period is zero days, in which "0 days" is returned.

// Usage with jQuery:
//     $(document).ready(function() {
//        update_age();
//     });
//     // Epoch "2012-01-06T02:52:00+02 in UTC
//     var epochd = new Date(Date.UTC(2012, 0, 6, 0, 52, 0));
//     function update_age() {
//         $('#age').html(getDateDiffStr(new Date(epochd.getTime()), new Date(), false));
//     }
//     var t = setInterval(update_age, 1000); // Update once a second
// ...
//     <p> Age: <span id="age">(calculating...)</span> </p>
if (typeof vlumi === 'undefined')
    vlumi = {};

vlumi.Age = {
    getDateDiffStr: function(p_startd, p_endd, format, precision) {
        var startd = new Date(p_startd);
        var endd = new Date(p_endd);

        // Maps for constructing the date string.
        // These may be localized if needed.
        var partTitlesSingular = [' year', ' month', ' week', ' day', ' hour', ' minute', ' second'];
        var partTitlesPlural = [' years', ' months', ' weeks', ' days', ' hours', ' minutes', ' seconds'];
        var partTitlesShort = ['歳', 'ヶ月', '週', '日', '', '', ''];
        var timeSeparator = ':';
        
        if (startd > endd) {
            var tempd = startd;
            startd = endd;
            endd = tempd;
        }
        
        var retstr = '';
        
        if (format == 'full' || format == 'full_short' || format == 'date' || format == 'date_short') {
            var is_short = false;
            if (format == 'full_short' || format == 'date_short') {
                is_short = true;
            }
            // Calculate full years and months; variable length, so needs looping.
            var years = -1;
            var months = -1;
            while (startd < endd) {
                startd.setUTCFullYear(startd.getUTCFullYear() + 1);
                years++;
            }
            startd.setUTCFullYear(startd.getUTCFullYear() - 1);
            while (startd < endd) {
                startd.setUTCMonth(startd.getUTCMonth() + 1);
                months++;
            }
            startd.setUTCMonth(startd.getUTCMonth() - 1);
            
            var dateParts = [];
            var timeParts = [];
            
            // Moved to within a month; calculate the rest from the millisecond difference.
            var t = endd - startd;
            var weeks = Math.floor((t / (1000 * 60 * 60 * 24 * 7)));
            var days = Math.floor((t / (1000 * 60 * 60 * 24)) % 7);
            
            // Collect the date string parts.
            var diffDateParts = [years, months, weeks, days];
            for (var i = 0; i < diffDateParts.length; i++) {
                var val = diffDateParts[i];
                if (val == 0 && (format == 'full' || format == 'full_short' || dateParts.length > 0 || i < 3)) {
                    continue;
                }
                var title = (is_short
                             ? partTitlesShort[i]
                             : (val == 1 ? partTitlesSingular[i] : partTitlesPlural[i]));
                dateParts.push(vlumi.Age.format_bignum(val, ',', 0) + title);
            }
            if (dateParts.length == 0 && format == 'date') {
                // Default to "0 days"
                dateParts.push(0 + partTitlesPlural[3]);
            }
            
            if (format == 'full' || format == 'full_short') {
                var hours = Math.floor((t / (1000 * 60 * 60)) % 24);
                var minutes = Math.floor((t / (1000 * 60)) % 60);
                var seconds = Math.floor((t / 1000) % 60);
                
                // Collect the time string parts.
                var diffTimeParts = [hours, minutes, seconds];
                for (var i = 0; i < diffTimeParts.length; i++) {
                    var val = diffTimeParts[i];
                    if (val < 10) {
                        val = '0' + val;
                    }
                    timeParts.push(val);
                }
            }
            
            // Join the parts together.
            var strParts = [];
            
            if (is_short) {
                strParts.push(dateParts.join('<br/>'));
            }
            else if (dateParts.length > 1) {
                var lastDatePart = dateParts.pop();
                strParts.push([dateParts.join(', '), lastDatePart].join(' and '));
            }
            else {
                strParts.push(dateParts.join(', '));
            }
            
            if (format == 'full' || format == 'full_short') {
                strParts.push(timeParts.join(timeSeparator));
            }
            if (is_short) {
                retstr = strParts.join('<br/>');
            }
            else {
                retstr = strParts.join(', ');
            }
        }
        else {
            var val = '';
            var title_idx = -1;
            
            if (format == 'years') {
                // Years, taking leap years into account.
                
                // Count the number of full years by looping.
                var years = -1;
                while (startd < endd) {
                    startd.setUTCFullYear(startd.getUTCFullYear() + 1);
                    years++;
                }
                var t_left = startd - endd;
                startd.setUTCFullYear(startd.getUTCFullYear() - 1);
                
                // Fractions from what's left after looping.
                var t_gone = endd - startd;
                years += t_gone / (t_gone + t_left);
                
                val = years;
                title_idx = 0;
                
                var title = (val == 1 ? partTitlesSingular[title_idx] : partTitlesPlural[title_idx]);
                
                var mul = Math.pow(10, precision);
                val = Math.floor(val * mul) / mul;
            }
            else if (format == 'months') {
                // Full months.
                var months = -1;
                while (startd < endd) {
                    startd.setUTCMonth(startd.getUTCMonth() + 1);
                    months++;
                }
                var t_left = startd - endd;
                startd.setUTCMonth(startd.getUTCMonth() - 1);
                
                // Fractions from what's left after looping.
                var t_gone = endd - startd;
                months += t_gone / (t_gone + t_left);
                
                val = months;
                title_idx = 1;
            }
            else {
                // Full time difference, in milliseconds
                var t = endd - startd;
                
                var val = '';
                if (format == 'weeks') {
                    val = t / (1000 * 60 * 60 * 24 * 7);
                    title_idx = 2;
                }
                else if (format == 'days') {
                    val = t / (1000 * 60 * 60 * 24);
                    title_idx = 3;
                }
                else if (format == 'hours') {
                    val = t / (1000 * 60 * 60);
                    title_idx = 4;
                }
                else if (format == 'minutes') {
                    val = t / (1000 * 60);
                    title_idx = 5;
                }
                else if (format == 'seconds') {
                    val = t / 1000;
                    title_idx = 6;
                }
            }
            var title = (val == 1 ? partTitlesSingular[title_idx] : partTitlesPlural[title_idx]);
            
            val = vlumi.Age.format_bignum(val, ',', precision);
            
            retstr = val + title;
        }
        
        return retstr;
    },

    // Display the number with thousand-separators, with exactly <precision> decimals.
    format_bignum: function(num, sep, precision) {
        // Split the number into parts.
        var parts = [];
        do {
            var val = num % 1000;
            if (num > 1000) {
                // Padding if in the middle of the number
                if (val < 10) {
                    val = "00" + val;
                }
                else if (val < 100) {
                    val = "0" + val;
                }
            }
            parts.unshift(val);
            num = Math.floor(num / 1000);
        } while (num > 0);
        
        // Collect the parts as a thousand-separated string
        var retstr = '0';
        if (parts.length > 0) {
            retstr = parts.join(sep);
        }

        // Always rounding down, not to reach milestones early.
        parts = retstr.split('.', 2)
        retstr = parts[0];
        if (precision > 0) {
            if (parts[1] === undefined) {
                parts[1] = '0';
            }
            if (parts[1].length > precision) {
                parts[1] = parts[1].substring(0, precision);
            }
            else {
                while (parts[1].length < precision) {
                    parts[1] += '0';
                }
            }
            retstr += '.' + parts[1];
        }
        
        return retstr
    },
};

