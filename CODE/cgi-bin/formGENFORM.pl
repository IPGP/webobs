#!/usr/bin/perl

=head1 NAME

formGENFORM.pl

=head1 SYNOPSIS

http://..../formGENFORM.pl?form=FORMName[&id=id&return_url=url&action={edit|save}]

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

action can be selected between [new|edit|save].

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
use WebObs::Users qw($CLIENT %USERS clientHasRead clientHasEdit clientHasAdm);
use WebObs::Grids;
use WebObs::Utils;
use WebObs::i18n;
use Locale::TextDomain('webobs');
use WebObs::Form;

# ---- standard FORMS inits ----------------------------------

my $FORMName = $cgi->param('form');      # name of the form

#die "You can't edit GENFORM reports." if (!clientHasEdit(type=>"authforms",name=>"GENFORM"));

my $FORM = new WebObs::Form($FORMName);

my $form_url = URI->new("/cgi-bin/formGENFORM.pl");

my %Ns;
my @NODESSelList;
my %Ps = $FORM->procs;
for my $p (keys(%Ps)) {
	my %N = $FORM->nodes($p);
	for my $n (keys(%N)) {
		push(@NODESSelList,"$n|$N{$n}{ALIAS}: $N{$n}{NAME}");
	}
	%Ns = (%Ns, %N);
}

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
my @annee  = $cgi->param('annee');
my @mois   = $cgi->param('mois');
my @jour   = $cgi->param('jour');
my @hr     = $cgi->param('hr');
my @mn     = $cgi->param('mn');
my $site   = $cgi->param('site');
my $rem    = $cgi->param('rem') // "";

my $val    = $cgi->param('val');
my $oper   = $cgi->param('oper');
my $idTraite = $cgi->param('id') // "";
my $action   = checkParam($cgi->param('action'), qr/(new|edit|save)/, 'action')  // "edit";
my $return_url = $cgi->param('return_url');
my $delete = $cgi->param('delete');
my @users  = $cgi->param('users');

my ($sdate, $sdate_min) = datetime2maxmin($annee[0],$mois[0],$jour[0],$hr[0],$mn[0]);
my $stamp = "[$today $oper]";
if (index($val,$stamp) eq -1) { $val = "$stamp $val"; };

# ---- specific FORM inits -----------------------------------
my %FORM = readCfg("$WEBOBS{PATH_FORMS}/$FORMName/$FORMName.conf");

$ENV{LANG} = $WEBOBS{LOCALE};

my $sel_site = my $sel_rem = "";

# ----

my $col_count = $FORM{COLUMNS_NUMBER};
my $fs_count  = $FORM{FIELDSETS_NUMBER};
my @keys = sort keys %FORM;
my @names = extract_field_names(@keys);
my @units = extract_field_units(@keys);
my @columns   = map {$_."_LIST"} extract_columns($col_count);
my @fieldsets = extract_fieldsets($fs_count);
my $count_inputs = count_inputs(@keys)-1;

# ---- Variables des menus
my $starting_date   = isok($FORM->conf('STARTING_DATE'));
my @yearList = ($FORM->conf('BANG')..$currentYear);
my @monthList = ("","01".."12");
my @dayList   = ("","01".."31");
my @hourList  = ("","00".."23");
my @minuteList= ("","00".."59");

# ---- if STARTING_DATE eq "yes"
my $edate = $sdate;
my $edate_min = $sdate_min;
if ($starting_date) {
    ($edate, $edate_min) = datetime2maxmin($annee[1],$mois[1],$jour[1],$hr[1],$mn[1]);
}

# ---- action is 'save'
#
# ---- registering data in WEBOBSFORMS.db
# --- connecting to the database
my $dbh = connectDbForms();
my $tbl = lc($FORMName);

