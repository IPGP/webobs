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

my $FORM = new WebObs::Form($form);

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
my $site    = $cgi->param('site');
my $comment = $cgi->param('comment') // "";

my $val     = $cgi->param('val');
my $user    = $cgi->param('user');
my $id      = $cgi->param('id') // "";
my $action   = checkParam($cgi->param('action'), qr/(new|edit|save|delete|restore|erase)/, 'action')  // "edit";
my $return_url = $cgi->param('return_url');
my @operators  = $cgi->param('operators');

my ($sdate, $sdate_min) = datetime2maxmin($year[0],$month[0],$day[0],$hr[0],$mn[0]);
my $stamp = "[$today $user]";
if (index($val,$stamp) eq -1) { $val = "$stamp $val"; };

# ---- specific FORM inits -----------------------------------
my %FORM = readCfg("$WEBOBS{PATH_FORMS}/$form/$form.conf");


my @NODESSelList;
my %Ps = $FORM->procs;
for my $p (keys(%Ps)) {
	my %N = $FORM->nodes($p);
	for my $n (keys(%N)) {
		push(@NODESSelList,"$n|$N{$n}{ALIAS}: $N{$n}{NAME}");
	}
}


my $sel_site = my $sel_comment = "";

# ----

my $col_count = $FORM{COLUMNS_NUMBER};
my $fs_count  = $FORM{FIELDSETS_NUMBER};
my @keys = sort keys %FORM;
my @names = extract_field_names(@keys);
my @units = extract_field_units(@keys);
my @columns   = map { sprintf("COLUMN%02d_LIST", $_) } (1..$col_count);
my @fieldsets = map { sprintf("FIELDSET%02d", $_) } (1..$fs_count);
my $count_inputs = count_inputs(@keys)-1;

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

if ($action eq 'save') {
	my @lignes;
	my $msg;

	my @inputs = map { sprintf("input%02d", $_) } (1..($count_inputs+1));

	# ---- filling the database with the data from the form
	my $row;
	my $db_columns;
	$db_columns = "trash, node, edate, edate_min, sdate, sdate_min, operators";
	$row = "false, \"$site\", \"$edate\", \"$edate_min\", \"$sdate\", \"$sdate_min\", \"".join(",", @operators)."\"";
        if ($id ne "") {
		$db_columns = "id, ".$db_columns;
		$row = "$id, ".$row;
		$msg = "record #$id has been updated.";
	} else {
		$msg = "new record has been created.";
	}
	for my $i (0 .. $#inputs) {
	    my $input = $cgi->param($inputs[$i]);
	    if ($input ne "") {
		$db_columns .= ", $inputs[$i]";
		$row .= ", \"$input\"";
	    }
	}
	$db_columns .= ", comment, tsupd, userupd";
	$row .= ", \"$comment\", \"$today\", \"$user\"";

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
    htmlMsgOK("Record #$id has been recoverd from trash.");

    $dbh->disconnect();
    exit;
} elsif ($action eq "erase" && $id ne "") {
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

# ---- Start HTML display
#
print qq[Content-type: text/html

<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>
<head>
<title>] . $FORM{TITLE} . qq[</title>
<link rel="stylesheet" type="text/css" href="/$WEBOBS{FILE_HTML_CSS}">
<meta http-equiv="content-type" content="text/html; charset=utf-8">
<script language="javascript" type="text/javascript" src="/js/jquery.js"></script>
<script language="javascript" type="text/javascript" src="/js/comma2point.js"></script>
<script type="text/javascript">
<!--
function update_form()
{
    var form = document.form;
}

function suppress(level)
{
    var str = "$FORM{TITLE} ?";
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
     // but wait 1s for the previous handler execution to finish
     \$('#theform').on("keydown", function() { setTimeout(update_form, 1000); });
   });
 </script>
];

# ---- read data file
#
my $message;
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
		($trash, $site, $edate, $edate_min, $sdate, $sdate_min, $opers, $sel_comment, $ts0, $user) = ($row[1], $row[2], $row[3], $row[4], $row[5], $row[6], $row[7], $row[-3], $row[-2], $row[-1]);
		($sel_y1,$sel_m1,$sel_d1,$sel_hr1,$sel_mn1) = datetime2array($sdate, $sdate_min);
		($sel_y2,$sel_m2,$sel_d2,$sel_hr2,$sel_mn2) = datetime2array($edate, $edate_min);
		@operators = split(/,/,$opers);
		for (my $i = 7; $i <= $#row-3; $i++) {
		    $prev_inputs{$colnam[$i]} = $row[$i];
		}
	}
	$message = "$__{'Edit data n°'} $id";
	$val = "[$ts0 $user]";
} else {
	$message = "$__{'Input new data'}";
	@operators = ("$client");
}

print qq(<input type="hidden" name="id" value="$id">);
print qq(<tr><td style="border: 0"><hr>);
if ($val ne "") {
	print qq(<p><b>Record timestamp:</b> $val
	<input type="hidden" name="val" value="$val"></p>);
}
if ($action eq "edit" && $id ne "") {
	if ($trash eq "1") {
		print qq(<input type="button" value="$__{'Restore'}" onClick="suppress(-1);">);
	} else {
		print qq(<input type="button" value="$__{'Remove'}" onClick="suppress(1);">);
	}
	if ($clientAuth > 2) {
		print qq(<input type="button" value="$__{'Erase'}" onClick="suppress(2);">);
	}
}
print qq(<hr></td></tr>);

