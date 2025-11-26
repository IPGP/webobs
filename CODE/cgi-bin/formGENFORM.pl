#!/usr/bin/perl

=head1 NAME

formGENFORM.pl

=head1 SYNOPSIS

http://..../formGENFORM.pl?form=FORMName[&id=id&return_url=url&action={new|edit|save|delete|restore|erase}]

=head1 DESCRIPTION

Edit form.

=head1 Configuration GENFORM

See 'showGENFORM.pl' for an example of configuration file 'FORM.GENFORM'

=head1 Query string parameter

=over

=item B<form=FORMName>

FORMName associated to the PROC.

=item B<id=>

data ID to edit. If void or inexistant, a new entry is proposed.

=item B<return_url=url>

URL to go back to showGENFORM.pl.

=item B<action=string>

action can be selected between [new|edit|save|delete|restore|erase].

=back

=cut

use strict;
use warnings;
use Time::Local;
use POSIX qw/strftime/;
use File::Basename;
use File::Path qw/make_path/;
use CGI;
my $cgi = new CGI;
$CGI::POST_MAX = 1024;
use DBI;
use CGI::Carp qw(fatalsToBrowser set_message);
use Fcntl qw(SEEK_SET O_RDWR O_CREAT LOCK_EX LOCK_NB);
use Locale::TextDomain('webobs');
use URI;
set_message(\&webobs_cgi_msg);

# ---- webobs stuff
use WebObs::Config;
use WebObs::Users qw($CLIENT %USERS clientMaxAuth);
use WebObs::Grids;
use WebObs::Utils;
use WebObs::i18n;
use Locale::TextDomain('webobs');
use WebObs::Form;

$ENV{LANG} = $WEBOBS{LOCALE};

# ---- standard FORMS inits ----------------------------------
my $form = $cgi->param('form');      # name of the form

# ---- Stops early if not authorized
my $clientAuth = clientMaxAuth(type=>"authforms",name=>"('$form')");
die "You can't edit records of the form $form. Please contact an administrator." if ($clientAuth < 2);

my %G = readForm($form);
my %FORM = %{$G{$form}};

my $form_url = URI->new("/cgi-bin/formGENFORM.pl");
my $client = $USERS{$CLIENT}{UID};

my $QryParm = $cgi->Vars;

# --- DateTime inits -------------------------------------
my $Ctod  = time();
my @tod  = localtime($Ctod);
my $today = strftime('%F %T',@tod);

# ---- Get the form data
# 
my $quality = $cgi->param('quality') // 0;
my $site    = $cgi->param('site');
my $comment = $cgi->param('comment') // "";

my $val     = $cgi->param('val');
my $user    = $cgi->param('user');
my $id      = $cgi->param('id') // "";
my $action   = checkParam($cgi->param('action'), qr/(new|edit|save|delete|restore|erase)/, 'action') // "edit";
my $return_url = $cgi->param('return_url');
my @operators  = $cgi->param('operators');
my $debug  = $cgi->param('debug');

my $starting_date = isok($FORM{STARTING_DATE});
my $stamp = "[$today $user]";
if (index($val,$stamp) eq -1) { $val = "$stamp $val"; };

# ---- specific FORM inits -----------------------------------

my @NODESSelList;
for (@{$FORM{NODESLIST}}) {
    my $id = $_;
    my %N = readNode($id);
    push(@NODESSelList,"$id|$N{$id}{ALIAS}: $N{$id}{NAME}");
}

my $sel_comment = "";

# ----

my $max_columns = count_columns(keys %FORM);
my @columns   = map { sprintf("COLUMN%02d_LIST", $_) } (1..$max_columns);
my $max_inputs = count_inputs(keys %FORM);
my @validity = split(/[, ]/, ($FORM{VALIDITY_COLORS} ? $FORM{VALIDITY_COLORS}:"#66FF66,#FFD800,#FFAAAA"));

my $MIN_HEIGHT = $GRIDS{GENFORM_THUMB_MIN_HEIGHT} || 10;
my $MAX_HEIGHT = $GRIDS{GENFORM_THUMB_MAX_HEIGHT} || 640;
my $DEFAULT_HEIGHT = $GRIDS{GENFORM_THUMB_DEFAULT_HEIGHT} || 50;
my $MIN_DELAY = $GRIDS{GENFORM_THUMB_MIN_DELAY} || 1;
my $MAX_DELAY = $GRIDS{GENFORM_THUMB_MAX_DELAY} || 5;
my $DEFAULT_DELAY = $GRIDS{GENFORM_THUMB_DEFAULT_DELAY} || 2;
my $THUMB_ANIM = $GRIDS{GENFORM_THUMB_ANIM} || "_anim.gif";
my $PATH_FORMDOCS = $GRIDS{SPATH_FORMDOCS} || "FORMDOCS";
my $PATH_THUMBNAILS = $GRIDS{SPATH_THUMBNAILS} || "THUMBNAILS";

my $LL_MIN_HEIGHT = $GRIDS{GENFORM_SHAPE_MIN_HEIGHT} || 150;
my $LL_MAX_HEIGHT = $GRIDS{GENFORM_SHAPE_MAX_HEIGHT} || 800;
my $LL_DEFAULT_HEIGHT = $GRIDS{GENFORM_SHAPE_DEFAULT_HEIGHT} || 300;