if ($action eq 'save' && $delete < 1) {
	my @lignes;
	my $msg = "";
	my $newID;

	my @inputs = map { sprintf("input%02d", $_) } (1..($count_inputs+1));

	# ---- filling the database with the data from the form
	my $row;
	my $db_columns;
	$db_columns = "trash, node, edate, edate_min, sdate, sdate_min, users";
	$row = "false, \"$site\", \"$edate\", \"$edate_min\", \"$sdate\", \"$sdate_min\", \"".join(/,/, @users)."\"";
	for my $i (0 .. $#inputs) {
	    my $input = $cgi->param($inputs[$i]);
	    if ($input ne "") {
		$db_columns .= ", $inputs[$i]";
		$row .= ", \"$input\"";
	    }
	}
	$db_columns .= ", comment, tsupd, userupd";
	$row .= ", \"$rem\", \"$today\", \"$oper\"";

	my $stmt = qq(replace into $tbl($db_columns) values($row));
	my $sth  = $dbh->prepare( $stmt );
	my $rv   = $sth->execute() or die $DBI::errstr;
	my $msg;
	if ($rv >= 1){
		$msg = "new record #$newID has been created.";
	} else {
		$msg = "formGENFORM couldn't access the database.";
	}
	htmlMsgOK($msg);

	$dbh->disconnect();
	exit;
} elsif ($action eq "save" && $delete > 0) {
    my $tbl = lc($FORMName);
    my $stmt = qq(update $tbl set trash = true where id=$idTraite);
    my $sth  = $dbh->prepare( $stmt );
	my $rv   = $sth->execute() or die $DBI::errstr;
    htmlMsgOK("Delete/recover existing record #$idTraite (in/from trash).");

    $dbh->disconnect();
    exit;
}

# ---- action is 'edit' (default) or new
#
#$editOK = WebObs::Users::clientHasEdit(type => "auth".$auth, name => "$FORMName") || WebObs::Users::clientHasEdit(type => "auth".$auth, name => "MC");
#$admOK = WebObs::Users::clientHasAdm(type => "auth".$auth, name => "*");

$form_url->query_form('form' => $FORMName, 'id' => $idTraite, 'return_url' => $return_url, 'action' => 'save');

