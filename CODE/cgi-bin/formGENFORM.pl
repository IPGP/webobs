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
my $today = strftime('%F',@tod);
my $currentYear = strftime('%Y',@tod);
my $sel_d1  = strftime('%d',@tod);
my $sel_m1  = strftime('%m',@tod);
my $sel_y1 = strftime('%Y',@tod);
my $sel_hr1 = "";
my $sel_mn1 = "";
my $sel_d2 = $sel_d1;
my $sel_m2 = $sel_m1;
my $sel_y2 = $sel_y1;
my $sel_hr2 = $sel_hr1;
my $sel_mn2 = $sel_mn1;

# ---- Get the form data
# 
my @year    = $cgi->param('year');
my @month   = $cgi->param('month');
my @day     = $cgi->param('day');
my @hr      = $cgi->param('hr');
my @mn      = $cgi->param('mn');
my $quality = $cgi->param('quality') // 0;
my $site    = $cgi->param('site');
my $comment = $cgi->param('comment') // "";

my $val     = $cgi->param('val');
my $user    = $cgi->param('user');
my $id      = $cgi->param('id') // "";
my $action   = checkParam($cgi->param('action'), qr/(new|edit|save|delete|restore|erase)/, 'action')  // "edit";
my $return_url = $cgi->param('return_url');
my @operators  = $cgi->param('operators');
my $debug  = $cgi->param('debug');

my ($sdate, $sdate_min) = datetime2maxmin($year[0],$month[0],$day[0],$hr[0],$mn[0]);
my $stamp = "[$today $user]";
if (index($val,$stamp) eq -1) { $val = "$stamp $val"; };

# ---- specific FORM inits -----------------------------------

my @NODESSelList;
for (@{$FORM{NODESLIST}}) {
    my $id = $_;
    my %N = readNode($id);
    push(@NODESSelList,"$id|$N{$id}{ALIAS}: $N{$id}{NAME}");
}

my $sel_site = my $sel_comment = "";

# ----

my $max_columns = count_columns(keys %FORM);
my @columns   = map { sprintf("COLUMN%02d_LIST", $_) } (1..$max_columns);
my $max_inputs = count_inputs(keys %FORM);
my @validity = split(/[, ]/, ($FORM{VALIDITY_COLORS} ? $FORM{VALIDITY_COLORS}:"#66FF66,#FFD800,#FFAAAA"));

# ---- Variables des menus
my $starting_date   = isok($FORM{STARTING_DATE});
my @yearList = ($FORM{BANG}..$currentYear);
my @monthList = ("","01".."12");
my @dayList   = ("","01".."31");
my @hourList  = ("","00".."23");
my @minuteList= ("","00".."59");

# ---- if STARTING_DATE eq "yes"
my $edate = $sdate;
my $edate_min = $sdate_min;
if ($starting_date) {
    ($edate, $edate_min) = datetime2maxmin($year[1],$month[1],$day[1],$hr[1],$mn[1]);
}

# ---- action is 'save'
#
# ---- registering data in WEBOBSFORMS.db
# --- connecting to the database
my $dbh = connectDbForms();
my $tbl = lc($form);

# Number of columns in the table without the primary key
my $ncol = 11;