# ---- action is 'save'
#
# ---- registering data in WEBOBSFORMS.db
# --- connecting to the database
my $dbh = connectDbForms();
my $tbl = lc($form);
my $table_geoloc = "geoloc";
my $table_udate = "udate";
my @columns_geoloc = ("latitude", "northern_error", "longitude", "eastern_error", "elevation", "elevation_error");
my @columns_udate = ("date", "date_min", "yce", "yce_min");

# Main columns in the table without the primary key, start date, end date and inputs
my @db_columns = ("trash", "quality", "node", "operators", "comment", "tsupd", "userupd");
my @values = ("0", $quality, $site, join(",", @operators), $comment, $today, $user);
my $ncol = scalar(@db_columns) + 2; # number of columns without the primary key and inputs

# Local temp dir
my $temp_dir = ".tmp/".$CLIENT."/".uc($form);

if ($action eq 'save') {
    # ---- filling the database with the data from the form
    foreach (map { sprintf("input%02d", $_) } (1..$max_inputs)) {
        my $input;
        my @input = $cgi->param($_);
        if (scalar(@input) > 1) {
            $input = join(",", @input);
        } else {
            $input = $cgi->param($_);
        }

        push(@db_columns, $_);
        $input =~ s/"/""/g; # needs to escape quotes for the sqlite command
        push(@values, $input);
    }

    my $rv;
    my $msg;
    if ($id ne "") {
        $msg = "record #$id has been updated.";
        my $update = join(", ", map { "$_ = ?" } @db_columns);
        my $stmt = qq(UPDATE $tbl SET $update WHERE id = $id);
        my $sth = $dbh->prepare($stmt);
        $rv = $sth->execute(@values) or die $DBI::errstr;
    } else {
        $msg = "new record has been created.";
        my $columns_str = join(", ", @db_columns);
        my $placeholders = join(", ", ("?") x @db_columns);
        my $stmt = qq(INSERT INTO $tbl ($columns_str) VALUES ($placeholders));
        my $sth = $dbh->prepare($stmt);
        $rv = $sth->execute(@values) or die $DBI::errstr;
        $id = $dbh->last_insert_id(undef, undef, $tbl, undef);
    }

    if ($rv < 1) {
        $msg = "ERROR: formGENFORM couldn't access the database $form.";
    }

    # rename images tmp directory
    if ($id eq "") {
        my $temp_path = "$WEBOBS{ROOT_DATA}/$PATH_FORMDOCS/".$temp_dir;
        my $final_path = "$WEBOBS{ROOT_DATA}/$PATH_FORMDOCS/".uc($form."/record".$id);
        make_path($temp_path);
        if ( $CLIENT && $form && scalar <$temp_path/*> ) {
            make_path($final_path);
            qx(mv -T $temp_path $final_path);
            if ($?) { htmlMsgNotOK("Couldn't move $temp_path to $final_path; $!"); }
        }
    }

    my @fields = ("edate", "sdate");
    push(@fields, map { sprintf("input%02d", $_) } (1..$max_inputs));
    foreach (@fields) {
        my $type = $_ eq "edate" || $_ eq "sdate" ? $_ : $FORM{uc($_."_TYPE")};
        if ($type =~ /^(geoloc|datetime|udate|edate|sdate)/) {
            my @values;
            my @columns;
            my $table_input;
            if ($type =~ /^geoloc/) {
                push(@values, ($cgi->param($_."_latitude"), $cgi->param($_."_northern_error")));
                push(@values, ($cgi->param($_."_longitude"), $cgi->param($_."_eastern_error")));
                push(@values, ($cgi->param($_."_elevation"), $cgi->param($_."_elevation_error")));
                $table_input = $table_geoloc;
                @columns = @columns_geoloc;
            } elsif ($type =~ /^(datetime|udate|edate|sdate)/) {
                push(@values, (datetime2maxmin(get_date_input($_))));
                my $yce_max = defined $cgi->param($_."_yce") ? $cgi->param($_."_yce") : "";
                my $yce_min = defined $cgi->param($_."_yce_min") ? $cgi->param($_."_yce_min") : "";
                $yce_max = $yce_min if ! $yce_max;
                $yce_min = $yce_max if ! $yce_min;
                push(@values, $yce_max);
                push(@values, $yce_min);
                $table_input = $table_udate;
                @columns = @columns_udate;
            }

            map { $_ eq "" and $_ = undef } @values;
            my $stmt = qq(SELECT $_ FROM $tbl WHERE id = $id);
            my $iid = $dbh->selectrow_array($stmt);
            if ($id and defined($iid)) {
                my $update = join(", ", map { "$_ = ?" } @columns);
                my $stmt = qq(UPDATE $table_input SET $update WHERE id = $iid);
                my $sth = $dbh->prepare($stmt);
                my $rv = $sth->execute(@values) or die $DBI::errstr;
            } else {
                my $columns_str = join(", ", @columns);
                my $placeholders = join(", ", ("?") x @columns);
                my $stmt = qq(INSERT INTO $table_input ($columns_str) VALUES ($placeholders));
                my $sth = $dbh->prepare($stmt);
                my $rv = $sth->execute(@values) or die $DBI::errstr;
                my $lid = $dbh->last_insert_id(undef, undef, $table_input, undef);
                $rv = $dbh->do("UPDATE $tbl SET $_ = $lid WHERE id = $id") or die $DBI::errstr;
            }
        }
    }

    htmlMsgOK($msg);
    $dbh->disconnect();
    exit;
} elsif ($action eq "delete" && $id ne "") {
    my $stmt = qq(UPDATE $tbl SET trash = 1 WHERE id = $id);
    my $sth  = $dbh->prepare($stmt);
    my $rv   = $sth->execute() or die $DBI::errstr;

    htmlMsgOK("Record #$id has been moved to trash.");
    $dbh->disconnect();
    exit;
} elsif ($action eq "restore" && $id ne "") {
    my $stmt = qq(UPDATE $tbl SET trash = 0 WHERE id = $id);
    my $sth  = $dbh->prepare($stmt);
    my $rv   = $sth->execute() or die $DBI::errstr;

    htmlMsgOK("Record #$id has been recovered from trash.");
    $dbh->disconnect();
    exit;
} elsif ($action eq "erase" && $id ne "") {
    # Get foreign keys for the form table
    my $fk_sth = $dbh->prepare("PRAGMA foreign_key_list('$tbl')");
    $fk_sth->execute();

    # Delete rows in table referenced by foreign keys
    while (my @row = $fk_sth->fetchrow_array) {
        $dbh->do("DELETE FROM @row[2] WHERE id IN (SELECT @row[3] FROM $tbl WHERE id = ?)", undef, $id) or die $DBI::errstr;
    }
    $fk_sth->finish();

    $dbh->do("DELETE FROM $tbl WHERE id = ?", undef, $id) or die $DBI::errstr;

    # delete images directory
    if ($form ne "" && $id ne "") {
        my $path = "$WEBOBS{ROOT_DATA}/$PATH_FORMDOCS/".uc($form."/record".$id);
        qx(rm $path -R);
    }

    htmlMsgOK("Record #$id has been permanently erased from database $form.");
    $dbh->disconnect();
    exit;
}

# ---- if we reach this point action is 'edit' (default) or 'new'
#

$form_url->query_form('form' => $form, 'id' => $id, 'return_url' => $return_url, 'action' => 'save');

# make a list of formulas
my @formulas;
foreach (sort keys %FORM) {
    if ($_ =~ /^OUTPUT.*_TYPE/ && $FORM{$_} =~ /^formula/) {
        push(@formulas, (split /_TYPE/, $_)[0]);
    }
}

# make a list of thresholds
my @thresh;
foreach (keys %FORM) {
    if ($_ =~ /^(IN|OUT)PUT.*_THRESHOLD/) {
        push(@thresh, (split /_THRESHOLD/, $_)[0]);
    }
}

# ---- Start HTML display
#
print qq[Content-type: text/html

<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>
<head>
<title>] . $FORM{NAME} . qq[</title>
<link rel="stylesheet" type="text/css" href="/$WEBOBS{FILE_HTML_CSS}">
<link rel="stylesheet" href="/css/leaflet.css" crossorigin=""/>
<meta http-equiv="content-type" content="text/html; charset=utf-8">
<script language="javascript" type="text/javascript" src="/js/jquery.js"></script>
<script language="javascript" type="text/javascript" src="/js/comma2point.js"></script>
<script language="javascript" type="text/javascript" src="/js/math.js"></script>
<script src="/js/leaflet.js" crossorigin=""></script>
<script type="text/javascript">
<!--
function update_form()
{
    var form = document.form;

    var yy2 = document.getElementsByName("edate_year");
    var mm2 = document.getElementsByName("edate_month");
    var dd2 = document.getElementsByName("edate_day");
    var hr2 = document.getElementsByName("edate_hr");
    var mn2 = document.getElementsByName("edate_mn");

    var yy1 = document.getElementsByName("sdate_year");
    var mm1 = document.getElementsByName("sdate_month");
    var dd1 = document.getElementsByName("sdate_day");
    var hr1 = document.getElementsByName("sdate_hr");
    var mn1 = document.getElementsByName("sdate_mn");

    if (yy1[0]) {
        var date1 = new Date(yy1[0].value, mm1[0].value, dd1[0].value, hr1[0].value, mn1[0].value);
        var date2 = new Date(yy2[0].value, mm2[0].value, dd2[0].value, hr2[0].value, mn2[0].value);
        duration = (date2.getTime() - date1.getTime())/86400000;
        form.duration.value = duration.toFixed(1);
    } else {
        form.duration.value = "0";
    }
];
foreach my $f (@formulas) {
    my ($formula, $size, @x) = extract_formula($FORM{$f."_TYPE"});
    # any word followed by an open parenthesis is supposed to be a math function (see math.js)...
    $formula =~ s/\b(pi)\b/Math.PI/ig;
    $formula =~ s/(\w+\()/math.$1/g;
    foreach ("mean", "std", "median") {
        $formula =~ s/math.$_\((.*)\)/math.$_([$1].filter(x => !Number.isNaN(x)))/g;
    }

    foreach (@x) {
        my $form_input = lc($_);
        $formula =~ s/$_/Number(form.$form_input.value ? form.$form_input.value : NaN)/g;
    }
    print "try {";
    print "form.".lc($f).".value = parseFloat($formula).toFixed(2);\n";
    print "} catch(err) { form.".lc($f).".value = NaN; console.error(err.message); };\n";
}
foreach (@thresh) {
    my $f = lc($_);
    my @tv = split(/[, ]/,$FORM{$_."_THRESHOLD"});
    if ($#tv > 0) {
        print qq(
    form.$f.style.background = "$validity[0]";
    if (Math.abs(form.$f.value) >= $tv[0]) {
        form.$f.style.background = "$validity[1]";
    }
    if (Math.abs(form.$f.value) >= $tv[1]) {
        form.$f.style.background = "$validity[2]";
    }
        );
    }
}

print qq[
}

function suppress(level)
{
    var str = "$FORM{NAME} ?";
    if (level > 1) {
        if (!confirm("$__{'ATT: Do you want PERMANENTLY erase this record from '}" + str)) {
            return false;
        }
        document.form.action.value = 'erase';
    } else {
        if (level == 1) {
            if (!confirm("$__{'Do you want to remove this record from '}" + str)) {
                return false;
            }
            document.form.action.value = 'delete';
        } else {
            if (!confirm("$__{'Do you want to restore this record in '}" + str)) {
                return false;
            }
            document.form.action.value = 'restore';
        }
    }
    document.form.delete.value = level;
    submit();
}

function verif_re(element)
{
    
}

function verif_form()
{
    var cboxs = document.querySelectorAll("input[type=checkbox]");
    Array.from(cboxs).forEach((cbox) => {
        if (cbox.checked) {
            cbox.value = "checked";
        } else { cbox.value = ""; }
    });
    console.log(\$("#theform"));
    if(document.form.site.value == "") {
        alert("$__{'You must select a node associated to this record!'}");
        document.form.site.focus();
        return false;
    }

    var form = document.getElementById("theform");
    var inputs = form.elements;
    for (var i = 0; i < inputs.length; i++) {
        if (inputs[i].type === "text" || inputs[i].type === "email" || inputs[i].type === "textarea") {
            inputs[i].value = inputs[i].value.trim();
        }
    }

    /*var inputs = document.querySelectorAll('input[name\$="_yce_min"]');
    Array.from(inputs).forEach((yce_min) => {
        var basename = yce_min.name.split("_yce_min")[0];
        var yce = document.querySelector('input[name=' + basename + '_yce]');
        if (yce.value < yce_min.value) {
            event.preventDefault();
            yce_min.focus();
            alert(yce_min.name + " must be inferior to " + yce.name);
            return false;
        }
    });*/

    console.log(\$("#theform").serialize());
    submit();
}

function submit()
{
    \$.post("]. $form_url . qq[", \$("#theform").serialize(), function(data) {\n]
            .(isok($WEBOBS{CGI_CONFIRM_SUCCESSFUL})? "alert(data);":""). qq[
            // Redirect the user to the form display page while keeping the previous filter
            document.location="] . $cgi->param('return_url') . qq[";
        }
    );
}

function updateMap(map_id, geojson, lat, lon, zoom=10) {
    var map = L.map(map_id).setView([lat, lon], zoom);
    L.tileLayer('http://{s}.tile.osm.org/{z}/{x}/{y}.png').addTo(map);
    L.control.scale( { metric: true, imperial: false } ).addTo(map);
    if (geojson == "not_found") {
        console.error("No valid shape file found.")
    } else {
        fetch(geojson)
            .then((response) => {
                return response.json()
            })
            .then((data) => {
                var geojsonLayer = L.geoJson(data, {
                    pointToLayer: function(feature, latlng){
                        return L.circleMarker(latlng, {color: '#3d85c6', radius: 4});
                    },
                    onEachFeature: function (feature, layer) {
                        var popupcontent = [];
                        for (var prop in feature.properties) {
                            popupcontent.push(prop + ": " + feature.properties[prop]);
                        }
                        layer.bindPopup(popupcontent.join("<br />"));
                    }
                }).addTo(map);
                map.fitBounds(geojsonLayer.getBounds());
            })
            .catch((error) => {
                console.log(error)
            })
    }
}
//-->
</script>
</head>

<body>
    <div id="overDiv" style="position:absolute; visibility:hidden; z-index:1000;"></div>
    <!-- overLIB (c) Erik Bosrup -->
    <script language="javascript" src="/js/overlib/overlib.js"></script>
    <div id="helpBox"></div>
    <script type="text/javascript">

    // Prevent the Return key from submitting the form
    function stopRKey(evt) {
        var evt = (evt) ? evt : ((event) ? event : null);
        var node = (evt.target) ? evt.target : ((evt.srcElement) ? evt.srcElement : null);
        if ((evt.keyCode == 13) && (node.type=="text")) {return false;}
    }
    document.onkeypress = stopRKey;

    // Once the document is loaded
    \$(document).ready(function() {
        // Update the form immediately
        update_form();
        // Also update the form when any of its element is changed
        \$('#theform').on("change", update_form);
        // Also update when a key is pressed in the form
        // but wait 0.5s for the previous handler execution to finish
        \$('#theform').on("keydown", function() { setTimeout(update_form, 500); });

        document.querySelectorAll("div[id*='_shape']").forEach((item) => {
            var geojson = item.getAttribute("geojson");
            var lat = item.getAttribute("lat");
            var lon = item.getAttribute("lon");
            updateMap(item, geojson, lat, lon);
        });

        const dateInputs = document.querySelectorAll("select[name*='_month'], select[name*='_day']").forEach(item => {
            item.addEventListener("change", function() {
                if (item.value == "") {
                    const name = item.name.split("_")[0];
                    const day = document.querySelector("select[name=" + name + "_day]");
                    const hr = document.querySelector("select[name=" + name + "_hr]");
                    const mn = document.querySelector("select[name=" + name + "_mn]");
                    const sec = document.querySelector("select[name=" + name + "_sec]");
                    if (hr) { hr.value = ""; }
                    if (mn) { mn.value = ""; }
                    if (sec) { sec.value = ""; }
                    if (day && item.name.match(/month/)) { day.value = ""; }
                }
            });
        });
   });

    window.addEventListener("pageshow", function (event) {
        if (event.persisted) {
            setTimeout(() => { window.location.reload(); }, "500");
        }
    });
    </script>
];

# ---- read data file
#
my $title2;
my $recinfo;
my $val;
my %prev_inputs;
my $trash;

my @edate_vals;
my @sdate_vals;

# --- connecting to the database
my $dbh = connectDbForms();

if ($action eq "edit") {
    my $tbl = lc($form);

    my $stmt = qq(SELECT * FROM $tbl WHERE id = $id); # selecting the row corresponding to the id of the record we want to modify
    my $sth = $dbh->prepare($stmt);
    my @colnam = @{ $sth->{NAME_lc} };
    my $rv = $sth->execute() or die $DBI::errstr;

    my ($edate, $sdate, $opers, $ts0, $user);
    while(my @row = $sth->fetchrow_array()) {
        ($trash, $quality, $site, $edate, $sdate, $opers, $sel_comment, $ts0, $user) = @row[1..$ncol];
        @operators = split(/,/,$opers);
        push(@operators,$user) if (@operators =~ /^$user$/);
        for (my $i = $ncol+1; $i <= $#row; $i++) {
            $prev_inputs{$colnam[$i]} = $row[$i];
        }
    }

    my $colnames = join(', ', @columns_udate);
    my $stmt = qq(SELECT $colnames FROM $table_udate WHERE id = $edate);
    @edate_vals = $dbh->selectrow_array($stmt);

    if ($sdate) {
        my $stmt = qq(SELECT $colnames FROM $table_udate WHERE id = $sdate);
        @sdate_vals = $dbh->selectrow_array($stmt);
    }

    $title2 = "$__{'Edit record n°'} $id";
    $title2 = "<SPAN class=\"inTrash\">$title2</SPAN>" if ($trash);
    $val = $ts0 ? "$ts0" : "";
    $val .= $user ? " [$user]" : "";
    if ($val ne "") {
        $recinfo = "<P><B>$__{'Record timestamp:'}</B> $val</P>";
    }
    if ($action eq "edit" && $id ne "") {
        if ($trash eq "1") {
            $title2 .= qq(&nbsp;<A href="#"><IMG src="/icons/restore.png" onClick="suppress(-1);" title="$__{'Restore'}"></A>);
        } else {
            $title2 .= qq(&nbsp;<A href="#"><IMG src="/icons/trash.png" onClick="suppress(1);" title="$__{'Remove'}"></A>);
        }
        if ($clientAuth > 2) {
            $title2 .= qq(&nbsp;<A href="#"><IMG src="/icons/no.png" onClick="suppress(2);" title="$__{'Erase'}"></A>);
        }
    }
} else {
    $title2 = "$__{'Input new record'}";
    @operators = ("$client");
}

if ($debug) {
    print "<P>".join(',',sort(keys(%FORM)))."</P>\n";
    print "<P>".join(',',@formulas)."</P>\n";
    print "<P>".join(',',@thresh)."</P>\n";
    print "<P>max_inputs = $max_inputs</P>\n";
}

print qq[<form name="form" id="theform" action="">
<input type="hidden" name="val" value="$val">
<input type="hidden" name="id" value="$id">
<input type="hidden" name="user" value="$client">
<input type="hidden" name="trash" value="$trash">
<input type="hidden" name="delete" value="">
<input type=\"hidden\" name=\"action\" value="save">
<input type=\"hidden\" name=\"form\" value=\"$form\">

<table width="100%">
  <tr>
    <td style="border: 0">
     <h1>$FORM{NAME}</h1>
     <h2>$title2</h2>
];

if (isok($FORM{QUALITY_CHECK})) {
    my @uid = ();
    foreach (split(/[, ]/, $FORM{QUALITY_OPERATORS})) {
        if (rindex($_,'+',0) == 0) {
            foreach my $u (WebObs::Users::groupListUser("$_")) {
                push(@uid, $u) if (!grep(/^$u$/, @uid));
            }
        } else {
            push(@uid, $_);
        }
    }
    my $qualOK = ($clientAuth>2 || grep(/^$USERS{$CLIENT}{UID}$/,@uid));
    print "<P><input type=\"checkbox\"".($quality ? " checked":"")
      .(!$qualOK ? " disabled=\"disabled\"":"")
      ." name=\"quality\" value=\"1\" onMouseOut=\"nd()\" onmouseover=\"overlib('$__{'help_genform_quality'}')\">"
      .(!$qualOK ? "<input name=\"quality\" type=\"hidden\" value=\"".($quality ? "1":"")."\">":"")
      ."<b>$__{'Validated record'}</b></P><BR>";
} else {
    print "<input type=\"hidden\" name=\"quality\" value=\"$quality\">";
}

print qq[</td>
  </tr>
</table>
<table style="border: 0" >
  <tr>
    <td style="border: 0" valign="top">
        <fieldset>
        <legend>$__{'Where, When, and Who'}</legend>
        <p class="parform" align=\"right\">
];

# Add mandatory site input
print qq(<B>$__{'Site'}: </B>
      <select name="site" size="1"
        onMouseOut="nd()" onMouseOver="overlib('$__{'Select a node for this record'}')">
      <option value=""></option>);
print @NODESSelList;
for (@NODESSelList) {
    my @cle = split(/\|/,$_);
    my $sel = ($cle[0] eq $site ? "selected":($action eq "edit" ? "disabled":""));
    print qq(<option $sel value="$cle[0]">$cle[1]</option>);
}
print qq(</select><BR>);

if ($starting_date) {
    datetime_input(\%FORM, "sdate", \@sdate_vals, "Start Date");
    datetime_input(\%FORM, "edate", \@edate_vals, "End Date");
    if ($FORM{BANG}) {
        print qq(<B>$__{'Duration'} =</B> <input size=5 readOnly class=inputNumNoEdit name="duration"> $__{'days'}<BR>);
    } else {
        print qq(<input type="hidden" name="duration">);
    }
} else {
    datetime_input(\%FORM, "edate", \@edate_vals);
    print qq(<input type="hidden" name="duration">);
}

# Add mandatory operator input
print qq(<table><tr><td style="border:0"><B>$__{'Operator(s)'}:</B> </td><td style="border:0">
            <select name="operators" size="5" multiple="multiple"
                onMouseOut="nd()" onmouseover="overlib('$__{'Select operator(s)'}')">);
my @uid = @operators; # $client if 'new', or @operators if 'edit'
foreach my $op (split(/[, ]/, $FORM{OPERATORS_LIST})) {
    if ($op =~ /^+/) {
        foreach my $u (WebObs::Users::groupListUser("$op")) {
            push(@uid, $u) if (!grep(/^$u$/, @uid));
        }
    } else {
        push(@uid, $op) if (!grep(/^$op$/, @uid));
    }
}
foreach my $u (@uid){
    my $sel = (grep(/^$u$/, @operators) ? "selected":"");
    print "<option value=\"$u\" $sel>$u: ".join('',WebObs::Users::userName($u))."</option>\n";
}
print qq(</select>
    </td></tr></table>
    </P>
    </fieldset>);

# Add user defined inputs
foreach (@columns) {
    my $col = $_ =~ s/_LIST//r;
    unless ($_ =~ "01") {
        print "</TD>\n<TD style=\"border:0\" valign=\"top\">";
    }
    foreach my $fieldset (split(/[, ]/, $FORM{$_})) {
        print "<fieldset><legend>".$FORM{"$fieldset\_NAME"}."</legend>";
        print "<table width=\"100%\"><tr>";
        my ($fscells,$fsdir) = split(/[, ]/,$FORM{"$fieldset\_CELLS"});
        my $row = ($fsdir =~ /ROWS/i ? "1":"0"); # true if splitted into rows
        my $dlm = ($row ? "&emsp;&emsp; ":"<BR>");
        foreach my $fs (1..$fscells) {
            print qq(<td style="border:0" valign="top"><p class="parform" align="right">);
            my $fsc = sprintf("$fieldset\_C%02d", $fs);
            foreach my $Field (split(/[, ]/, $FORM{$fsc})) {
                my $name = $FORM{"$Field\_NAME"};
                my $unit = $FORM{"$Field\_UNIT"};
                my $type = $FORM{"$Field\_TYPE"};
                my $help = htmlspecialchars($FORM{"$Field\_HELP"});
                my $field = lc($Field);
                my $input_id = ( $action eq "new" ? $temp_dir : uc($form."/record".$id) )."/".$Field;
                my ($size, $default) = extract_type($type);
                if ($action ne 'edit' && $default ne "") {
                    $prev_inputs{$field} = $default;
                }
                my $txt = "<B>$name</B>".($unit ne "" ? " ($unit)":"");
                my $hlp;

                # --- INPUT type 'list'
                if ($field =~ /^input/ && $type =~ /^list/) {
                    my %list = extract_list($type,$form);
                    my @list_keys = sort { $list{$a}{'_SO_'} <=> $list{$b}{'_SO_'} } keys %list;
                    $hlp = ($help ne "" ? $help:"$__{'Select a value for'} $Field");

                    # if list contains an icon column (HoH), displays radio button instead of select list
                    if ($list{$list_keys[0]}{icon}) {
                        print "$txt =";
                        for my $k (@list_keys) {
                            my $selected = ($prev_inputs{$field} eq "$k" ? "checked":"");
                            print qq(&nbsp;<input name="$field" type=radio value="$k" $selected
                            onMouseOut="nd()" onmouseover="overlib('$list{$k}{name}')"><IMG src="$list{$k}{icon}">);
                        }
                        print "$dlm";
                    } else {
                        my $multi = ( $size eq "multiple" ? "multiple" : "" );
                        print qq($txt = <select name="$field"
                            onMouseOut="nd()" onmouseover="overlib('$hlp')" $multi><option value=""></option>);
                        for (@list_keys) {
                            my $nam = ($list{$_}{name} ? $list{$_}{name}:$list{$_}{value});
                            my $selected = ( $prev_inputs{$field} =~ /^$_$/ ? "selected" : "" );
                            print qq(<option value="$_" $selected>$nam</option>);
                        }
                        print "</select>$dlm";
                    }

                # --- INPUT type 'users'
                } elsif ($field =~ /^input/ && $type =~ /^users/) {
                    $hlp = ($help ne "" ? $help:"$__{'Select users for '} $Field");
                    my @seluid = split(/[, ]+/,$prev_inputs{$field});
                    push(@seluid,$user) if (@seluid =~ /^$user$/); # adds loggued user if necessary
                    my @uid = @seluid;
                    foreach my $op (split(/[, ]/, $default)) {
                        if ($op =~ /^+/) {
                            foreach my $u (WebObs::Users::groupListUser("$op")) {
                                push(@uid, $u) if (!grep(/^$u$/, @uid));
                            }
                        } else {
                            push(@uid, $op) if (!grep(/^$op$/, @uid));
                        }
                    }
                    print qq(<table><tr><td style="border:0">$txt: </td><td style="border:0"><select name="$field" size="$size" multiple="multiple"
                        onMouseOut="nd()" onmouseover="overlib('$hlp')">);
                    foreach my $u (@uid){
                        my $sel = (grep(/^$u$/, @seluid) ? "selected":"");
                        print "<option value=\"$u\" $sel>$u: ".join('',WebObs::Users::userName($u))."</option>\n";
                    }
                    print qq(</select></td></tr></table>$dlm);

                # --- INPUT type 'text'
                } elsif ($field =~ /^input/ && $type =~ /^text/) {
                    $hlp = ($help ne "" ? $help:"$__{'Enter a value for'} $Field");
                    my $value = $prev_inputs{$field};
                    $value =~ s/"/&quot;/g;
                    print qq($txt = <input type="text" size=$size name="$field" value="$value"
                        onMouseOut="nd()" onmouseover="overlib('$hlp')">$dlm);

                # --- INPUT type 'checkbox'
                } elsif ($field =~ /^input/ && $type =~ /^checkbox/) {
                    $hlp = ($help ne "" ? $help:"$__{'Click to select'} $Field");
                    my $selected = ($prev_inputs{$field} ? "checked" : "");
                    print qq($txt <input type="checkbox" name="$field" $selected onMouseOut="nd()" onmouseover="overlib('$hlp')">$dlm);

                # --- INPUT type 'image'
                } elsif ($field =~ /^input/ && $type =~ /^image/) {
                    my $height = $size ? $size : $DEFAULT_HEIGHT;
                    $height = ( ( $height >= $MIN_HEIGHT && $height <= $MAX_HEIGHT ) ? $height : $DEFAULT_HEIGHT );
                    my $delay = ( ( $default >= $MIN_DELAY && $default <= $MAX_DELAY ) ? $default : $DEFAULT_DELAY );
                    my $base_url = "formUPLOAD.pl?object=$input_id&doc=SPATH_GENFORM_IMAGES&form=$form&height=$height&delay=$delay";
                    my $upload_path = "$WEBOBS{ROOT_DATA}/$PATH_FORMDOCS/$input_id";
                    if ( -e "$upload_path/$PATH_THUMBNAILS/$THUMB_ANIM" ) {
                        print qq(<img height=$height src="/data/$PATH_FORMDOCS/$input_id/$PATH_THUMBNAILS/$THUMB_ANIM" style="margin-bottom:5px" border=1">);
                    }
                    print qq(<br><button onclick="location.href='$base_url'" type="button" style="float:center;">);
                    print qq(<img src="/icons/upload.png" style="vertical-align: middle;">$txt</button>);
                    my $nb = qx(ls $upload_path -p | grep -v / | wc -l);
                    print qq(<input type="hidden" name="$field" value=$nb>\n);

                # --- INPUT type 'shapefile'
                } elsif ($field =~ /^input/ && $type =~ /^shapefile/) {
                    my $height = $size ? $size : $DEFAULT_HEIGHT;
                    $height = ( ( $height >= $LL_MIN_HEIGHT && $height <= $LL_MAX_HEIGHT ) ? $height : $LL_DEFAULT_HEIGHT )."px";
                    my $base_url = "formUPLOAD.pl?object=$input_id&doc=SHAPEFILE";
                    if ($site) {
                        my %S = readNode($site, "novsub");
                        if (%S) {
                            my %node = %{$S{$site}};
                            if (%node) {
                                my ( $lat, $lon ) = ( $node{LAT_WGS84}, $node{LON_WGS84} );
                                my $geojson = "$PATH_FORMDOCS/$input_id/shape.json";
                                $geojson = ( ( -f "$WEBOBS{ROOT_DATA}/$geojson" ) ? "/data/$geojson" : "not_found" );
                                print qq(<div id=$field\_shape geojson=$geojson lat=$lat lon=$lon style="height: $height;"></div>);
                            }
                        }
                    }
                    print qq(<br><button onclick="location.href='$base_url'" type="button" style="float:right;">);
                    print qq(<img src="/icons/upload.png" style="vertical-align: middle;"> $txt</button>);

                # --- INPUT type 'geoloc'
                } elsif ($field =~ /^input/ && $type =~ /^geoloc/) {
                    my @gvals = map { "" } @columns_geoloc;
                    if ($prev_inputs{$field}) {
                        my $colnames = join(', ', @columns_geoloc);
                        my $stmt = qq(SELECT $colnames FROM $table_geoloc WHERE id = $prev_inputs{$field});
                        @gvals = $dbh->selectrow_array($stmt);
                    }
                    my @msgs = ("a latitude", "a northern error", "a longitude", "an eastern error", "an elevation", "an elevation error");
                    my @units = ("decimal degrees", "meters", "decimal degrees", "meters", "meters", "meters");
                    print "<table>";
                    foreach my $j (0 .. scalar(@columns_geoloc) - 1) {
                        print $j % 2 eq 0 ? "<tr>" : "";
                        $hlp = ($help ne "" ? $help:"$__{'Enter '.$msgs[$j].' (in '.$units[$j].') for'} $Field");
                        print qq(<td class="udateRow"><label> $columns_geoloc[$j] =</label><input type="text" pattern="[0-9\\.\\-]*" size="$size" class="inputNum"
                            name="$field\_$columns_geoloc[$j]" value="$gvals[$j]"
                            onMouseOut="nd()" onmouseover="overlib('$hlp')"></td>);
                        print $j % 2 eq 1 ? "</tr>" : "";
                    }
                    print "</table>";

                # --- INPUT type 'udate'
                } elsif ($field =~ /^input/ && $type =~ /^(datetime|udate)/) {
                    my @uvals;
                    if ($prev_inputs{$field}) {
                        my $colnames = join(', ', @columns_udate);
                        my $stmt = qq(SELECT $colnames FROM $table_udate WHERE id = $prev_inputs{$field});
                        @uvals = $dbh->selectrow_array($stmt);
                    }
                    datetime_input(\%FORM, $field, \@uvals);

                # --- INPUT type 'numeric' (default)
                } elsif ($field =~ /^input/) {
                    $hlp = ($help ne "" ? $help:"$__{'Enter a numerical value for'} $Field");
                    print qq($txt = <input type="text" pattern="[0-9\\.\\-]*" size=$size class=inputNum name="$field" value="$prev_inputs{$field}"
                        onMouseOut="nd()" onmouseover="overlib('$hlp')">$dlm);

                # --- OUTPUT type 'formula'
                } elsif ($field =~ /^output/ && $type =~ /^formula/) {
                    my ($formula, $size, @x) = extract_formula($type);
                    if ($size > 0) {
                        $hlp = ($help ne "" ? $help:"$Field = $formula");
                        print qq(<B>$name</B> = <input size=$size readOnly class=inputNumNoEdit name="$field"
                        onMouseOut="nd()" onmouseover="overlib('$hlp')">&nbsp;$unit$dlm);
                    } else {
                        print qq(<input type="hidden" name="$field">);
                    }

                # --- OUTPUT type 'text'
                } elsif ($field =~ /^output/ && $type =~ /^text/) {
                    my $text = extract_text($type);
                    print $txt.($text ne "" ? ": $text":"").$dlm;
                } else {
                    print qq(<input type="hidden" name="$field">\n);
                }
            }
            print "</p></td>";
            print "</tr>\n<tr>" if ($row && $fs ne $fscells);
        }
        print "</tr></table></fieldset>\n";
    }
    unless ($_ =~ "01") {
        print "</TD>";
    }
}

# Close database connection
$dbh->disconnect();

my $comsz = ($FORM{COMMENT_SIZE} > 0 ? $FORM{COMMENT_SIZE}:80);
my $comhlp = htmlspecialchars($FORM{COMMENT_HELP});
print qq(</TD>
  <tr>
    <td style="border:0" colspan="2">
      <P><B>$__{'Observations'}</B>:&nbsp;<input size=$comsz name="comment" value="$sel_comment"
      onMouseOut="nd()" onmouseover="overlib('$comhlp')"><P>
      $recinfo
    </td>
  </tr>
  <tr>
    <td style="border:0" colspan="$max_columns">
      <HR>
      <P style="margin-top: 20px; text-align: center">
        <input type="button" name=lien value="$__{'Cancel'}"
         onClick="document.location=') . $cgi->param('return_url') . qq('" style="font-weight: normal">
        <input type="button" value="$__{'Save'}" onClick="verif_form();" style="font-weight: bold">
      </P>
    </td>
  </tr>
</table>
</form>

<br>
</body>
</html>);

# --- End of main script
# -----------------------------------------------------------------------------

# --- return information when OK and registering metadata in the metadata database
sub htmlMsgOK {
    print $cgi->header(-type=>'text/plain', -charset=>'utf-8');
    print "$_[0]\n";
}

# --- return information when not OK
sub htmlMsgNotOK {
    print $cgi->header(-type=>'text/plain', -charset=>'utf-8');
    print "Update FAILED !\n $_[0] \n";
}

# --- returm a date string from a form input of type datetime|udate
sub get_date_input {
    my $in = shift;
    my @date;
    push(@date, $cgi->param($in."_year"));
    push(@date, $cgi->param($in."_month"));
    push(@date, $cgi->param($in."_day"));
    push(@date, defined $cgi->param($in."_hr") ? $cgi->param($in."_hr") : "");
    push(@date, defined $cgi->param($in."_mn") ? $cgi->param($in."_mn") : "");
    push(@date, defined $cgi->param($in."_sec") ? $cgi->param($in."_sec") : "");
    return @date;
}

__END__

=pod

=head1 AUTHOR(S)

Lucas Dassin, François Beauducel, Jérôme Touvier

=head1 COPYRIGHT

WebObs - 2012-2025 - Institut de Physique du Globe Paris

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

=cut
