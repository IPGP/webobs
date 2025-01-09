(function($) {

    $.fn.wodp = function(options) {
        return this.each(function() {
            if (undefined == $(this).data('wodp')) {
                if ($(this).is("input")) {
                    var ME = new $.wodp(this, options);
                    $(this).data('wodp', ME);
                }
            }
        });
    }

    $.wodp = function(dominput, options) {

        // private defaults for options
        var defaults = {
            days: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"],
            months: ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"],
            range: { from: "1582-12-20" , to: "2038-01-18" },
            icon: false,
            popup: true,
            offX: 0, offY: 0,
            holidays: [
                { d: "$Y-01-01", t: "New Year" },
                { d: "$PQ 1", t: "Easter Monday" },
                { d: "$PQ 39", t: "Ascension" },
                { d: "$PQ 50", t: "Pentecost" },
                { d: "$Y-08-15", t: "Assumption" },
                { d: "$Y-11-01", t: "All Saints' Day" },
                { d: "$Y-12-25", t: "Christmas" },
            ],
            oninvalid: function() {},
            onpicked: function() {}
        }

        var ME = this;
        ME.settings = {}
        ME.holidays = [];
        ME.holidaysY = "";
        ME.selranging = "";
        ME.sel = "";
        var $dominput = $(dominput);
        var dominput = dominput;
        $dominput.data('wodpdesc','init');
        ME.clicker = $dominput;

        // public method to append calendar to dom
        ME.fill = function(arg) {
            $(html).insertAfter($dominput) ;
            var dominputId = $dominput.attr('id');
            var caltable = $dominput.next('table.wodp');
            var today = new Date();
            var tDate, inputvals;
            if ( arg == undefined ) {
                if ( ME.selranging == "" ) {
                    inputvals = $dominput.val().split(',');
                    ME.sel = { from: new Date(inputvals[0]), to: new Date(inputvals[1])}
                    if (isNaN(ME.sel.from.getDate())) {
                        if (inputvals != "") { ME.settings.oninvalid.call(); }
                        ME.sel.from = new Date(today.getWODate());
                    }
                    if (isNaN(ME.sel.to.getDate()))   ME.sel.to   = new Date(ME.sel.from.getWODate());
                    tDate = new Date(ME.sel.from.getWODate());
                } else {
                    tDate =new Date(ME.ref);
                    ME.sel = { from: new Date(ME.selranging), to: new Date(ME.ref)};
                }
            } else {
                tDate = new Date(arg);
                if (isNaN(tDate.getDate())) tDate = new Date(today.getWODate());
            }
            ME.ref = new Date(tDate.getWODate());
            if ($dominput.val() == "") $dominput.val(tDate.getWODate());
            buildHolidays(tDate.getFullYear());
            tDate.setDate(1);  // 1st of this month
            caltable.find('th span.wodpIdM').get(0).innerHTML = ME.settings.months[tDate.getMonth()];
            caltable.find('th span.wodpIdY').get(0).innerHTML = '&nbsp;'+tDate.getFullYear();
            tDate.setTime(tDate.getWeek().wstart); // monday of week containing 1st of this month

            var calbody = '';
            for (var d=0; d<=41; d++) { // 42 days from & including tDate
                var uDate = new Date(tDate.getFullYear(),tDate.getMonth(),tDate.getDate()+d);
                if ( uDate.getDay() == 1 ) {
                    var ws = new Date(uDate.getWeek().wstart); var we = new Date(uDate.getWeek().wend);
                    calbody += '<tr><th';
                    if (ws.isInRange(ME) && we.isInRange(ME)) {
                        calbody += ' onclick=$("#'+dominputId+'").data("wodp").clickWeek(event,"'+ws.getWODate();
                        calbody += ','+we.getWODate()+'")';
                    } else {
                        calbody += ' class=offside';
                    }
                    calbody += '>'+lz(uDate.getWeek().woy)+'</th>' ;
                }
                var clickable = true;
                var title = "";
                calbody += '<td class="';
                if ( uDate.toDateString() == today.toDateString() ) calbody += 'today';
                if ( uDate.getDay() == 0 || uDate.getDay() == 6 ) calbody += 'SD';
                for (var i=0; i<ME.holidays.length; i++) {
                    if (uDate.getWODate() == ME.holidays[i].d) { calbody +='off'; title = ME.holidays[i].t; }
                }
                if ( uDate.getFullYear() != ME.ref.getFullYear() || uDate.getMonth() != ME.ref.getMonth() ) calbody += 'notInM';
                if ( uDate.isInRange(ME.sel) ) calbody += ' insel';
                if ( !uDate.isInRange(ME) )
                     { calbody += ' offside'; clickable = false; }
                calbody += '" '; // end of class attribute
                if (title != "") {
                    calbody += 'title="'+title+'" ';
                }
                if (clickable) {
                    calbody += 'onclick=$("#'+dominputId+'").data("wodp").clickDay(event,"'+uDate.getWODate()+'")';
                }
                calbody += '>'+lz(uDate.getDate())+'</td>';
            }
            caltable.css({top: $dominput.position().top+ME.settings.offY, left: $dominput.position().left+ME.settings.offX });
            caltable.find('tbody.wodpBody').append($(calbody));
            caltable.find('th, td').css('cursor','default');
            var m0 = ME.from.getWODate(); var m1 = ME.to.getWODate();
            caltable.find('th.wodpPrevM').on('click',function(e){ ME.clickPrevMonth(e)}).css('cursor','pointer').attr('title','> '+m0);
            caltable.find('th.wodpNextM').on('click',function(e){ ME.clickNextMonth(e) }).css('cursor','pointer').attr('title','< '+m1);
            caltable.find('th span.wodpIdM').on('click',function(e){ ME.clickThisMonth(e) }).css('cursor','pointer');
            caltable.find('th span.wodpIdY').on('click',function(e){ ME.clickThisYear(e) }).css('cursor','pointer');
            caltable.find('th.wodpPrevY').on('click',function(e){ ME.clickPrevYear(e)}).css('cursor','pointer').attr('title','> '+m0);
            caltable.find('th.wodpNextY').on('click',function(e){ ME.clickNextYear(e) }).css('cursor','pointer').attr('title','< '+m1);
            if (ME.selranging == "") { caltable.find('[onclick]').css('cursor','pointer') }
            else { caltable.find('[onclick]').css('cursor','ew-resize') }
            if (!ME.settings.popup) caltable.css('box-shadow','none');
        }

        ME.clickDay = function(event,day) {
            var pos = $dominput.next('table.wodp').css('position');
            $dominput.next('table.wodp').remove();
            if (event.ctrlKey) {
                if (ME.selranging != "") {
                    if ( ME.selranging < day ) { $dominput.val(ME.selranging+','+day) }
                    else { $dominput.val(day+','+ME.selranging) }
                    $dominput.data('wodpdesc','range');
                    ME.selranging = "";
                } else {
                    $dominput.data('wodpdesc','ranging');
                    $dominput.val(day);
                    ME.ref = new Date(day);
                    ME.selranging = day;
                }
            } else {
                $dominput.val(day);
                ME.ref = new Date(day);
                ME.selranging = "";
                $dominput.data('wodpdesc','day');
            }
            if (!ME.settings.popup || ME.selranging != "") {
                ME.fill();
                $dominput.next('table.wodp').css('position',pos);
            }
            ME.settings.onpicked.call();
        }

        ME.clickWeek = function(event,week) {
            $dominput.val(week);
            $dominput.next('table.wodp').remove();
            if (!ME.settings.popup) {
                ME.fill();
                $dominput.next('table.wodp').css('position','inherit');
            }
            ME.selranging = "";
            $dominput.data('wodpdesc','week');
            ME.settings.onpicked.call();
        }

        ME.clickNextMonth = function(event) {    ME.clickMonth(event,+1); }

        ME.clickPrevMonth = function(event) {    ME.clickMonth(event,-1); }

        ME.clickMonth = function(event,way) {
            var pos = $dominput.next('table.wodp').css('position');
            var t = new Date(ME.ref.getTime());
            t.setMonth(t.getMonth()+way);
            if (t.isInRange(ME)) {
                $dominput.next('table.wodp').remove();
                ME.ref.setMonth(ME.ref.getMonth()+way);
                ME.fill(ME.ref.getWODate());
                $dominput.next('table.wodp').css('position',pos);
            }
        }

        ME.clickNextYear = function(event) { ME.clickYear(event,+1); }

        ME.clickPrevYear = function(event) { ME.clickYear(event,-1); }

        ME.clickYear = function(event,way) {
            var pos = $dominput.next('table.wodp').css('position');
            var t = new Date(ME.ref.getTime());
            t.setYear(t.getFullYear()+way);
            if (t.isInRange(ME)) {
                ME.ref.setFullYear(ME.ref.getFullYear()+way);
            } else {
                if (way>0) { ME.ref.setTime(ME.to.getTime()) }
                else       { ME.ref.setTime(ME.from.getTime()) }
            }
            $dominput.next('table.wodp').remove();
            ME.fill(ME.ref.getWODate());
            $dominput.next('table.wodp').css('position',pos);
        }

        ME.clickThisMonth = function(event) {
            $dominput.data('wodpdesc','month');
            ME.clickThisYM(event, new Date(ME.ref.getFullYear(),ME.ref.getMonth(),1,0,0,0,0), new Date(ME.ref.getFullYear(),ME.ref.getMonth()+1,0,0,0,0,0));
        }

        ME.clickThisYear = function(event) {
            $dominput.data('wodpdesc','year');
            ME.clickThisYM(event, new Date(ME.ref.getFullYear(),0,1,0,0,0,0), new Date(ME.ref.getFullYear(),11,31,0,0,0,0));
        }

        ME.clickThisYM = function(event,s,e) {
            if ( s.isInRange(ME) && e.isInRange(ME) ) {
                $dominput.val(s.getWODate()+','+e.getWODate());
                $dominput.next('table.wodp').remove();
                if (!ME.settings.popup) {
                    ME.fill();
                    $dominput.next('table.wodp').css('position','inherit');
                }
                ME.selranging = "";
                ME.settings.onpicked.call();
            }
        }

        // public function to validate user's manual input
        ME.inrange = function() {
            var invals = $dominput.val().split(','); var t;
            if (!invals[0].match(/\d{4}|\d{4}-\d{2}|\d{4}-\d{2}-\d{2}/)) return false;
            t = new Date(invals[0]); if (isNaN(t.getDate()) || !t.isInRange(ME)) return false;
            if (!invals[1] === undefined) {
                if (!invals[1].match(/\d{4}|\d{4}-\d{2}|\d{4}-\d{2}-\d{2}/)) return false;
                t = new Date(inputvals[1]); if (isNaN(t.getDate()) || !t.isInRange(ME)) return false;
            }
            return true;
        }


        // initialize
        extendDate();
        ME.settings = $.extend({}, defaults, options);
        ME.from = new Date(Date.parse(ME.settings.range.from));
        ME.to = new Date(Date.parse(ME.settings.range.to));

        var html =     '<table class="wodp">'+
                        '<thead class="wodpHead">'+
                            '<tr>'+
                                '<th class="wodpPrevY">&#9664;&#9664;&nbsp;</th><th class="wodpPrevM">&#9664;&nbsp;</th>'+
                                '<th colspan="4"><span class="wodpIdM"></span><span class="wodpIdY"></span></th>'+
                                '<th class="wodpNextM">&nbsp;&#9654;</th><th class="wodpNextY">&nbsp;&#9654;&#9654;</th>'+
                            '</tr>'+
                            '<tr><th>&nbsp;</th><th>'+ME.settings.days.join("</th><th>")+'</th></tr>'+
                        '</thead>'+
                        '<tbody class="wodpBody"></tbody>'+
                    '</table>';

        if (ME.settings.popup) {
            if (ME.settings.icon) {
                ME.clicker = $('<div class="wodpIcon">&nbsp;</div>').insertAfter($dominput) ;
            }
            ME.clicker.on('click',function() {
                if ($dominput.next('table.wodp').length) {
                    $dominput.next('table.wodp').remove();
                    $(document).off('keyup.wodpKeyup');
                } else {
                    $(document).on('keyup.wodpKeyup', function(e) {
                        if (e.keyCode == 27) {
                            $dominput.next('table.wodp').remove();
                            $(document).off('keyup.wodpKeyup');
                        }
                    });
                    ME.fill();
                }
            });
        } else {
            ME.fill();
            $dominput.next('table.wodp').css('position','inherit');
            ME.settings.onpicked.call();
        }

        // private method to extend Date Object
        function extendDate() {
            if (! Date.prototype.hasOwnProperty('getWeek')) {  // ISO week# , 1st and Last days
                Date.prototype.getWeek = function() {
                    var d = new Date(this.toDateString());     // clone date at 00:00:00
                    d.setDate(d.getDate() + 3 - (d.getDay() + 6) % 7); // Thursday this week
                    var w1 = new Date(d.getFullYear(), 0, 4);  // ISO says Jan 4 always in week #1
                    return {
                        woy:    1 + Math.round(((d.getTime() - w1.getTime()) / 86400000 - 3 + (w1.getDay() + 6) % 7) / 7),
                        wstart: d.setDate(d.getDate() - (d.getDay() + 6) % 7),
                        wend:   d.setDate(d.getDate() + 6 - (d.getDay() + 6) % 7)
                    }
                }
                Date.prototype.getEaster = function() {  // Easter date
                    var Y = this.getFullYear();
                    var H = (19*(Y%19) + Math.floor(Y/100) - Math.floor(Y/400) - Math.floor((8*Math.floor(Y/100) + 13)/25) + 15)%30;
                    var I = (Math.floor(H/28)*Math.floor(29/(H + 1)) * Math.floor((21 - Y%19)/11) - 1)*Math.floor(H/28) + H;
                    var J = (Math.floor(Y/4) + Y + I + 2 + Math.floor(Y/400) - Math.floor(Y/100))%7;
                    var D = I - J;
                    return new Date(Y,2,28+D);
                }
                Date.prototype.getWODate = function() {  // YYYY-MM-DD local
                    var d =  this.getFullYear()+'-';
                        d += (this.getMonth()+1 < 10) ? "0" : ""; d += (this.getMonth()+1)+'-';
                        d += (this.getDate() < 10) ? "0" : ""; d += this.getDate();
                    return d;
                }
                Date.prototype.isInRange = function(range) {  // is within Dates range.from and range.to
                    if ( isNaN(range.from) || isNaN(range.to) ) return true; // invalid range = can't tell = in range
                    range.from.setHours(0,0,0,0); range.to.setHours(0,0,0,0);
                    if ( (this.getTime() < range.from.getTime()) || (this.getTime() > range.to.getTime()) ) return false;
                    return true;
                }
            }
        }

        // private method to left-pad numeric with 0
        function lz(n) { return (n<10) ? "0"+n : n; }

        // private method to build holidays array for given year
        function buildHolidays(year) {
            var y  = new Date(year,0,1);
            if (ME.holidaysY != year) {
                var ES = y.getEaster();
                ME.holidays = [];
                for (var i=0; i<ME.settings.holidays.length; i++) {
                    ME.holidays[i] = { d: ME.settings.holidays[i].d, t: ME.settings.holidays[i].t };
                    var m = ME.settings.holidays[i].d;
                    if (m.match(/\$Y/))   { ME.holidays[i].d = m.replace(/\$Y/,year); }
                    if (m.match(/\$PQ$/)) { ME.holidays[i].d = ES.getWODate(); }
                    if (m.match(/\$PQ (\d*)$/)) { ME.holidays[i].d = m.replace(/\$PQ (.*)$/,
                                        function(a, b){ var s= new Date(ES); s.setDate(s.getDate()+parseInt(b,10)); return s.getWODate() } ) };
                }
                ME.holidaysY = year;
            }
        }
    }

})(jQuery);