if ($action eq 'save') {
    my $msg;

    # ---- filling the database with the data from the form
    my $row;
    my $db_columns;
    $db_columns = "trash, quality, node, edate, edate_min, sdate, sdate_min, operators";
    $row = "false, \"$quality\", \"$site\", \"$edate\", \"$edate_min\", \"$sdate\", \"$sdate_min\", \"".join(",", @operators)."\"";
    if ($id ne "") {
        $db_columns = "id, ".$db_columns;
        $row = "$id, ".$row;
        $msg = "record #$id has been updated.";
    } else {
        $msg = "new record has been created.";
    }
    $db_columns .= ", comment, tsupd, userupd";
    $row .= ", \"$comment\", \"$today\", \"$user\"";
    foreach (map { sprintf("input%02d", $_) } (1..$max_inputs)) {
        my $input = $cgi->param($_);
        if ($input ne "") {
            $db_columns .= ", $_";
            $row .= ", \"$input\"";
        }
    }

    my $stmt = qq(REPLACE INTO $tbl($db_columns) values($row));
    my $sth  = $dbh->prepare( $stmt );
    my $rv   = $sth->execute() or die $DBI::errstr;
    if ($rv < 1){
        $msg = "ERROR: formGENFORM couldn't access the database $form.";
    }
    htmlMsgOK($msg);

    $dbh->disconnect();
    exit;
} elsif ($action eq "delete" && $id ne "") {
    my $stmt = qq(UPDATE $tbl SET trash = true WHERE id = $id);
    my $sth  = $dbh->prepare( $stmt );
    my $rv   = $sth->execute() or die $DBI::errstr;
    htmlMsgOK("Record #$id has been moved to trash.");

    $dbh->disconnect();
    exit;
} elsif ($action eq "restore" && $id ne "") {
    my $stmt = qq(UPDATE $tbl SET trash = false WHERE id = $id);
    my $sth  = $dbh->prepare( $stmt );
    my $rv   = $sth->execute() or die $DBI::errstr;
    htmlMsgOK("Record #$id has been recovered from trash.");

    $dbh->disconnect();
    exit;
} elsif ($action eq "erase" && $id ne "") {
    if ( $form ne "" ) {
        my $erase_dir = "$WEBOBS{ROOT_DATA}".uc("/formdocs/FORM_".$form."_data".$id )."*";
        qx(rm -rf $erase_dir);
    }
    my $stmt = qq(DELETE FROM $tbl WHERE id = $id);
    my $sth  = $dbh->prepare( $stmt );
    my $rv   = $sth->execute() or die $DBI::errstr;
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
<meta http-equiv="content-type" content="text/html; charset=utf-8">
<script language="javascript" type="text/javascript" src="/js/jquery.js"></script>
<script language="javascript" type="text/javascript" src="/js/comma2point.js"></script>
<script language="javascript" type="text/javascript" src="/js/math.js"></script>
<script type="text/javascript">
<!--
function update_form()
{
    var form = document.form;
];
foreach my $f (@formulas) {
    my ($formula, $size, @x) = extract_formula($FORM{$f."_TYPE"});

# any word followed by an open parenthesis is supposed to be a math function (see math.js)...
    $formula =~ s/\b(pi)\b/Math.PI/ig;
    $formula =~ s/(\w+\()/math.$1/g;
    foreach (@x) {
        my $form_input = lc($_);
        $formula =~ s/$_/Number(form.$form_input.value)/g;
    }
    print "form.".lc($f).".value = parseFloat($formula).toFixed(2);\n";
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
        cbox.value="checked";
        } else { cbox.value="unchecked"; }
    });
    console.log(\$("#theform"));
    if(document.form.site.value == "") {
        alert("$__{'You must select a node associated to this record!'}");
        document.form.site.focus();
        return false;
    }
    console.log(\$("#theform").serialize());
    submit();
}

function submit()
{
    \$.post("]. $form_url . qq[", \$("#theform").serialize(), function(data) {
            alert(data);
            // Redirect the user to the form display page while keeping the previous filter
            document.location="] . $cgi->param('return_url') . qq[";
        }
    );
}
//-->
</script>
</head>

