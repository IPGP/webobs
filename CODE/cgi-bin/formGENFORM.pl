#!/usr/bin/perl

=head1 NAME

formGENFORM.pl

=head1 SYNOPSIS

http://..../formGENFORM.pl?[id=]

=head1 DESCRIPTION

Edit form.

=head1 Configuration GENFORM

See 'showGENFORM.pl' for an example of configuration file 'GENFORM.conf'

=head1 Query string parameter

=over

=item B<id=>

data ID to edit. If void or inexistant, a new entry is proposed.

=back

=cut

use strict;
use warnings;
use Time::Local;
use POSIX qw/strftime/;
use File::Basename;
use CGI;
my $cgi = new CGI;
use CGI::Carp qw(fatalsToBrowser set_message);
set_message(\&webobs_cgi_msg);

# ---- webobs stuff
use WebObs::Config;
use WebObs::Users qw($CLIENT %USERS clientHasRead clientHasEdit clientHasAdm);
use WebObs::Grids;
use WebObs::Utils;
use WebObs::i18n;
use Locale::TextDomain('webobs');
use WebObs::Form;

# ---- local functions
#

# Return information when OK
# (Reminder: we use text/plain as this is an ajax action)
sub htmlMsgOK {
 	print $cgi->header(-type=>'text/plain', -charset=>'utf-8');
	print "$_[0] successfully !\n" if ($WEBOBS{CGI_CONFIRM_SUCCESSFUL} ne "NO");
}

# Return information when not OK
# (Reminder: we use text/plain as this is an ajax action)
sub htmlMsgNotOK {
 	print $cgi->header(-type=>'text/plain', -charset=>'utf-8');
 	print "Update FAILED !\n $_[0] \n";
}

# Print a DB error message to STDERR and show it to the user
sub htmlMsgDBError {
	my ($dbh, $errmsg) = @_;
	print STDERR $errmsg.": ".$dbh->errstr;
	htmlMsgNotOK($errmsg);
}

# Open an SQLite connection to the forms database
sub connectDbForms {
	return DBI->connect("dbi:SQLite:$WEBOBS{SQL_FORMS}", "", "", {
		'AutoCommit' => 1,
		'PrintError' => 1,
		'RaiseError' => 1,
		}) || die "Error connecting to $WEBOBS{SQL_FORMS}: $DBI::errstr";
}

# ---- misc inits
#
set_message(\&webobs_cgi_msg);
my $FORMName = $cgi->param("id");      # name of the form

# ---- standard FORMS inits ----------------------------------

#die "You can't edit GENFORM reports." if (!clientHasEdit(type=>"authforms",name=>"GENFORM"));

my $FORM = new WebObs::Form("$FORMName");

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

my $QryParm   = $cgi->Vars;

# --- DateTime inits -------------------------------------
my $Ctod  = time();  my @tod  = localtime($Ctod);
my $sel_jour  = strftime('%d',@tod);
my $sel_mois  = strftime('%m',@tod);
my $sel_annee = strftime('%Y',@tod);
my $anneeActuelle = strftime('%Y',@tod);
my $sel_hr    = "";
my $sel_mn    = "";
my $today = strftime('%F',@tod);

# ---- specific FORM inits -----------------------------------
my @html;
my $affiche;
my $s;
#my %types    = readCfg($FORM->path."/".$FORM->conf('FILE_TYPE'));
#my @rapports = readCfgFile($FORM->path."/".$FORM->conf('FILE_RAPPORTS'));

my %FORM = readCfg("$WEBOBS{PATH_FORMS}/$FORMName/$FORMName.conf");

$ENV{LANG} = $WEBOBS{LOCALE};

# ----

my $col_count = $FORM{COLUMNS_NUMBER};
my $fs_count  = $FORM{FIELDSETS_NUMBER};
my @keys = sort keys %FORM;
my @names = extract_field_names(@keys);
my @units = extract_field_units(@keys);
my @columns   = map {$_."_LIST"} extract_columns($col_count);
my @fieldsets = extract_fiedlsets($fs_count);


# ---- Variables des menus
my $bang = 1789;
my @anneeListe = ($bang..$anneeActuelle);
my @moisListe  = ('01'..'12');
my @jourListe  = ('01'..'31');
my @heureListe = ("",'00'..'23');
my @minuteListe= ("",'00'..'59');

