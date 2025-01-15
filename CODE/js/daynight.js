var dtr = Math.PI / 180;
var mapWidth = 360;
var mapHeight = 180;
var pixelDegW = 360 / mapWidth;
var pixelDegH = 180 / mapHeight;
var centerDegW = (mapWidth / 2) * pixelDegW;
var centerDegH = (mapHeight / 2) * pixelDegH;
var K = Math.PI / 180.0;

function initDN(d, m, plots) {
    mapImage = new Image();
    mapImage.onload = function() {
        var map = document.getElementById("DNmap");
        map.width = mapWidth;
        map.height = mapHeight;
        var ctx = map.getContext("2d");
        ctx.drawImage(mapImage, 0, 0);
        drawDN(d);
        for (i = 0; i < plots.length; ++i) {
            drawCircle(ctx, pixelX(-1.0 * plots[i][1]), pixelY(plots[i][0]), 2, plots[i][2]);
        }
        //setInterval(function() {drawDN()},5000);
    };
    mapImage.src = m;
}

function drawDN(d) {
    var map = document.getElementById("DNmap");
    map.width = mapWidth;
    map.height = mapHeight;
    var ctx = map.getContext("2d");
    ctx.drawImage(mapImage, 0, 0);

    if (typeof d !== 'undefined') {
        // d is supposed to be a UTC date (provided by perl's gmtime).
        d = new Date(d);
        date = new Date(Date.UTC(d.getYear(), d.getMonth(), d.getDate(),
            d.getHours(), d.getMinutes(), d.getSeconds(),
            d.getMilliseconds()));
    } else {
        // Strange case, where no date was provided; use localtime from browser
        // (though this is a bad idea).
        date = new Date();
    }

    outdate = date.getUTCFullYear() + "/" + lz(date.getUTCMonth() + 1) + "/" + lz(date.getUTCDate()) + " " + lz(date.getUTCHours()) + ":" + lz(date.getUTCMinutes()) + ":" + lz(date.getUTCSeconds()) + " UTC";

    STD = date.getUTCHours() + (date.getUTCMinutes() / 60) + (date.getUTCSeconds() / 3600);
    dec = computeDeclination(date.getUTCDate(), date.getUTCMonth() + 1, date.getUTCFullYear(), STD);
    GHA = computeGHA(date.getUTCDate(), date.getUTCMonth() + 1, date.getUTCFullYear(), STD);

    x0 = 180;
    y0 = 90;
    ctx.fillStyle = "rgba(0, 0, 0, 0.5)";
    var F = (dec > 0) ? 1 : -1;
    x = x0 - Math.round(GHA);
    for (i = -x; x + i < 2 * x0; i++) {
        yy = computeLat(i, dec);
        yy1 = computeLat(i + 1, dec);
        //contour: ctx.fillRect(x+i, y0-yy, 1.5, -yy1+yy);
        //contour: if (i % 2 ==0) ctx.fillRect(x+i, y0-yy, 1.5, (F*90-2)+yy);
        ctx.fillRect(x + i, y0 - yy, 1, (F * 90 - 2) + yy + 1);
    }
    //sun: drawCircle(ctx, pixelX(GHA), pixelY(dec), 4, "#FFFF00");
    ctx.font = "10px Arial";
    ctx.fillStyle = "rgba(180, 0, 0, 1)";
    ctx.fillText(outdate, 10, 175);
}

//Sine of angles in degrees
function sind(x) {
    return Math.sin(dtr * x);
}

//Cosine of angles in degrees
function cosd(x) {
    return Math.cos(dtr * x);
}

//Tangent of angles in degrees
function tand(x) {
    return Math.tan(dtr * x);
}

//Truncate large angles
function trunc(x) {
    return 360 * (x / 360 - Math.floor(x / 360));
}

// Pixel coordinates
function pixelX(deg) {
    var offset = (deg < centerDegW) ? (centerDegW - deg) : (360 - deg + centerDegW);
    return offset / pixelDegW; // in 360 deg. space
}

function pixelY(deg) {
    return (centerDegH - deg) / pixelDegH;
}

// Canvas circle helper
function drawCircle(ctx, cx, cy, r, fill) {
    ctx.beginPath();
    ctx.arc(cx, cy, r, 0, Math.PI * 2, true);
    ctx.closePath();
    ctx.fillStyle = fill;
    ctx.fill();
    ctx.stroke();
}

function computeGHA(T, M, J, STD) {
    var N;
    var X, XX, P, NN;

    N = 365 * J + T + 31 * M - 46;
    if (M < 3) {
        N = N + parseInt((J - 1) / 4);
    } else {
        N = N - parseInt(0.4 * M + 2.3) + parseInt(J / 4.0);
    }
    P = STD / 24.0;
    X = (P + N - 7.22449E5) * 0.98564734 + 279.306;
    X = X * K;
    XX = -104.55 * Math.sin(X) - 429.266 * Math.cos(X) + 595.63 * Math.sin(2.0 * X) - 2.283 * Math.cos(2.0 * X);
    XX = XX + 4.6 * Math.sin(3.0 * X) + 18.7333 * Math.cos(3.0 * X);
    XX = XX - 13.2 * Math.sin(4.0 * X) - Math.cos(5.0 * X) - Math.sin(5.0 * X) / 3.0 + 0.5 * Math.sin(6.0 * X) + 0.231;
    XX = XX / 240.0 + 360.0 * (P + 0.5);
    if (XX > 360) {
        XX = XX - 360.0;
    }
    return XX;
}

function computeDeclination(T, M, J, STD) {
    var N;
    var X, XX, P, NN;
    var Ekliptik, J2000;

    N = 365 * J + T + 31 * M - 46;
    if (M < 3) {
        N = N + parseInt((J - 1) / 4);
    } else {
        N = N - parseInt(0.4 * M + 2.3) + parseInt(J / 4.0);
    }
    X = (N - 693960) / 1461.0;
    X = (X - parseInt(X)) * 1440.02509 + parseInt(X) * 0.0307572;
    X = X + STD / 24.0 * 0.9856645 + 356.6498973;
    X = X + 1.91233 * Math.sin(0.9999825 * X * K);
    X = (X + Math.sin(1.999965 * X * K) / 50.0 + 282.55462) / 360.0;
    X = (X - parseInt(X)) * 360.0;

    J2000 = (J - 2000) / 100.0;
    Ekliptik = 23.43929111 - (46.8150 + (0.00059 - 0.001813 * J2000) * J2000) * J2000 / 3600.0;
    X = Math.sin(X * K) * Math.sin(K * Ekliptik);

    return Math.atan(X / Math.sqrt(1.0 - X * X)) / K + 0.00075;
}

function computeLat(longitude, dec) {
    var tan, itan;
    tan = -Math.cos(longitude * K) / Math.tan(dec * K);
    itan = Math.atan(tan);
    itan = itan / K;
    return Math.round(itan);
}

function lz(n) {
    return (n < 10) ? "0" + n : n;
}