<body style="background-color:#E0E0E0">
 <div id="overDiv" style="position:absolute; visibility:hidden; z-index:1000;"></div>
 <!-- overLIB (c) Erik Bosrup -->
 <script language="javascript" src="/js/overlib/overlib.js"></script>
 <div id="helpBox"></div>
 <script type="text/javascript">
   // Prevent the Return key from submitting the form
   function stopRKey(evt) {
     var evt = (evt) ? evt : ((event) ? event : null);
     var node = (evt.target) ? evt.target : ((evt.srcElement) ? evt.srcElement : null);
     if ((evt.keyCode == 13) && (node.type=="text"))  {return false;}
   }
   document.onkeypress = stopRKey;

   // Once the document is loaded
   \$(document).ready(function(){
     // Update the form immediately
     update_form();
     // Also update the form when any of its element is changed
     \$('#theform').on("change", update_form);
     // Also update when a key is pressed in the form
     // but wait 0.5s for the previous handler execution to finish
     \$('#theform').on("keydown", function() { setTimeout(update_form, 500); });
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

if ($action eq "edit") {

    # --- connecting to the database
    my $dbh = connectDbForms();
    my $tbl = lc($form);

    my $stmt = qq(SELECT * FROM $tbl WHERE id = $id); # selecting the row corresponding to the id of the record we want to modify
    my $sth = $dbh->prepare( $stmt );
    my @colnam = @{ $sth->{NAME_lc} };
    my $rv = $sth->execute() or die $DBI::errstr;

    my ($edate, $edate_min, $sdate, $sdate_min, $opers, $ts0, $user);
    while(my @row = $sth->fetchrow_array()) {
        ($trash, $quality, $site, $edate, $edate_min, $sdate, $sdate_min, $opers, $sel_comment, $ts0, $user) = @row[1..$ncol];
        ($sel_y1,$sel_m1,$sel_d1,$sel_hr1,$sel_mn1) = datetime2array($sdate, $sdate_min);
        ($sel_y2,$sel_m2,$sel_d2,$sel_hr2,$sel_mn2) = datetime2array($edate, $edate_min);
        @operators = split(/,/,$opers);
        push(@operators,$user) if (@operators =~ /^$user$/);
        for (my $i = $ncol+1; $i <= $#row; $i++) {
            $prev_inputs{$colnam[$i]} = $row[$i];
        }
    }
    $title2 = "$__{'Edit record n°'} $id";
    $title2 = "<SPAN class=\"inTrash\">$title2</SPAN>" if ($trash);
    $val = "$ts0 [$user]";
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
    print "<P><input type=\"checkbox\"".($quality ? " checked":"")
      ." name=\"quality\" value=\"1\" onMouseOut=\"nd()\" onmouseover=\"overlib('$__{'help_genform_quality'}')\">"
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
        <legend>$__{'Date, site, and operators'}</legend>
        <p class="parform" align=\"right\">
];

if ($starting_date) {
    print qq(
                <b>$__{'Start Date'}: </b>
                    <select name="year" size="1">
        );
    for (@yearList) {if ($_ == $sel_y1) {print qq(<option selected value="$_">$_</option>);} else {print qq(<option value="$_">$_</option>);}}
    print qq(</select>);
    print qq(<select name="month" size="1">);
    for (@monthList) {if ($_ == $sel_m1) {print qq(<option selected value="$_">$_</option>);} else {print qq(<option value="$_">$_</option>);}}
    print qq(</select>);
    print qq( <select name=day size="1">);
    for (@dayList) {if ($_ == $sel_d1) {print qq(<option selected value="$_">$_</option>);} else {print qq(<option value="$_">$_</option>);}}
    print "</select>";

    print qq(&nbsp;&nbsp;<b>$__{'Time'}: </b><select name=hr size="1">);
    for (@hourList) {if ($_ eq $sel_hr1) {print qq(<option selected value="$_">$_</option>);} else {print qq(<option value="$_">$_</option>);}}

    print qq(</select>);
    print qq(<select name=mn size="1">);
    for (@minuteList) {if ($_ eq $sel_mn1) {print qq(<option selected value="$_">$_</option>);} else {print qq(<option value="$_">$_</option>);}}
    print qq(</select><BR>);

    print qq(
                <b>$__{'End Date'}: </b>
                    <select name="year" size="1">
        );
    for (@yearList) {if ($_ == $sel_y2) {print qq(<option selected value="$_">$_</option>);} else {print qq(<option value="$_">$_</option>);}}
    print qq(</select>);
    print qq(<select name="month" size="1">);
    for (@monthList) {if ($_ == $sel_m2) {print qq(<option selected value="$_">$_</option>);} else {print qq(<option value="$_">$_</option>);}}
    print qq(</select>);
    print qq( <select name=day size="1">);
    for (@dayList) {if ($_ == $sel_d2) {print qq(<option selected value="$_">$_</option>);} else {print qq(<option value="$_">$_</option>);}}
    print "</select>";

    print qq(&nbsp;&nbsp;<b>$__{'Time'}: </b><select name=hr size="1">);
    for (@hourList) {if ($_ eq $sel_hr2) {print qq(<option selected value="$_">$_</option>);} else {print qq(<option value="$_">$_</option>);}}
    print qq(</select>);
    print qq(<select name=mn size="1">);
    for (@minuteList) {if ($_ eq $sel_mn2) {print qq(<option selected value="$_">$_</option>);} else {print qq(<option value="$_">$_</option>);}}

} else {
    print qq(
            <b>$__{'Date'}: </b>
                <select name="year" size="1">
        );
    for (@yearList) {
        my $sel = ($_ eq $sel_y2 ? "selected":"");
        print qq(<option $sel value="$_">$_</option>);
    }
    print qq(</select>);
    print qq(<select name="month" size="1">);
    for (@monthList) {
        my $sel = ($_ eq $sel_m2 ? "selected":"");
        print qq(<option $sel value="$_">$_</option>);
    }
    print qq(</select>);
    print qq( <select name=day size="1">);
    for (@dayList) {
        my $sel = ($_ eq $sel_d2 ? "selected":"");
        print qq(<option $sel value="$_">$_</option>);
    }
    print "</select>";

    print qq(&nbsp;&nbsp;<b>$__{'Time'}: </b><select name=hr size="1">);
    for (@hourList) {
        my $sel = ($_ eq $sel_hr2 ? "selected":"");
        print qq(<option $sel value="$_">$_</option>);
    }
    print qq(</select>);
    print qq(<select name=mn size="1">);
    for (@minuteList) {
        my $sel = ($_ eq $sel_mn2 ? "selected":"");
        print qq(<option $sel value="$_">$_</option>);
    }
}
print qq(</select><BR>
    <B>Site: </B>
      <select name="site" size="1"
        onMouseOut="nd()"onmouseover="overlib('$__{'Select a node for this record'}')">
      <option value=""></option>);
print @NODESSelList;
for (@NODESSelList) {
    my @cle = split(/\|/,$_);
    my $sel = ($cle[0] eq $site ? "selected":($action eq "edit" ? "disabled":""));
    print qq(<option $sel value="$cle[0]">$cle[1]</option>);
}

print qq(</select><BR>
    <table><tr><td style="border:0"><B>$__{'Operator(s)'}:</B> </td><td style="border:0">
            <select name="operators" size="5" multiple="multiple"
                onMouseOut="nd()" onmouseover="overlib('$__{'Select operator(s)'}')">);
my @uid = @operators; # $client if 'new', or @operators if 'edit'
foreach my $op (split(/,/, $FORM{OPERATORS_LIST})) {
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
            print qq(<td style=\"border:0\" valign=\"top\"><p class=\"parform\" align=\"right\">);
            my $fsc = sprintf("$fieldset\_C%02d", $fs);
            foreach my $Field (split(/[, ]/, $FORM{$fsc})) {
                my $name = $FORM{"$Field\_NAME"};
                my $unit = $FORM{"$Field\_UNIT"};
                my $type = $FORM{"$Field\_TYPE"};
                my $help = htmlspecialchars($FORM{"$Field\_HELP"});
                my $field = lc($Field);
                my ($size, $default) = extract_type($type);
                if ($action ne 'edit' && $default ne "") {
                    $prev_inputs{$field} = $default;
                }
                my $txt = "<B>$name</B>".($unit ne "" ? " ($unit)":"");
                my $hlp;
                if ($field =~ /^input/ && $type =~ /^list:/) {
                    my %list = extract_list($type,$form);
                    my @list_keys = sort keys %list;
                    $hlp = ($help ne "" ? $help:"$__{'Select a value for'} $Field");

# if list contains an icon column (HoH), displays radio button instead of select list
                    if (ref($list{$list_keys[0]})) {
                        print "$txt =";
                        for (@list_keys) {
                            my $selected = ($prev_inputs{$field} eq "$_" ? "checked":"");
                            print qq(&nbsp;<input name="$field" type=radio value="$_" $selected
                            onMouseOut="nd()" onmouseover="overlib('$list{$_}{name}')"><IMG src="$list{$_}{icon}">);
                        }
                        print "$dlm";
                    } else {
                        print qq($txt = <select name="$field" size=1
                            onMouseOut="nd()" onmouseover="overlib('$hlp')"><option value=""></option>);
                        for (@list_keys) {
                            my $nam = (ref($list{$_}) ? $list{$_}{name}:$list{$_});
                            my $selected = ($prev_inputs{$field} eq "$_" ? "selected":"");
                            print qq(<option value="$_" $selected>$_: $nam</option>);
                        }
                        print "</select>$dlm";
                    }
                } elsif ($field =~ /^input/ && $type =~ /^text/) {
                    $hlp = ($help ne "" ? $help:"$__{'Enter a value for'} $Field");
                    print qq($txt = <input type="text" size=$size name="$field" value="$prev_inputs{$field}"
                        onMouseOut="nd()" onmouseover="overlib('$hlp')">$dlm);
                } elsif ($field =~ /^input/ && $type =~ /^checkbox/) {
                    $hlp = ($help ne "" ? $help:"$__{'Click to select'} $Field");
                    my $selected = ($prev_inputs{$field} eq "checked" ? "checked" : "");
                    print qq($txt <input type="checkbox" name="$field" $selected onMouseOut="nd()" onmouseover="overlib('$hlp')">$dlm);
                } elsif ($field =~ /^input/ && $type =~ /^image/) {
                    my $img_id = uc($form."/record".$id."/".$Field);
                    if ($action eq "edit") {
                        my @dim = split(/,/, $size);
                        my $width = ($dim[0] >= $GRIDS{THUMB_MIN_WIDTH} && $dim[0] <= $GRIDS{THUMB_MAX_WIDTH} ? $dim[0] : $GRIDS{THUMB_DEFAULT_WIDTH});
                        my $height = ($dim[1] >= $GRIDS{THUMB_MIN_HEIGHT} && $dim[1] <= $GRIDS{THUMB_MAX_HEIGHT} ? $dim[1] : $GRIDS{THUMB_DEFAULT_HEIGHT});
                        $default = ($default >= $GRIDS{THUMB_MIN_DELAY} && $default <= $GRIDS{THUMB_MAX_DELAY} ? $default : $GRIDS{THUMB_DEFAULT_DELAY});
                        my $path = "/formdocs/$img_id";
                        print qq(<button onclick="location.href='formUPLOAD.pl?object=$img_id&doc=SPATH_GENFORM_IMAGES&width=$width&height=$height&delay=$default'"
                            type="button"> Upload images or files</button><br><br>);
                        if ( -e "$WEBOBS{ROOT_DATA}".uc($path)."/THUMBNAILS/$GRIDS{THUMBNAILS_ANIM}") {
                            print qq(<img width=$width height=$height src="$path/THUMBNAILS/$GRIDS{THUMBNAILS_ANIM}"></img>);
                        }
                        my $imgdir = "$WEBOBS{ROOT_DATA}".uc($path);
                        my $nb = qx(ls $imgdir -p | grep -v / | wc -l);
                        print qq(<input type="hidden" name="$field" value=$nb>\n);
                    } else {
                        print qq(Image upload is available once the form has been submitted.);
                    }
                } elsif ($field =~ /^input/) {
                    $hlp = ($help ne "" ? $help:"$__{'Enter a numerical value for'} $Field");
                    print qq($txt = <input type="text" pattern="[0-9\\.\\-]*" size=$size class=inputNum name="$field" value="$prev_inputs{$field}"
                        onMouseOut="nd()" onmouseover="overlib('$hlp')">$dlm);
                } elsif ($field =~ /^output/ && $type =~ /^formula/) {
                    my ($formula, $size, @x) = extract_formula($type);
                    if ($size > 0) {
                        $hlp = ($help ne "" ? $help:"$Field = $formula");
                        print qq(<B>$name</B> = <input size=$size readOnly class=inputNumNoEdit name="$field"
                        onMouseOut="nd()" onmouseover="overlib('$hlp')">&nbsp;$unit$dlm);
                    } else {
                        print qq(<input type="hidden" name="$field">);
                    }
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
    my $msg = $_[0];
    print "$msg\n";
}

# --- return information when not OK
sub htmlMsgNotOK {
    print $cgi->header(-type=>'text/plain', -charset=>'utf-8');
    print "Update FAILED !\n $_[0] \n";
}

# Open an SQLite connection to the forms database
sub connectDbForms {
    return DBI->connect("dbi:SQLite:$WEBOBS{SQL_FORMS}", "", "", {
            'AutoCommit' => 1,
            'PrintError' => 1,
            'RaiseError' => 1,
        }) || die "Error connecting to $WEBOBS{SQL_FORMS}: $DBI::errstr";
}

__END__

=pod

=head1 AUTHOR(S)

Lucas Dassin, François Beauducel

=head1 COPYRIGHT

WebObs - 2012-2024 - Institut de Physique du Globe Paris

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
