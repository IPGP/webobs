var lines = false;
var bars = true;
var datad = [];
var datah = [];
var datav = [];
var dataw = [];
var datam = [];
var datac = [];
var datasm = [];
var datag = [];
var data_energy = [];
var data_energy_total = [];
var plot;
var ylabel;

function plotFlot(gtype) {
    xmode = 'time';
    stack = true;
    lines = true;
    linewidth = 1;
    bars = false;
    fill = 0.7;
    points = false;
    ymin = 0;
    bw = 80000000;
    timeformat = null;
    shadowsize = 2;
    if (gtype == 'bars') {
        data = datad;
        ylabel = '# events per day';
        lines = false;
        bars = true;
    } else if (gtype == 'hbars') {
        data = datah;
        ylabel = '# events per hour';
        lines = false;
        bars = true;
        bw = 3300000;
    } else if (gtype == 'mcum') {
        data = datasm;
        ylabel = 'cum. seismic moment (Edyn.cm)';
    } else if (gtype == 'ncum') {
        data = datac;
        ylabel = 'cum. # events';
    } else if (gtype == 'ecum') {
        data = data_energy;
        ylabel = 'cum. energy (MJ)';
    } else if (gtype == 'ecum_total') {
        data = data_energy_total;
        ylabel = 'cum. energy (MJ)';
        fill = false;
        linewidth = 2;
        timeformat = '%Y-%m-%d';
        shadowsize = 0;
    } else if (gtype == 'gr') {
        data = datag;
        ylabel = '# events';
        xmode = null;
        stack = null;
        fill = null;
        linewidth = 2;
        points = true;
        ymin = -0.2;
    } else if (gtype == 'wsum') {
        data = dataw;
        ylabel = '# events per week';
    } else if (gtype == 'msum') {
        data = datam;
        ylabel = '# events per 28 days';
    } else {
        data = datav;
        ylabel = '# events per day';
    }
    options = {
        canvas: true,
        xaxis: {
            mode: xmode,
            timeformat: timeformat
        },
        yaxis: {
            min: ymin,
            minTickSize: 1,
            tickDecimals: 0,
        },
        axisLabels: {
            show: true
        },
        yaxes: [{
            axisLabelUseCanvas: true,
            position: 'left',
            axisLabel: ylabel
        }],
        series: {
            stack: stack,
            shadowSize: shadowsize,
            bars: {
                show: bars,
                fill: fill,
                barWidth: bw,
                align: 'center',
                lineWidth: 0
            },
            lines: {
                show: lines,
                fill: fill,
                lineWidth: linewidth
            },
            points: {
                show: points
            }
        },
        legend: {
            container: '#graphlegend'
        },
        grid: {
            hoverable: true,
            autoHighlight: false
        },
        crosshair: {
            mode: 'x',
            color: 'gray'
        },
        selection: {
            mode: 'x'
        },
    };
    plot = $.plot($('#mcgraph'), data, options);

    $('#mcgraph').bind('plothover', function(event, pos, item) {
        latestPosition = pos;
        if (!updateLegendTimeout) updateLegendTimeout = setTimeout(updateLegend, 50);
    });
    $('#mcgraph').bind('plotselected', function(event, ranges) {
        $.each(plot.getXAxes(), function(_, axis) {
            var opts = axis.options;
            opts.min = ranges.xaxis.from;
            opts.max = ranges.xaxis.to;
        });
        plot.setupGrid();
        plot.draw();
        plot.clearSelection();
    });
    $('#mcgraph').bind('plotunselected', function(event) {
        //plotAll();
    });

    var legends = $('#graphlegend .legendLabel');
    var time = new Date();
    var info = document.getElementById('graphinfo');
    var updateLegendTimeout = null;
    var latestPosition = null;

    function updateLegend() {
        updateLegendTimeout = null;

        var pos = latestPosition;

        var axes = plot.getAxes();
        if (pos.x < axes.xaxis.min || pos.x > axes.xaxis.max ||
            pos.y < axes.yaxis.min || pos.y > axes.yaxis.max)
            return;

        var i, j, dataset = plot.getData();
        var p = pos.x;
        if (xmode == 'time') {
            time.setTime(p);
            //if (document.formulaire.slt.value == 0) {
            info.textContent = time.toUTCString();
            //} else {
            //    info.textContent = time.toLocaleString();
            //}
        } else {
            info.innerHTML = 'M &ge; ' + p.toFixed(1);
        }
        if (gtype == 'bars') {
            p -= 1000 * 86400 / 2;
        }
        for (i = 0; i < dataset.length; ++i) {
            var series = dataset[i];
            // find the nearest points, x-wise
            for (j = 0; j < series.data.length; ++j)
                if (series.data[j][0] > p)
                    break;

            var y = series.data[j][1];
            if (gtype == 'mcum') {
                y = y.toFixed(1) + ' (10^18 dyn.cm)';
            }
            if (gtype == 'gr') {
                y = Math.pow(10, y).toFixed(0);
            }
            legends.eq(i).text(series.label.replace(/=.*\//, '= ' + y + '/'));
        }
    }
    cop();
}

function plotAll() {
    plot.setSelection({
        xaxis: {
            from: options.xaxis.min,
            to: options.xaxis.max
        }
    }, true);
    plot = $.plot($('#mcgraph'), data, options);
}

function cop(color) {
    var bgcolor = (typeof color == "undefined") ? "#fff" : color;
    var link = $("#tlsavelink");
    link.hidden;
    try {
        var canvas = plot.getCanvas();
        var context = canvas.getContext("2d");
        context.globalCompositeOperation = "destination-over";
        //context.fillStyle = "#fff";
        //context.fillRect(0,0,canvas.width,canvas.height);
        var canvasimg = canvas.toDataURL();
        link.attr('href', canvasimg);
        link.attr('download', 'WebObsMCgraph.png');
        link.show;
    } catch (e) {
        console.log("canvas op failed: " + e);
    }
}