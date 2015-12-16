"use strict";
// Copyright 2012-2015 Ville Misaki <ville@misaki.fi>. All rights reserved.

// A function for creating a string representation for the difference of two Date objects.
// Outputs the time difference in years, months, weeks and days. Optionally can also
// include the time decision as HH:MM:SS, if the parameter show_time is set.

// The date format is in English, as a natural string of format with numbers as numerals,
// each segment separated by commas, and the last two segments separated by an "and". All
// zero-values are left out from the date, except in the special case when the time is not
// shown and the period is zero days, in which "0 days" is returned.

// Usage with jQuery:
//     $(document).ready(function() {
//         // Epoch "2012-01-06T02:52:00+02 in UTC
//         var epochd = new Date(Date.UTC(2012, 0, 6, 0, 52, 0));
//         var updateAge = function() {
//             $("#age").html(getDateDiffStr(new Date(epochd.getTime()), new Date(), false));
//         }
//         updateAge();
//         setInterval(updateAge, 1000); // Update once a second
//     });
// ...
//     <p> Age: <span id="age">(calculating...)</span> </p>
var vlumi;
if (typeof vlumi === "undefined") {
    vlumi = {};
}

vlumi.age = (function () {
    // Maps for constructing the date string.
    // These may be localized if needed.
    var partTitlesSingular = [" year", " month", " week", " day", " hour", " minute", " second"];
    var partTitlesPlural = [" years", " months", " weeks", " days", " hours", " minutes", " seconds"];
    var partTitlesShort = ["歳", "ヶ月", "週", "日", "", "", ""];
    var timeSeparator = ":";

    // Display the number with thousand-separators, with exactly <precision> decimals.
    var formatBignum = function (num, sep, precision) {
        var retstr = "0";
        var parts = [];
        var val;
        // Split the number into parts.
        do {
            val = num % 1000;
            if (num > 1000) {
                // Padding if in the middle of the number
                if (val < 10) {
                    val = "00" + val;
                } else if (val < 100) {
                    val = "0" + val;
                }
            }
            parts.unshift(val);
            num = Math.floor(num / 1000);
        } while (num > 0);

        // Collect the parts as a thousand-separated string
        if (parts.length > 0) {
            retstr = parts.join(sep);
        }

        // Always rounding down, not to reach milestones early.
        parts = retstr.split(".", 2);
        retstr = parts[0];
        if (precision > 0) {
            if (parts[1] === undefined) {
                parts[1] = "0";
            }
            if (parts[1].length > precision) {
                parts[1] = parts[1].substring(0, precision);
            } else {
                while (parts[1].length < precision) {
                    parts[1] += "0";
                }
            }
            retstr += "." + parts[1];
        }

        return retstr;
    };
    // Collect the date string parts.
    var getDateParts = function (diffDateParts, isShort, dateOnly) {
        var dateParts = [];
        var i, val, title;
        for (i = 0; i < diffDateParts.length; i++) {
            val = diffDateParts[i];
            if (val === 0 && (!dateOnly || dateParts.length > 0 || i < 3)) {
                continue;
            }
            title = (isShort
                    ? partTitlesShort[i]
                    : (val === 1 ? partTitlesSingular[i] : partTitlesPlural[i]));
            dateParts.push(formatBignum(val, ",", 0) + title);
        }
        if (dateParts.length === 0 && dateOnly) {
            // Default to "0 days"
            dateParts.push(0 + partTitlesPlural[3]);
        }
        return dateParts;
    };
    var getTimeParts = function (diffTimeParts) {
        var timeParts = [];
        var i, val;

        // Collect the time string parts.
        for (i = 0; i < diffTimeParts.length; i++) {
            val = diffTimeParts[i];
            if (val < 10) {
                val = "0" + val;
            }
            timeParts.push(val);
        }
        return timeParts;
    };
    var formatFullDate = function (startd, endd, format) {
        var years, months, weeks, days, hours, minutes, seconds,
                dateParts = [], timeParts = [], strParts = [],
                isShort = (format === "full_short" || format === "date_short"),
                dateOnly = (format === "date" || format === "date_short"),
                timeDiff, i;

        // Calculate full years and months; variable length, so needs looping.
        years = -1;
        while (startd < endd) {
            startd.setUTCFullYear(startd.getUTCFullYear() + 1);
            years++;
        }
        startd.setUTCFullYear(startd.getUTCFullYear() - 1);
        months = -1;
        while (startd < endd) {
            startd.setUTCMonth(startd.getUTCMonth() + 1);
            months++;
        }
        startd.setUTCMonth(startd.getUTCMonth() - 1);

        // Moved to within a month; calculate the rest from the millisecond difference.
        timeDiff = endd - startd;
        weeks = Math.floor((timeDiff / (1000 * 60 * 60 * 24 * 7)));
        days = Math.floor((timeDiff / (1000 * 60 * 60 * 24)) % 7);
        hours = Math.floor((timeDiff / (1000 * 60 * 60)) % 24);
        minutes = Math.floor((timeDiff / (1000 * 60)) % 60);
        seconds = Math.floor((timeDiff / 1000) % 60);

        dateParts = getDateParts([years, months, weeks, days], isShort, dateOnly);

        if (!dateOnly) {
            timeParts = getTimeParts([hours, minutes, seconds]);
        }

        // Join the parts together.
        if (isShort) {
            strParts.push(dateParts.join("<br/>"));
        } else if (dateParts.length > 1) {
            var lastDatePart = dateParts.pop();
            strParts.push([dateParts.join(", "), lastDatePart].join(" and "));
        } else {
            strParts.push(dateParts.join(", "));
        }

        if (!dateOnly) {
            strParts.push(timeParts.join(timeSeparator));
        }
        if (isShort) {
            return strParts.join("<br/>");
        }
        return strParts.join(", ");
    };
    // Years, taking leap years into account.
    var getYears = function (startd, endd, precision) {
        var years, timeLeft, timeGone, mul;

        // Count the number of full years by looping,
        // startd will be moved forwards.
        years = -1;
        while (startd < endd) {
            startd.setUTCFullYear(startd.getUTCFullYear() + 1);
            years++;
        }
        timeLeft = startd - endd;
        startd.setUTCFullYear(startd.getUTCFullYear() - 1);

        // Fractions from what's left after looping.
        timeGone = endd - startd;
        years += timeGone / (timeGone + timeLeft);

        mul = Math.pow(10, precision);
        return Math.floor(years * mul) / mul;
    };
    // Full months.
    var getMonths = function (startd, endd) {
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

        return months;
    };
    var getWeeks = function (startd, endd) {
        return (endd - startd) / (1000 * 60 * 60 * 24 * 7);
    };
    var getDays = function (startd, endd) {
        return (endd - startd) / (1000 * 60 * 60 * 24);
    };
    var getHours = function (startd, endd) {
        return (endd - startd) / (1000 * 60 * 60);
    };
    var getMinutes = function (startd, endd) {
        return (endd - startd) / (1000 * 60);
    };
    var getSeconds = function (startd, endd) {
        return (endd - startd) / 1000;
    };

    return {
        getDateDiffStr: function (p_startd, p_endd, format, precision) {
            var startd, endd, tempd, val, title_idx;

            startd = new Date(p_startd);
            endd = new Date(p_endd);

            if (startd > endd) {
                tempd = startd;
                startd = endd;
                endd = tempd;
            }

            if (format === "full" || format === "full_short" || format === "date" || format === "date_short") {
                return formatFullDate(startd, endd, format);
            }
            val = 0;
            title_idx = -1;

            if (format === "years") {
                val = getYears(startd, endd, precision);
                title_idx = 0;
            } else if (format === "months") {
                val = getMonths(startd, endd, precision);
                title_idx = 1;
            } else {
                // Full time difference, in milliseconds
                var val = "";
                if (format === "weeks") {
                    val = getWeeks(startd, endd);
                    title_idx = 2;
                } else if (format === "days") {
                    val = getDays(startd, endd);
                    title_idx = 3;
                } else if (format === "hours") {
                    val = getHours(startd, endd);
                    title_idx = 4;
                } else if (format === "minutes") {
                    val = getMinutes(startd, endd);
                    title_idx = 5;
                } else if (format === "seconds") {
                    val = getSeconds(startd, endd);
                    title_idx = 6;
                }
            }
            var title = (val === 1 ? partTitlesSingular[title_idx] : partTitlesPlural[title_idx]);

            return formatBignum(val, ",", precision) + title;
        }
    };
}());