print qq[<form name="form" id="theform" action="">
<input type="hidden" name="id" value="$id">
<input type="hidden" name="user" value="$client">
<input type="hidden" name="trash" value="$trash">
<input type="hidden" name="delete" value="">
<input type=\"hidden\" name=\"action\" value="save">
<input type=\"hidden\" name=\"form\" value=\"$form\">

<table width="100%">
  <tr>
    <td style="border: 0">
     <h1>$FORM{TITLE}</h1>
     <h2>$message</h2>
    </td>
  </tr>

</table>
<table style="border: 0" >
  <tr>
    <td style="border: 0" valign="top">
      <fieldset>
        <legend>$__{'Date and place of sampling'}</legend>
        <p class="parform">
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
		onMouseOut="nd()"onmouseover="overlib('Select a node for this record')">
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
    my $side;
    unless ($_ =~ "01") {
        print "<TD style=\"border:0\" valign=\"top\">";
        $side = "right";
    }
    my @list = split(/,/, $FORM{$_});
    for (my $i = 0; $i <= $#list; $i++) {
        print "<fieldset><legend>$FORM{\"$list[$i]\_NAME\"}</legend>";
        print "<table width=\"100%\">";
        my @inputs;
        my @j = (1..$FORM{"$list[$i]\_COLUMNS"});
        for (@j) {
            print qq(<td style=\"border:0\" valign=\"top\">
                        <p class=\"parform\" align=$side>);
            @inputs  = split(/,/, $FORM{"$list[$i]\_C0$_"});
            for (my $i = 0; $i <= $#inputs; $i++) {
                my $name = $FORM{"$inputs[$i]_NAME"};
                my $unit = $FORM{"$inputs[$i]_UNIT"};
                my $type = $FORM{"$inputs[$i]_TYPE"};
                my $txt = "<B>$name </B>".($unit ne "" ? " ($unit)":"")." = ";
                while ($name =~ /(<sup>|<\/sup>|<sub>|<\/sub>|\+|\-|\&|;)/) {
                    $name =~ s/(<sup>|<\/sup>|<sub>|<\/sub>|\+|\-|\&|;)//;
                }
                $inputs[$i] = lc($inputs[$i]);
                print $FORM{"$inputs[$i]_LIST"};
                print exists($FORM{"$inputs[$i]_LIST"});
                if ($type =~ /^formula:/) {
                    (my $formula, my @x) = extract_formula($type);
                    foreach (@x) {
                        my $form_input = lc($_);
                        $formula =~ s/$_/Number(form.$form_input.value)/g;
                    }
                    foreach (@x) {
                        my $form_input = lc($_);
                        print qq(
                            <script>
                                form.$form_input.onchange = function() {
                                    form.$inputs[$i].value = parseFloat($formula).toFixed(2);
                                }
                            </script>
                        );
                    }
                    print qq($txt<input size=6 readOnly class=inputNumNoEdit name="$inputs[$i]"
                        onMouseOut="nd()" onmouseover="overlib('$formula')"><BR>);
                } elsif ($type =~ "list") {
                    my %list = extract_list($type,$form);
                    my @list_keys = keys %list;
                    print qq($txt<select name="$inputs[$i]" size=1
                        onMouseOut="nd()" onmouseover="overlib('Select a value for $inputs[$i]')"><option value=""></option>);
                    for (@list_keys) {
			my $selected = ($prev_inputs{$inputs[$i]} eq "$_" ? "selected":"");
                        print "<option value=\"$_\" $selected>$_: $list{$_}</option>";
                    }
                    print qq(</select><BR>);
                } elsif ($type =~ "text"){
                    my $re = extract_re($type);
                    print qq($txt<input type=\"text\" size=5 class=inputNum name=\"$inputs[$i]\" value=\"$prev_inputs{$inputs[$i]}\"
                        onMouseOut="nd()" onchange=\"verif_re()\" onmouseover="overlib('Enter a value for $inputs[$i]')"><BR>);
                } else {
                    print qq($txt<input size=5 name=\"$inputs[$i]\" value=\"$prev_inputs{$inputs[$i]}\"
                        onMouseOut="nd()" onmouseover="overlib('Enter a value for $inputs[$i]')"><BR>);
                }
            }
            print "</p></td>";
        }
        print "</table>";
        print "</fieldset>";
    }
    unless ($_ =~ "01") {
        print "</TD>";
    }
}

my $comhlp = htmlspecialchars($FORM{COMMENT_HELPER});
print qq(</TD>
  <tr>
    <td style="border: 0" colspan="2">
      <B>$__{'Observations'}</B>:&nbsp;<input size=80 name="comment" value="$sel_comment"
      onMouseOut="nd()" onmouseover="overlib('$comhlp')"><BR>
    </td>
  </tr>
  <tr>
    <td style="border: 0" colspan="2">
      <P style="margin-top: 20px; text-align: center">
        <input type="button" name=lien value="$__{'Cancel'}"
         onClick="document.location=') . $cgi->param('return_url') . qq('" style="font-weight: normal">
        <input type="button" value="$__{'Submit'}" onClick="verif_form();" style="font-weight: bold">
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