# ---- Start HTML display
#
print qq[Content-type: text/html

<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>
<head>
<title>] . $FORM->conf('TITLE') . qq[</title>
<link rel="stylesheet" type="text/css" href="/$WEBOBS{FILE_HTML_CSS}">
<meta http-equiv="content-type" content="text/html; charset=utf-8">
<script language="javascript" type="text/javascript" src="/js/jquery.js"></script>
<script language="javascript" type="text/javascript" src="/js/comma2point.js"></script>
<script type="text/javascript">
<!--
function update_form()
{
    var formulaire = document.formulaire;
}

function suppress(level)
{
    var str = "]  . u2l($FORM->conf('TITLE')) . qq[ ?";
    if (level > 1) {
        if (!confirm("$__{'ATT: Do you want PERMANENTLY erase this record from '}" + str)) {
            return false;
        }
    } else {
        if (document.formulaire.id.value > 0) {
            if (!confirm("$__{'Do you want to remove this record from '}" + str)) {
                return false;
            }
        } else {
            if (!confirm("$__{'Do you want to restore this record in '}" + str)) {
                return false;
            }
        }
    }
    document.formulaire.delete.value = level;
    submit();
}

function verif_re(element)
{
    
}

function verif_formulaire()
{
    console.log(\$("#theform"));
    if(document.formulaire.site.value == "") {
        alert("Veuillez spécifier le site de prélèvement!");
        document.formulaire.site.focus();
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
my $message = "$__{'Input new data'}";
my $id = $idTraite;
my $val = "";
my %prev_inputs;

if ($action eq "edit") {
    # --- connecting to the database
	my $dbh = connectDbForms();
	my $tbl = lc($FORMName);

	my $stmt = qq(SELECT * FROM $tbl WHERE id = $id;); # selecting the row corresponding to the id of the record we want to modify
	my $sth = $dbh->prepare( $stmt );
	my @colnam = @{ $sth->{NAME_lc} };
	my $rv = $sth->execute() or die $DBI::errstr;

	my ($id, $delete, $site, $edate, $edate_min, $sdate, $sdate_min, $users, $ts0, $oper);
	while(my @row = $sth->fetchrow_array()) {
		($id, $delete, $site, $edate, $edate_min, $sdate, $sdate_min, $users, $sel_rem, $ts0, $oper) = ($row[0], $row[1], $row[2], $row[3], $row[4], $row[5], $row[6], $row[7], $row[-3], $row[-2], $row[-1]);
		($sel_y1,$sel_m1,$sel_d1,$sel_hr1,$sel_mn1) = datetime2array($edate, $edate_min);
		($sel_y2,$sel_m2,$sel_d2,$sel_hr2,$sel_mn2) = datetime2array($sdate, $sdate_min);
		for (my $i = 7; $i <= $#row-3; $i++) {
		    $prev_inputs{$colnam[$i]} = $row[$i];
		}
	}
    $message = "$__{'Edit data n°'} $id";
    $val = "[$ts0 $oper]";
} else { $val = "" ;}

if ($action eq "edit") {
	print qq(<input type="hidden" name="id" value="$QryParm->{id}">);
	print qq(<tr><td style="border: 0"><hr>);
	if ($val ne "") {
		print qq(<p><b>Information de saisie:</b> $val
		<input type="hidden" name="val" value="$val"></p>);
	}
	print qq(<input type="button" value=") . ($id < 0 ? "Reset":"$__{'Remove'}") . qq(" onClick="suppress(1);">);
	#if (clientHasAdm(type=>"authforms",name=>"EAUX")) {
		print qq(<input type="button" value="$__{'Erase'}" onClick="suppress(2);">);
	#}
	print qq(<hr></td></tr>);
}

print qq(<form name="formulaire" id="theform" action="">
<input type="hidden" name="oper" value="$USERS{$CLIENT}{UID}">
<input type="hidden" name="delete" value="">
<input type=\"hidden\" name=\"action\" value="save">
<input type=\"hidden\" name=\"form\" value=\"$FORMName\">

<table width="100%">
  <tr>
    <td style="border: 0">
     <h1>) . $FORM->conf('TITLE') . qq(</h1>\
     <h2>$message</h2>
    </td>
  </tr>
);

print qq(</table>
<table style="border: 0" >
  <tr>
    <td style="border: 0" valign="top">
      <fieldset>
        <legend>$__{'Date and place of sampling'}</legend>
        <p class="parform">
);
    if ($starting_date) {
        print qq(
                <b>$__{'Start Date'}: </b>
                    <select name="annee" size="1">
        );
    	for (@yearList) {if ($_ == $sel_y1) {print qq(<option selected value="$_">$_</option>);} else {print qq(<option value="$_">$_</option>);}}
	    print qq(</select>);
	    print qq(<select name="mois" size="1">);
	    for (@monthList) {if ($_ == $sel_m1) {print qq(<option selected value="$_">$_</option>);} else {print qq(<option value="$_">$_</option>);}}
	    print qq(</select>);
	    print qq( <select name=jour size="1">);
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
                    <select name="annee" size="1">
        );
    	for (@yearList) {if ($_ == $sel_y2) {print qq(<option selected value="$_">$_</option>);} else {print qq(<option value="$_">$_</option>);}}
	    print qq(</select>);
	    print qq(<select name="mois" size="1">);
	    for (@monthList) {if ($_ == $sel_m2) {print qq(<option selected value="$_">$_</option>);} else {print qq(<option value="$_">$_</option>);}}
	    print qq(</select>);
	    print qq( <select name=jour size="1">);
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
                <select name="annee" size="1">
        );
        for (@yearList) {
		    if ($_ == $sel_y2) {
			    print qq(<option selected value="$_">$_</option>);
		    } else {
			    print qq(<option value="$_">$_</option>);
		    }
	    }
	    print qq(</select>);
	    print qq(<select name="mois" size="1">);
	    for (@monthList) {
		    if ($_ == $sel_m2) {
			    print qq(<option selected value="$_">$_</option>);
		    } else {
			    print qq(<option value="$_">$_</option>);
		    }
	    }
	    print qq(</select>);
	    print qq( <select name=jour size="1">);
	    for (@dayList) {
		    if ($_ == $sel_d2) {
			    print qq(<option selected value="$_">$_</option>);
		    } else {
			    print qq(<option value="$_">$_</option>);
		    }
	    }
	    print "</select>";

	    print qq(&nbsp;&nbsp;<b>$__{'Time'}: </b><select name=hr size="1">);
	    for (@hourList) {
		    if ($_ eq $sel_hr2) {
			    print qq(<option selected value="$_">$_</option>);
		    } else {
			    print qq(<option value="$_">$_</option>);
		    }
	    }
	    print qq(</select>);
	    print qq(<select name=mn size="1">);
	    for (@minuteList) {
		    if ($_ eq $sel_mn2) {
			    print qq(<option selected value="$_">$_</option>);
		    } else {
		       print qq(<option value="$_">$_</option>);
		    }
	    }
    }
	print qq(</select><BR>
	<B>Site: </B>
	  <select name="site" size="1"
		onMouseOut="nd()"onmouseover="overlib('S&eacute;lectionner le site du prélèvement')">
	  <option value=""></option>);
    print @NODESSelList;
	for (@NODESSelList) {
		my @cle = split(/\|/,$_);
		if ($cle[0] eq $site) {
			print qq(<option selected value="$cle[0]">$cle[1]</option>);
		} else {
			print qq(<option value="$cle[0]">$cle[1]</option>);
		}
	}

print qq(</select><BR>
        <B>$__{'Users'}: </B>
            <select name="users" size="1"
                onMouseOut="nd()" onmouseover="overlib('$__{'Select users'}')">);
        my @users = split(/,/, $FORM->conf('LIST_USERS'));
        foreach(@users){
            print "<option value=\"$_\" >$_</option>";
        }
print qq(</select>
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
        print "<table>";
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
                my $txt;
                if ($unit ne "") {$txt = "<B>$name </B> ($unit) = "} else {$txt = "<B>$name </B> = "};
                while ($name =~ /(<sup>|<\/sup>|<sub>|<\/sub>|\+|\-|\&|;)/) {
                    $name =~ s/(<sup>|<\/sup>|<sub>|<\/sub>|\+|\-|\&|;)//;
                }
                $inputs[$i] = lc($inputs[$i]);
                print $FORM{"$inputs[$i]_LIST"};
                print exists($FORM{"$inputs[$i]_LIST"});
                if ($type =~ "formula:") {
                    (my $formula, my @x) = extract_formula($type);
                    foreach (@x) {
                        my $form_input = lc($_);
                        $formula =~ s/$_/Number(formulaire.$form_input.value)/g;
                    }
                    foreach (@x) {
                        my $form_input = lc($_);
                        print qq(
                            <script>
                                formulaire.$form_input.onchange = function() {
                                    formulaire.$form_input.value = formulaire.$form_input.value;
                                    formulaire.$inputs[$i].value = parseFloat($formula).toFixed(2);
                                }
                            </script>
                        );
                    }
                    print qq($txt<input size=6 readOnly class=inputNumNoEdit name="$inputs[$i]"
                        onMouseOut="nd()" onmouseover="overlib('$formula')"><BR>
                        <script>
                            formulaire.$_.value = parseFloat($formula).toFixed(2);
                        </script>);
                } elsif ($type =~ "list") {
                    my $list = extract_list($type);
                    my %list = readCfg($list);
                    my $list_size = keys %list;
                    print qq($txt<select name="$inputs[$i]" size=1
                        onMouseOut="nd()" onmouseover="overlib('Select one value')"><option value=""></option>);
                    for (my $j = 1; $j <= $list_size; $j++) {
                        print "<option value=\"".u2l($list{"opt$j"})."\">".u2l($list{"opt$j"})."</option>";
                    }
                    print qq(</select><BR>);
                } elsif ($type =~ "text"){
                    my $re = extract_re($type);
                    print qq($txt<input type=\"text\" size=5 class=inputNum name=\"$inputs[$i]\" value=\"$prev_inputs{$inputs[$i]}\"
                        onMouseOut="nd()" onchange=\"verif_re()\" onmouseover="overlib('Entrer la valeur de $name')"><BR>);
                } else {
                    print qq($txt<input size=5 name=\"$inputs[$i]\" value=\"$prev_inputs{$inputs[$i]}\"
                        onMouseOut="nd()" onmouseover="overlib('Entrer la valeur de $name')"><BR>);
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

print qq(</TD>
  <tr>
    <td style="border: 0" colspan="2">
      <B>Observations</B> :<BR>
      <input size=80 name=rem value="$sel_rem"
      onMouseOut="nd()" onmouseover="overlib('Noter toute présence d&rsquo;odeur, gaz, précipité, etc...')"><BR>
    </td>
  </tr>
  <tr>
    <td style="border: 0" colspan="2">
      <P style="margin-top: 20px; text-align: center">
        <input type="button" name=lien value="$__{'Cancel'}"
         onClick="document.location=') . $cgi->param('return_url') . qq('" style="font-weight: normal">
        <input type="button" value="$__{'Submit'}" onClick="verif_formulaire();">
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

sub datetime2array {
	my $date = shift;
	my $date_min = shift;
	my @d  = split(/[-: ]/,$date);
	my @dm = split(/[-: ]/,$date_min);
	if ($date eq $date_min) { return @d };
	@d = ($d[0],   "",   "",   "","") if ($d[1] ne $dm[1]);
	@d = ($d[0],$d[1],   "",   "","") if ($d[2] ne $dm[2]);
	@d = ($d[0],$d[1],$d[2],   "","") if ($d[3] ne $dm[3]);
	@d = ($d[0],$d[1],$d[2],$d[3],"") if ($d[4] ne $dm[4]);
	return @d;
}

sub datetime2maxmin {
	my ($y,$m,$d,$hr,$mn) = @_;
	my $date_min = "$y-$m-$d $hr:$mn";
	my $date_max = "$y-$m-$d $hr:$mn";
	if ($m eq "") {
		$date_min = "$y-01-01";
		$date_max = "$y-12-31";
	} elsif ($d eq "") {
		$date_min = qx(date -d "$y-$m-01" +%F);
		$date_max = qx(date -d "$y-$m-01 1 month 1 day ago" +%F);
	} elsif ($hr eq "") {
		$date_min = "$y-$m-$d 00:00";
		$date_max = "$y-$m-$d 23:59";
	} elsif ($mn eq "") {  
		$date_min = "$y-$m-$d $hr:00";
		$date_max = "$y-$m-$d $hr:59";
	}
	return ("$date_max","$date_min");
}

sub extract_field_names {
	my @names;
	foreach (@_) {
		if ($_ =~ "_NAME") {push(@names,$_);}
	}
	return @names;
}

sub extract_field_units {
	my @units;
	foreach (@_) {
		if ($_ =~ "_UNIT") {push(@units,$_);}
	}
	return @units;
}

sub extract_columns {
	my $col_count = shift;
	for (my $i = 1; $i <= $col_count; $i++) {
		push(@columns, "COLUMN0".$i);
	}
	return @columns;
}

sub extract_fieldsets {
	my $fs_count = shift;
	for (my $i = 1; $i <= $fs_count; $i++) {
		push(@fieldsets, "FIELDSET0".$i);
	}
	return @fieldsets;
}

sub extract_formula {
	my $formula = shift;
	my @x;
	my @form_x;
	$formula = (split /\:/, $formula)[1];
	while ($formula =~ /(INPUT[0-9]{2})/g) {
		push(@x,$1);
	}
	return ($formula, @x);
}

sub extract_list {
	my $list = shift;
	my $filename = (split /\: /, $list)[1];
	my %list = readCfg("$WEBOBS{PATH_FORMS}/$FORMName/$filename");

	return "$WEBOBS{PATH_FORMS}/$FORMName/$filename";
}

sub extract_re {
	my $re = shift;
	return (split /txt\: /, $re)[1];
}

sub count_inputs {
	my $count = 0;
	foreach(@_) {
		if ($_ =~ /(INPUT[0-9]{2}_NAME)/) {
			$count += 1;
		}
	}
	return $count;
}

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

Webobs - 2012-2024 - Institut de Physique du Globe Paris

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