# ---- Debut de l'affichage HTML
#
print qq[Content-type: text/html

<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>
<head>
<title>] . $FORM->conf('NAME') . qq[</title>
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
    var str = "]  . u2l($FORM->conf('NAME')) . qq[ ?";
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

function verif_formulaire()
{
    if(document.formulaire.site.value == "") {
        alert("Veuillez spécifier le site de prélèvement!");
        document.formulaire.site.focus();
        return false;
    }
/*
    if(document.formulaire.type.value == "") {
        alert("Veuillez entrer un type!");
        document.formulaire.type.focus();
        return false;
    }*/
    submit();
}

function submit()
{
    \$.post("/cgi-bin/formGENFORM.pl", \$("#theform").serialize(), function(data) {
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
my $message = "Saisie de nouvelles donn&eacute;es";
my ($id,$val) = "";

print qq(<form name="formulaire" id="theform" action="">
<input type="hidden" name="oper" value="$USERS{$CLIENT}{UID}">
<input type="hidden" name="delete" value="">

<table width="100%">
  <tr>
    <td style="border: 0">
     <h1>) . $FORM->conf('NAME') . qq(</h1>\
     <h2>$message</h2>
    </td>
  </tr>
);

if ($QryParm->{id} ne "") {
	print qq(<input type="hidden" name="id" value="$QryParm->{id}">);
	print qq(<tr><td style="border: 0"><hr>);
	if ($val ne "") {
		print qq(<p><b>Information de saisie:</b> $val
		<input type="hidden" name="val" value="$val"></p>);
	}
	print qq(<input type="button" value=") . ($id < 0 ? "Reset":"$__{'Remove'}") . qq(" onClick="suppress(1);">);
=pod
	if (clientHasAdm(type=>"authforms",name=>"GENFORM")) {
		print qq(<input type="button" value="$__{'Erase'}" onClick="suppress(2);">);
	}
=cut
	print qq(<hr></td></tr>);
}

print qq(</table>
<table style="border: 0" >
  <tr>
    <td style="border: 0" valign="top">
      <fieldset>
        <legend>Date et lieu du prélèvement</legend>
        <p class="parform">
          <b>Date: </b>
          <select name="annee" size="1">
);

	for (@anneeListe) {
		if ($_ == $sel_annee) {
			print qq(<option selected value="$_">$_</option>);
		} else {
			print qq(<option value="$_">$_</option>);
		}
	}
	print qq(</select>);
	print qq(<select name="mois" size="1">);
	for (@moisListe) {
		if ($_ == $sel_mois) {
			print qq(<option selected value="$_">$_</option>);
		} else {
			print qq(<option value="$_">$_</option>);
		}
	}
	print qq(</select>);
	print qq( <select name=jour size="1">);
	for (@jourListe) {
		if ($_ == $sel_jour) {
			print qq(<option selected value="$_">$_</option>);
		} else {
			print qq(<option value="$_">$_</option>);
		}
	}
	print "</select>";

	print qq(&nbsp;&nbsp;<b>Heure: </b><select name=hr size="1">);
	for (@heureListe) {
		if ($_ eq $sel_hr) {
			print qq(<option selected value="$_">$_</option>);
		} else {
			print qq(<option value="$_">$_</option>);
		}
	}
	print qq(</select>);
	print qq(<select name=mn size="1">);
	for (@minuteListe) {
		if ($_ eq $sel_mn) {
			print qq(<option selected value="$_">$_</option>);
		} else {
		   print qq(<option value="$_">$_</option>);
		}
	}
	print qq(</select><BR>
	<B>Site: </B>
	  <select name="site" size="1"
		onMouseOut="nd()"onmouseover="overlib('S&eacute;lectionner le site du prélèvement')">
	  <option value=""></option>);

	for (@NODESSelList) {
		my @cle = split(/\|/,$_);
		if ($cle[0] eq $sel_site) {
			print qq(<option selected value="$cle[0]">$cle[1]</option>);
		} else {
			print qq(<option value="$cle[0]">$cle[1]</option>);
		}
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
                if ($unit ne "") {$txt = "<B>$name </B> (en $unit) = "} else {$txt = "<B>$name </B> = "};
                while ($name =~ /(<sup>|<\/sup>|<sub>|<\/sub>|\+|\-|\&|;)/) {
                    $name =~ s/(<sup>|<\/sup>|<sub>|<\/sub>|\+|\-|\&|;)//;
                }
                if ($type =~ "formula:") {
                    (my $formula, my @x) = extract_formula($type);
                    @x = map {$FORM{"$_\_NAME"}} @x;
                    foreach (@x) {
                        while ($_ =~ /(<sup>|<\/sup>|<sub>|<\/sub>|\+|\-|\&|;)/) {
                            $_ =~ s/(<sup>|<\/sup>|<sub>|<\/sub>|\+|\-|\&|;)//;
                        }
                        $formula =~ s/(INPUT[0-9]{2})/parseFloat(formulaire.$_.value)/;
                    }
                    foreach (@x) {
                        print qq(
                            <script>
                                formulaire.$_.onchange = function() {
                                    formulaire.$name.value = parseFloat($formula).toFixed(2);
                                    console.log(formulaire);
                                }
                            </script>
                        );
                    }
                    print qq($txt<input size=6 readOnly class=inputNumNoEdit name="$name"
                        onMouseOut="nd()" onmouseover="overlib('$formula')"><BR>
                        <script>
                            formulaire.$name.value = parseFloat($formula).toFixed(2);
                        </script>);
                } elsif ($type =~ "list:") {
                    my @list = extract_list($type);
                    print qq($txt<select name="$name" size=1
                        onMouseOut="nd()" onmouseover="overlib('Select one value')"><option value=""></option>);
                    for (my $j = 1; $j <= $#list+1; $j++) {
                        print "<option value=\"$j\">$list[$j-1]</option>";
                    }
                    print qq(</select><BR>);
                } else {
                    print qq($txt<input size=5 class=inputNum name=\"$name\" 
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
        <input type="button" name=lien value="Annuler"
         onClick="document.location=') . $cgi->param('return_url') . qq('" style="font-weight: normal">
        <input type="button" value="Soumettre" onClick="verif_formulaire();">
      </P>
    </td>
  </tr>
</table>
</form>

<br>
</body>
</html>);

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

sub extract_fiedlsets {
    my $fs_count = shift;
    for (my $i = 1; $i <= $fs_count; $i++) {
        push(@fieldsets, "FIELDSET0".$i);
    }
    return @fieldsets;
}

sub extract_formula {
    my $formula = shift;
    my @x;
    $formula = (split /\:/, $formula)[1];
    while ($formula =~ /(INPUT[0-9]{2})/g) {
         push(@x,$1);
    }
    return ($formula, @x);
}

sub extract_list {
    my $list = shift;
    my @list = split(/,/, (split /\:/, $list)[1]);
    return @list;
}

__END__

=pod

=head1 AUTHOR(S)

Lucas Dassin

=head1 COPYRIGHT

Webobs - 2012-2023 - Institut de Physique du Globe Paris

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
