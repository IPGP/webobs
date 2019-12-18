#!/usr/bin/perl

=head1 NAME

usersMgr.pl 

=head1 SYNOPSIS

/cgi-bin/usersMgr.pl?....see query string below ....

=head1 DESCRIPTION

Builds html page for WebObs' users Manager. Displays all 'USERS' DataBase tables and 
provides maintenance functions on these tables: insert new rows, delete rows, updates rows.

First apply the maintenance function (action+tbl) if requested, then build page to display all tables.

usersMgr.pl assumes that the DataBase 'USERS' have sql-triggers defined ('deluid' and 'delgid' triggers)
to handle clean deletion of userid (uid) and groupid (gid) references across all tables. 

=head1 QUERY-STRING PARAMETERS

=over

=item B<action=>

One of { display | insert | update | updgrp | delete } . Defaults to 'display' .
'insert', 'update' and 'delete' require a 'tbl' (table to act upon).  

=item B<tbl=>

{ user | group | notification | proc | view | form | wiki | misc } .  

=item B<uid=>, B<gid=>, B<fullname=>, B<login=>, B<email=>, B<event=>, B<valid=>, B<mailsub=>, B<mailatt=>, B<act=>, B<res=>, B<auth=>

Any, depending on requested maintenance function (action+tbl) 

=back

=cut

use strict;
use warnings;
use Time::HiRes qw/time gettimeofday tv_interval usleep/;
use POSIX qw/strftime/;
use File::Basename;
use File::Path qw/make_path/;
use CGI;
my $cgi = new CGI;
use CGI::Carp qw(fatalsToBrowser set_message);
use DBI;
use IO::Socket;
use WebObs::Config;
use WebObs::Users;
$|=1;

set_message(\&webobs_cgi_msg);

# ---- checks/defaults query-string elements 
my $QryParm   = $cgi->Vars;
$QryParm->{'action'}    ||= 'display';

# ---- some globals
my $go2top = "&nbsp;&nbsp;<A href=\"#MYTOP\"><img src=\"/icons/go2top.png\"></A>";
my @qrs;
my $buildTS = strftime("%Y-%m-%d %H:%M:%S %z",localtime(int(time())));
my $userMsg="$buildTS ";
my $userMsgColor='black';
my $notfMsg="$buildTS ";
my $notfMsgColor='black';
my $authMsg="$buildTS ";
my $authMsgColor='black';
my $refMsg = my $refMsgColor = "";
my $lastDBIerrstr = "";

# ---- any reasons why we couldn't go on ?
# ----------------------------------------
if ( ! WebObs::Users::clientHasAdm(type=>"authmisc",name=>"users")) {
	die "You are not authorized" ;
}

# ---- parse/defaults query string
# -----------------------------------------------------------------------------
$QryParm->{'action'}    ||= "display";
$QryParm->{'tbl'}       ||= "";
$QryParm->{'fullname'}  ||= "";
$QryParm->{'login'}     ||= "";
$QryParm->{'email'}     ||= "";
$QryParm->{'uid'}       ||= "";
$QryParm->{'gid'}       ||= "";
$QryParm->{'event'}     ||= "";
$QryParm->{'valid'}     ||= "";
$QryParm->{'mailsub'}   ||= "";
$QryParm->{'mailatt'}   ||= "";
$QryParm->{'act'}       ||= "";
$QryParm->{'res'}       ||= "";
$QryParm->{'auth'}      ||= "";
$QryParm->{'OLDuid'}    ||= "";
$QryParm->{'OLDgid'}    ||= "";
$QryParm->{'OLDevent'}  ||= "";
$QryParm->{'OLDuid'}    ||= "";
$QryParm->{'OLDact'}    ||= "";
$QryParm->{'OLDres'}    ||= "";
my $authtable = "";
$authtable = $WEBOBS{SQL_TABLE_AUTHPROCS} if ($QryParm->{'tbl'} eq "proc") ;
$authtable = $WEBOBS{SQL_TABLE_AUTHVIEWS} if ($QryParm->{'tbl'} eq "view") ;
$authtable = $WEBOBS{SQL_TABLE_AUTHFORMS} if ($QryParm->{'tbl'} eq "form") ;
$authtable = $WEBOBS{SQL_TABLE_AUTHWIKIS} if ($QryParm->{'tbl'} eq "wiki") ;
$authtable = $WEBOBS{SQL_TABLE_AUTHMISC}  if ($QryParm->{'tbl'} eq "misc") ;

# ---- process (execute) sql insert new row into table 'tbl' 
# -----------------------------------------------------------------------------
if ($QryParm->{'action'} eq 'insert') {
	# query-string must contain all required DB columns values for an sql insert
	my $q='';
	if ($QryParm->{'tbl'} eq "user") {
		$q = "insert into $WEBOBS{SQL_TABLE_USERS} values(\'$QryParm->{'uid'}\',\'$QryParm->{'fullname'}\',\'$QryParm->{'login'}\',\'$QryParm->{'email'}\',\'$QryParm->{'valid'}\')";
		$refMsg = \$userMsg; $refMsgColor = \$userMsgColor; 
	}
	elsif ($QryParm->{'tbl'} eq "group") {
		$q = "insert into $WEBOBS{SQL_TABLE_GROUPS} values(\'$QryParm->{'gid'}\',\'$QryParm->{'uid'}\')";
		$refMsg = \$userMsg; $refMsgColor = \$userMsgColor; 
	}
	elsif ($QryParm->{'tbl'} eq "notification") {
		$q = "insert into $WEBOBS{SQL_TABLE_NOTIFICATIONS} values(\'$QryParm->{'event'}\',\'$QryParm->{'valid'}\',\'$QryParm->{'uid'}\',\'$QryParm->{'mailsub'}\',\'$QryParm->{'mailatt'}\',\'$QryParm->{'act'}\')";
		$refMsg = \$notfMsg; $refMsgColor = \$notfMsgColor; 
	}
	elsif ($authtable ne "") {
		$q = "insert into $authtable values(\'$QryParm->{'uid'}\',\'$QryParm->{'res'}\',\'$QryParm->{'auth'}\')";
		$refMsg = \$authMsg; $refMsgColor = \$authMsgColor; 
	} else { die "$QryParm->{'action'} for unknown table"; }
	my $rows = dbu($q);
	$$refMsg  .= ($rows == 1) ? "  having inserted new $QryParm->{'tbl'} " : "  failed to insert new $QryParm->{'tbl'}"; 
	$$refMsg  .= " $lastDBIerrstr";
	$$refMsgColor  = ($rows == 1) ? "green" : "red";
	#$$refMsg  .= " - <i>$q</i>";
}
# ---- process (execute) sql update a row of table 'tbl' 
# ----------------------------------------------------------------------------
if ($QryParm->{'action'} eq 'update') {
	# query-string must contain all required DB columns values for an sql insert
	my $q='';
	if ($QryParm->{'tbl'} eq "user") {
		$q = "update $WEBOBS{SQL_TABLE_USERS} set UID=\'$QryParm->{'uid'}\', FULLNAME=\'$QryParm->{'fullname'}\', LOGIN=\'$QryParm->{'login'}\', EMAIL=\'$QryParm->{'email'}\', VALIDITY=\'$QryParm->{'valid'}\'";
		$q .= " WHERE UID=\'$QryParm->{'OLDuid'}\'";
		$refMsg = \$userMsg; $refMsgColor = \$userMsgColor; 
	}
	elsif ($QryParm->{'tbl'} eq "group") {
		$q = "update $WEBOBS{SQL_TABLE_GROUPS} set GID=\'$QryParm->{'gid'}\', UID=\'$QryParm->{'uid'}\'";
		$q .= " WHERE GID=\'$QryParm->{'OLDgid'}\' AND UID=\'$QryParm->{'OLDuid'}\'";
		$refMsg = \$userMsg; $refMsgColor = \$userMsgColor; 
	}
	elsif ($QryParm->{'tbl'} eq "notification") {
		$q = "update $WEBOBS{SQL_TABLE_NOTIFICATIONS} set EVENT=\'$QryParm->{'event'}\', VALIDITY=\'$QryParm->{'valid'}\', UID=\'$QryParm->{'uid'}\', MAILSUBJECT=\'$QryParm->{'mailsub'}\', MAILATTACH=\'$QryParm->{'mailatt'}\',ACTION=\'$QryParm->{'act'}\'";
		$q .= " WHERE EVENT=\'$QryParm->{'OLDevent'}\' AND UID=\'$QryParm->{'OLDuid'}\' AND ACTION=\'$QryParm->{'OLDact'}\'";
		$refMsg = \$notfMsg; $refMsgColor = \$notfMsgColor; 
	} 
	elsif ($authtable ne "") {
		$q = "update $authtable set UID=\'$QryParm->{'uid'}\', RESOURCE=\'$QryParm->{'res'}\', AUTH=\'$QryParm->{'auth'}\'";
		$q .= " WHERE UID=\'$QryParm->{'OLDuid'}\' AND RESOURCE=\'$QryParm->{'OLDres'}\'";
		$refMsg = \$authMsg; $refMsgColor = \$authMsgColor; 
	} else { die "$QryParm->{'action'} for unknown table"; }
	my $rows = dbu($q);
	$$refMsg  .= ($rows == 1) ? "  having updated $QryParm->{'tbl'} " : "  failed to update $QryParm->{'tbl'}"; 
	$$refMsg  .= " $lastDBIerrstr";
	$$refMsgColor  = ($rows == 1) ? "green" : "red";
	#$$refMsg  .= " - <i>$q</i>";
}
# ---- process (execute) sql update table 'groups' after user insert or update
# ----------------------------------------------------------------------------
if (($QryParm->{'action'} eq 'insert' || $QryParm->{'action'} eq 'update') && $QryParm->{'tbl'} eq "user") {
	my @gids = $cgi->param('gid');
	my $q0 = "insert into $WEBOBS{SQL_TABLE_GROUPS} values (\'+++\',\'$QryParm->{'uid'}\')";
	my $q1 = "delete from $WEBOBS{SQL_TABLE_GROUPS} WHERE UID=\'$QryParm->{'uid'}\' AND GID != \'+++\'";
	my @values = map { "('$_',\'$QryParm->{'uid'}\')" } @gids ;
	my $q2 = "insert or replace into $WEBOBS{SQL_TABLE_GROUPS} VALUES ".join(',',@values);
	my $q3 = "delete from $WEBOBS{SQL_TABLE_GROUPS} WHERE UID=\'$QryParm->{'uid'}\' AND GID = \'+++\'";
	my $rows = dbuow($q0,$q1,$q2,$q3);
	$userMsg  .= ($rows >= 1) ? "  having updated $WEBOBS{SQL_TABLE_GROUPS} " : "  failed to update $WEBOBS{SQL_TABLE_GROUPS}"; 
	$userMsg  .= " $lastDBIerrstr";
	$userMsgColor  = ($rows >= 1) ? "green" : "red";
	#$userMsg  .= " - <i>$q1 * $q2</i>";
}
# ---- process (execute) sql update table 'groups' 
# ----------------------------------------------------------------------------
if ($QryParm->{'action'} eq 'updgrp') {
	my @uids = $cgi->param('uid');
	my $q0 = "insert into $WEBOBS{SQL_TABLE_GROUPS} values (\'$QryParm->{'gid'}\',\'+++\')";
	my $q1 = "delete from $WEBOBS{SQL_TABLE_GROUPS} WHERE GID=\'$QryParm->{'gid'}\' AND UID != \'+++\'";
	my @values = map { "(\'$QryParm->{'gid'}\','$_')" } @uids ;
	my $q2 = "insert or replace into $WEBOBS{SQL_TABLE_GROUPS} VALUES ".join(',',@values);
	my $q3 = "delete from $WEBOBS{SQL_TABLE_GROUPS} WHERE GID=\'$QryParm->{'gid'}\' AND UID = \'+++\'";
	my $rows = dbuow($q0,$q1,$q2,$q3);
	$userMsg  .= ($rows >= 1) ? "  having updated $WEBOBS{SQL_TABLE_GROUPS} " : "  failed to update $WEBOBS{SQL_TABLE_GROUPS}"; 
	$userMsg  .= " $lastDBIerrstr";
	$userMsgColor  = ($rows >= 1) ? "green" : "red";
	#$userMsg  .= " - <i>$q1 * $q2</i>";
}
# ---- process (execute) sql delete a row of table 'tbl' 
# ------------------------------------------------------
if ($QryParm->{'action'} eq 'delete') {
	my $q='';
	# query-string must contain all required DB columns values for an sql insert
	if ($QryParm->{'tbl'} eq "user") {
		$q = "delete from $WEBOBS{SQL_TABLE_USERS}";
		$q .= " WHERE UID=\'$QryParm->{'uid'}\'";
		$refMsg = \$userMsg; $refMsgColor = \$userMsgColor; 
	}
	elsif ($QryParm->{'tbl'} eq "group") {
		$q = "delete from $WEBOBS{SQL_TABLE_GROUPS}";
		$q .= " WHERE GID=\'$QryParm->{'gid'}\' AND UID=\'$QryParm->{'uid'}\'";
		$refMsg = \$userMsg; $refMsgColor = \$userMsgColor; 
	}
	elsif ($QryParm->{'tbl'} eq "notification") {
		$q = "delete from $WEBOBS{SQL_TABLE_NOTIFICATIONS}";
		$q .= " WHERE EVENT=\'$QryParm->{'event'}\' AND UID=\'$QryParm->{'uid'}\' AND ACTION=\'$QryParm->{'act'}\'";
		$refMsg = \$notfMsg; $refMsgColor = \$notfMsgColor; 
	}
	elsif ($authtable ne "") {
		$q = "delete from $authtable";
		$q .= " WHERE UID=\'$QryParm->{'uid'}\' AND RESOURCE=\'$QryParm->{'res'}\'";
		$refMsg = \$authMsg; $refMsgColor = \$authMsgColor; 
	} else { die "$QryParm->{'action'} for unknown table"; }
	my $rows = dbu($q);
	$$refMsg  .= ($rows >= 1) ? "  having deleted in $QryParm->{'tbl'} " : "  failed to delete in $QryParm->{'tbl'}"; 
	$$refMsg  .= " $lastDBIerrstr";
	$$refMsgColor  = ($rows >= 1) ? "green" : "red";
	#$$refMsg  .= " - <i>$q</i>";
}
# ---- process (execute) sql delete 
# ---------------------------------------------------------------------------------------
if ($QryParm->{'action'} eq 'deleteU') {
	if ($QryParm->{'tbl'} eq "group") {
		my $q = "delete from $WEBOBS{SQL_TABLE_GROUPS} where GID=\'$QryParm->{'gid'}\'";
		my $rows = dbu($q);
		$userMsg  .= ($rows >= 1) ? "  having deleted $QryParm->{'tbl'}" : "  failed to delete $QryParm->{'tbl'}"; 
		$userMsg  .= " $lastDBIerrstr";
		$userMsgColor  = ($rows >= 1) ? "green" : "red";
		#$userMsg  .= " - <i>$q</i>";
	}
	if ($QryParm->{'tbl'} eq "notification") {
		my $q = "delete from $WEBOBS{SQL_TABLE_NOTIFICATIONS} where EVENT=\'$QryParm->{'event'}\'";
		my $rows = dbu($q);
		$notfMsg  .= ($rows >= 1) ? "  having deleted $QryParm->{'tbl'} " : "  failed to delete $QryParm->{'tbl'}"; 
		$notfMsg  .= " $lastDBIerrstr";
		$notfMsgColor  = ($rows >= 1) ? "green" : "red";
		#$notfMsg  .= " - <i>$q</i>";
	}
}

# ---- start html page
# --------------------
print $cgi->header(-type=>'text/html',-charset=>'utf-8');
print '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">', "\n";

print <<"EOHEADER";
<html>
<head>
<meta http-equiv="content-type" content="text/html; charset=utf-8">
<title>Users Manager</title>
<link rel="stylesheet" type="text/css" href="/$WEBOBS{FILE_HTML_CSS}">
<link rel="stylesheet" type="text/css" href="/css/users.css">
<link rel="stylesheet" type="text/css" href="/css/scheduler.css">
<script language="JavaScript" src="/js/jquery.js" type="text/javascript"></script>
<script language="JavaScript" src="/js/users.js" type="text/javascript"></script>
<script language="JavaScript" src="/js/htmlFormsUtils.js" type="text/javascript"></script>
<script language="JavaScript" type="text/javascript">
\$(document).ready(function(){
Gscriptname = \"$ENV{SCRIPT_NAME}\"; // required by users.js
});
</script>
</head>
EOHEADER

# ---- build users and groups 'select dropdowns contents' 
# -----------------------------------------------------------------------------
my $quusers  = "select distinct(UID) from $WEBOBS{SQL_TABLE_USERS} order by uid";
@qrs   = qx(sqlite3 $WEBOBS{SQL_DB_USERS} "$quusers");
chomp(@qrs);
my $selusers = ""; map { $selusers .= "<option>$_</option>" } @qrs; 

my $qugrps  = "select distinct(GID) from $WEBOBS{SQL_TABLE_GROUPS} order by gid";
@qrs   = qx(sqlite3 $WEBOBS{SQL_DB_USERS} "$qugrps");
chomp(@qrs);
my $selgrps = ""; map { $selgrps .= "<option>$_</option>" } @qrs;  

# ---- build 'users' table result rows 
# -----------------------------------------------------------------------------
my $qusers  = "select u.UID,FULLNAME,LOGIN,EMAIL,VALIDITY,group_concat(GID) AS groups";
$qusers .= " from $WEBOBS{SQL_TABLE_USERS} u left join $WEBOBS{SQL_TABLE_GROUPS} g on (u.uid = g.uid)";
$qusers .= " group by u.uid order by u.uid";
@qrs   = qx(sqlite3 $WEBOBS{SQL_DB_USERS} "$qusers");
chomp(@qrs);
my $dusers='';
my $dusersCount=0; my $dusersId='';
for (@qrs) {
	(my $dusers_uid, my $dusers_fullname, my $dusers_login, my $dusers_email, my $dusers_validity, my $dusers_groups) = split(/\|/,$_);
	$dusersCount++; $dusersId="udef".$dusersCount;
	if ($dusers_uid eq "!" || $dusers_uid eq "?" ) {
		$dusers .= "<tr id=\"$dusersId\"><td class=\"tdlock\">";
		$dusers .= "<td class=\"tdlock\">";
		$dusers .= "<td class=\"tdlock\">$dusers_uid</td><td class=\"tdlock\">$dusers_fullname</td><td class=\"tdlock\">$dusers_login</td><td class=\"tdlock\">$dusers_email</td><td class=\"tdlock\">$dusers_validity</td><td class=\"tdlock\">$dusers_groups</td></tr>\n";
	} else {
		$dusers .= "<tr id=\"$dusersId\"><td style=\"width:12px\" class=\"tdlock\"><a href=\"#IDENT\" onclick=\"openPopupUser($dusersId,'$WEBOBS{SQL_TABLE_USERS}');return false\"><img title=\"edit user\" src=\"/icons/modif.png\"></a>";
		$dusers .= "<td style=\"width:12px\" class=\"tdlock\"><a href=\"#IDENT\" onclick=\"postDeleteUser($dusersId);return false\"><img title=\"delete user\" src=\"/icons/no.png\"></a>";
		$dusers .= "<td>$dusers_uid</td><td nowrap>$dusers_fullname</td><td>$dusers_login</td><td>$dusers_email</td><td>$dusers_validity</td><td>$dusers_groups</td></tr>\n";
	}
}

# ---- build 'unique groups' table result rows 
# -----------------------------------------------------------------------------
my $qugrps  = "select distinct(GID) ";
$qugrps .= "from $WEBOBS{SQL_TABLE_GROUPS} order by gid";
@qrs   = qx(sqlite3 $WEBOBS{SQL_DB_USERS} "$qugrps");
chomp(@qrs);
my $dugrps='';
my $dugrpsCount=0; my $dugrpsId='';
for (@qrs) {
	#(my $dgrps_gid, my $dgrps_uid) = split(/\|/,$_);
	$dugrpsCount++; $dugrpsId="nudef".$dugrpsCount;
	$dugrps .= "<tr id=\"$dugrpsId\"><td style=\"width:12px\" class=\"tdlock\"><a href=\"#IDENT\" onclick=\"postDeleteUGroup($dugrpsId);return false\"><img title=\"delete group\" src=\"/icons/no.png\"></a>";
	$dugrps .= "<td class=\"tdlock\">$_</tr>\n";
}

# ---- build 'groups' table result rows 
# -----------------------------------------------------------------------------
my $qgrps  = "select GID,UID ";
$qgrps .= "from $WEBOBS{SQL_TABLE_GROUPS} order by gid,uid";
@qrs   = qx(sqlite3 $WEBOBS{SQL_DB_USERS} "$qgrps");
chomp(@qrs);
my $dgrps='';
my $dgrpsCount=0; my $dgrpsId='';
for (@qrs) {
	(my $dgrps_gid, my $dgrps_uid) = split(/\|/,$_);
	$dgrpsCount++; $dgrpsId="gdef".$dgrpsCount;
	$dgrps .= "<tr id=\"$dgrpsId\"><td style=\"width:12px\" class=\"tdlock\"><a href=\"#IDENT\" onclick=\"openPopupGroup($dgrpsId);return false\"><img title=\"edit grp\" src=\"/icons/modif.png\"></a>";
	$dgrps .= "<td style=\"width:12px\" class=\"tdlock\"><a href=\"#IDENT\" onclick=\"postDeleteGroup($dgrpsId);return false\"><img title=\"delete group\" src=\"/icons/no.png\"></a>";
	$dgrps .= "<td>$dgrps_gid<td>$dgrps_uid</tr>\n";
}

# ---- build S'groups' table result rows 
# -----------------------------------------------------------------------------
my $Sqgrps  = "select gid,group_concat(uid) as uids ";
$Sqgrps .= "from $WEBOBS{SQL_TABLE_GROUPS} group by gid order by gid";
@qrs   = qx(sqlite3 $WEBOBS{SQL_DB_USERS} "$Sqgrps");
chomp(@qrs);
my $Sdgrps='';
my $SdgrpsCount=0; my $SdgrpsId='';
for (@qrs) {
	(my $Sdgrps_gid, my $Sdgrps_uids) = split(/\|/,$_);
	$SdgrpsCount++; $SdgrpsId="gdef".$SdgrpsCount;
	$Sdgrps .= "<tr id=\"$SdgrpsId\"><td style=\"width:12px\" class=\"tdlock\"><a href=\"#IDENT\" onclick=\"openPopupGroup($SdgrpsId);return false\"><img title=\"edit grp\" src=\"/icons/modif.png\"></a>";
	$Sdgrps .= "<td style=\"width:12px\" class=\"tdlock\"><a href=\"#IDENT\" onclick=\"postDeleteUGroup($SdgrpsId);return false\"><img title=\"delete group\" src=\"/icons/no.png\"></a>";
	$Sdgrps .= "<td>$Sdgrps_gid<td>$Sdgrps_uids</tr>\n";
}

# ---- build 'unique evnt notifications' table result rows 
# -----------------------------------------------------------------------------
my $qunotf  = "select distinct(EVENT) ";
$qunotf .= "from $WEBOBS{SQL_TABLE_NOTIFICATIONS} order by EVENT";
@qrs   = qx(sqlite3 $WEBOBS{SQL_DB_USERS} "$qunotf");
chomp(@qrs);
my $dunotf='';
my $dunotfCount=0; my $dunotfId='';
for (@qrs) {
	#(my $dgrps_gid, my $dgrps_uid) = split(/\|/,$_);
	$dunotfCount++; $dunotfId="nudef".$dunotfCount;
	$dunotf .= "<tr id=\"$dunotfId\"><td style=\"width:12px\" class=\"tdlock\"><a href=\"#POSTBOARD\" onclick=\"postDeleteUNotf($dunotfId);return false\"><img title=\"delete group\" src=\"/icons/no.png\"></a>";
	$dunotf .= "<td class=\"tdlock\">$_</tr>\n";
}

# ---- build 'notifications' table result rows 
# -----------------------------------------------------------------------------
my $qnotf  = "select EVENT,VALIDITY,UID,MAILSUBJECT,MAILATTACH,ACTION ";
$qnotf .= "from $WEBOBS{SQL_TABLE_NOTIFICATIONS} order by 1";
@qrs   = qx(sqlite3 $WEBOBS{SQL_DB_USERS} "$qnotf");
chomp(@qrs);
my $dnotf='';
my $dnotfCount=0; my $dnotfId='';
for (@qrs) {
	(my $dnotf_event, my $dnotf_valid, my $dnotf_mail, my $dnotf_mailsubj, my $dnotf_mailatt, my $dnotf_act) = split(/\|/,$_);
	$dnotfCount++; $dnotfId="ndef".$dnotfCount;
	$dnotf .= "<tr id=\"$dnotfId\"><td style=\"width:12px\" class=\"tdlock\"><a href=\"#POSTBOARD\" onclick=\"openPopupNotf($dnotfId);return false\"><img title=\"edit grp\" src=\"/icons/modif.png\"></a>";
	$dnotf .= "<td style=\"width:12px\" class=\"tdlock\"><a href=\"#POSTBOARD\" onclick=\"postDeleteNotf($dnotfId);return false\"><img title=\"delete notification\" src=\"/icons/no.png\"></a>";
	$dnotf .= "<td>$dnotf_event<td>$dnotf_valid<td>$dnotf_mail<td>$dnotf_mailsubj<td>$dnotf_mailatt<td>$dnotf_act</tr>\n";
}

# ---- build 'notifications' table result rows 
# -----------------------------------------------------------------------------
my $postboardstatus="";
my @PBREPLY = qx($WEBOBS{ROOT_CODE}/shells/postboard status);
if ( scalar(@PBREPLY) > 0 ) {
	my @td1 = map {$_ =~ s/\n/<br>/; $_} (grep { /STATTIME=|STARTED=|PID=|USER=/ } @PBREPLY);
	s/POSTBOARD NOT RUNNING/<span class=\"statusBAD\">POSTBOARD NOT RUNNING<\/span>/ for @td1;
	my @td2 = map {$_ =~ s/\n/<br>/; $_} (grep { /FIFO=|LOG=/ } @PBREPLY);
	$postboardstatus = "<table><tr valign=\"top\"><td class=\"status\">@td1<td class=\"status\">@td2</table>"
} else { $postboardstatus = "<span class=\"statusBAD\">POSTBOARD IS NOT RUNNING !</span>"}


# ---- build 'auth' table result rows 
# -----------------------------------------------------------------------------
my %TA;
for my $an (qw(proc view form wiki misc)) {
	$TA{$an}{table} = $WEBOBS{SQL_TABLE_AUTHPROCS} if ($an eq "proc") ;
	$TA{$an}{table} = $WEBOBS{SQL_TABLE_AUTHVIEWS} if ($an eq "view") ;
	$TA{$an}{table} = $WEBOBS{SQL_TABLE_AUTHFORMS} if ($an eq "form") ;
	$TA{$an}{table} = $WEBOBS{SQL_TABLE_AUTHWIKIS} if ($an eq "wiki") ;
	$TA{$an}{table} = $WEBOBS{SQL_TABLE_AUTHMISC}  if ($an eq "misc") ;
	$TA{$an}{qauth}  = "select UID,RESOURCE,AUTH from $TA{$an}{table} order by UID,RESOURCE";
	my @qrs   = qx(sqlite3 $WEBOBS{SQL_DB_USERS} '$TA{$an}{qauth}');
	chomp(@qrs);
	$TA{$an}{dauth}='';
	$TA{$an}{dauthCount}=0;
	for (@qrs) {
		(my $dauth_uid, my $dauth_res, my $dauth_auth) = split(/\|/,$_);
		$TA{$an}{dauthCount}++; my $dauthId="adef$an".$TA{$an}{dauthCount};
		$TA{$an}{dauth} .= "<tr id=\"$dauthId\"><td style=\"width:12px\" class=\"tdlock\"><a href=\"#AUTH\" onclick=\"openPopupAuth('$an',$dauthId);return false\"><img title=\"edit grp\" src=\"/icons/modif.png\"></a>";
		$TA{$an}{dauth} .= "<td style=\"width:12px\" class=\"tdlock\"><a href=\"#AUTH\" onclick=\"postDeleteAuth('$an',$dauthId);return false\"><img title=\"delete autorisation\" src=\"/icons/no.png\"></a>";
		$TA{$an}{dauth} .= "<td>$dauth_uid<td>$dauth_res<td>$dauth_auth</tr>\n";
	}
}

# ---- assemble the page 
# -----------------------------------------------------------------------------
print <<"EOPART1";
<body style="min-height: 600px;">
<!-- overLIB (c) Erik Bosrup -->
<div id="overDiv" style="position:absolute; visibility:hidden; z-index:1000;"></div>
<script language="JavaScript" src="/js/overlib/overlib.js" type="text/javascript"></script>

<A NAME="MYTOP"></A>
<h1>WebObs Users Manager</h1>

<P class="subMenu"> <b>&raquo;&raquo;</b> [ <a href="#IDENT">Identification</a> | <a href="#POSTBOARD">PostBoard Subscriptions</a> | <a href="#AUTH">Authorizations</a>]</P>
<br>

<div id="ovly" style="display: none"></div>

<A NAME="IDENT"></A>
<div class="drawer">
<div class="drawerh2" >&nbsp;<img src="/icons/drawer.png"  onClick="toggledrawer('\#idID');">
Identifications&nbsp;$go2top
</div>
<div id="idID">
	<div id="userMsg" style="font-weight: bold; color: $userMsgColor">&bull; $userMsg</div><br/>
	<form id="overlay_form_user" class="overlay_form" style="display:none">
	<input type="hidden" name="action" value="">
	<input type="hidden" name="tbl" value="">
	<input type="hidden" name="OLDuid" value="">
	<input type="hidden" name="OLDgid" value="">
	<p><b><i>Edit user definition</i></b></p>
	<label>Uid:<span class="small">WebObs userid</span></label>
	<input type="text" name="uid" value=""/><br/>
	<label>Name:<span class="small">full name</span></label>
	<input type="text" name="fullname" value=""/><br/>
	<label>Login:<span class="small">http userid</span></label>
	<input type="text" name="login" value=""/><br/>
	<label>Email:<span class="small">mail address</span></label>
	<input type="text" name="email" value=""/><br/>
	<label for="gid">Gid(s):<span class="small">group id(s)<br>Ctrl for multiple</span></label>
	<!--<input type="text" name="gid" id="gid" value=""/><br/>-->
	<select name="gid" id="gid" size="5" multiple>$selgrps</select><br/> 
	<label>Validity:<span class="small">Y or N</span></label>
	<input type="text" name="valid" value=""/><br/>
	<p style="margin: 0px; text-align: center">
		<input type="button" name="sendbutton" value="send" onclick="sendPopupUser(); return false;" /> <input type="button" value="cancel" onclick="closePopup(); return false" />
	</p>
	</form>
	<form id="overlay_form_group" class="overlay_form" style="display:none">
	<input type="hidden" name="action" value="">
	<input type="hidden" name="tbl" value="">
	<input type="hidden" name="OLDuid" value="">
	<input type="hidden" name="OLDgid" value="">
	<p><b><i>Edit group/user definition</i></b></p>
	<label for="gid">Gid:<span class="small">group id</span></label>
	<input type="text" name="gid" id="gid"value=""/><br/>
	<label for="uid">Uid(s):<span class="small">WebObs userid(s)<br>Ctrl for multiple</span></label>
	<!--<input type="text" name="uid" id="uid" value=""/><br/>-->
	<select name="uid" id="uid" size="5" multiple>$selusers</select><br/> 
	<p style="margin: 0px; text-align: center">
		<input type="button" name="sendbutton" value="send" onclick="sendPopupGroup(); return false;" /> <input type="button" value="cancel" onclick="closePopup(); return false" />
	</p>
	</form>

	<fieldset id="users-field"><legend><b>Users</b></A></legend>
		<div style="background: #BBB">
			<b>$dusersCount</b> users defined
		</div>
		<div class="dusers-container">
			<div class="dusers">
				<table class="dusers">
				<thead><tr><th style=\"width:12px\"><a href="#IDENT" onclick="openPopupUser(-1);return false"><img title="define a new user" src="/icons/modif.png"></a>
				<th style=\"width:12px\" class="tdlock">&nbsp;
				<th>Uid</th><th>Name</th><th>Login</th><th>Email</th><th>V</th><th>Groups</th>
				</tr></thead>
				<tbody>
				$dusers
				</tbody>
				</table>
			</div>
		</div>
	</fieldset>

	<fieldset id="groups-field"><legend><b>Groups</b></A></legend>
		<div style="background: #BBB">
			<b>$SdgrpsCount</b> groups defined
		</div>
		<div class="dugrps-container">
			<div class="dugrps">
				<table class="dugrps">
				<thead><tr><th style=\"width:12px\"><a href="#IDENT" onclick="openPopupGroup(-1);return false"><img title="define new group/user" src="/icons/modif.png"></a>
				<th style=\"width:12px\" class="tdlock">&nbsp;
				<th>Gid<th>Uids
				</tr></thead>
				<tbody>
				$Sdgrps
				</tbody>
				</table>
			</div>
		</div>
	</fieldset>

</div>
</div>

<BR>
<A NAME="POSTBOARD"></A>
<div class="drawer">
<div class="drawerh2" >&nbsp;<img src="/icons/drawer.png"  onClick="toggledrawer('\#pbID');">
PostBoard subscriptions&nbsp;$go2top
</div>
<div id="pbID">
	<div id="notfMsg" style="font-weight: bold; color: $notfMsgColor">&bull; $notfMsg</div><br/>
	<form id="overlay_form_notf" class="overlay_form" style="display:none">
	<input type="hidden" name="action" value="">
	<input type="hidden" name="tbl" value="">
	<input type="hidden" name="OLDevent" value="">
	<input type="hidden" name="OLDuid" value="">
	<input type="hidden" name="OLDact" value="">
	<p><b><i>Edit notification definition</i></b></p>
	<label>Event:<span class="small">Event ID (major[.minor])</span></label>
	<input type="text" name="event" value=""/><br/>
	<label>Validity:<span class="small">Y or N</span></label>
	<input type="text" name="valid" value=""/><br/>
	<label>Uid:<span class="small">userid to send mail to</span></label>
	<input type="text" name="uid" value=""/><br/>
	<label>MailSubject:<span class="small">mail subject</span></label>
	<input type="text" name="mailsub" value=""/><br/>
	<label>MailAtt:<span class="small">mail attachment</span></label>
	<input type="text" name="mailatt" value=""/><br/>
	<label>Action:<span class="small">system() cmd</span></label>
	<input type="text" name="act" value=""/><br/>
	<p style="margin: 0px; text-align: center">
		<input type="button" name="sendbutton" value="send" onclick="sendPopupNotf(); return false;" /> <input type="button" value="cancel" onclick="closePopup(); return false" />
	</p>
	</form>

	<TABLE><TR style="vertical-align: top;">
	<TD style="border: none; vertical-align: top;">
	<TR>
	<TD style="border: none; vertical-align: top;">

	<fieldset><legend class="smanlegend">Postboard status</legend>
		<div class="status-container">
			<div class="schedstatus">$postboardstatus</div>
		</div>
	</fieldset>

	<fieldset><legend><b>Notifications</b></A></legend>
		<div style="background: #BBB">
			<b>$dnotfCount</b> notifications defined
		</div>
		<div class="dunotf-container">
			<div class="dunotf">
				<table class="dunotf">
				<thead><tr>
				<th style=\"width:12px\" class="tdlock">&nbsp;
				<th class="tdlock">Event
				</tr></thead>
				<tbody>
				$dunotf
				</tbody>
				</table>
			</div>
		</div>
		<div class="dnotf-container">
			<div class="dnotf">
				<table class="dnotf">
				<thead><tr><th style=\"width:12px\"><a href="#POSTBOARD" onclick="openPopupNotf(-1);return false"><img title="define new notification" src="/icons/modif.png"></a>
				<th style=\"width:12px\" class="tdlock">&nbsp;
				<th>Event<th>V<th>Uid<th>Mail<br>Subject<th>Mail<br>Attachm.<th>Action
				</tr></thead>
				<tbody>
				$dnotf
				</tbody>
				</table>
			</div>
		</div>
	</fieldset>

	</TABLE>
</div>
</div>
EOPART1

print <<"EOPART2";
<BR>
<A NAME="AUTH"></A>
<div class="drawer">
<div class="drawerh2" >&nbsp;<img src="/icons/drawer.png"  onClick="toggledrawer('\#authID');">
Authorizations&nbsp;$go2top
</div>
<div id="authID">
	<div id="authMsg" style="font-weight: bold; color: $authMsgColor">&bull; $authMsg</div><br/>
	<form id="overlay_form_auth" class="overlay_form" style="display:none">
	<input type="hidden" name="action" value="">
	<input type="hidden" name="tbl" value="">
	<input type="hidden" name="OLDuid" value="">
	<input type="hidden" name="OLDres" value="">
	<p><b><i>Edit authorization</i></b></p>
	<label>Uid:<span class="small">Uid or Gid</span></label>
	<input type="text" name="uid" value=""/><br/>
	<label>Resource:<span class="small">resource name</span></label>
	<input type="text" name="res" value=""/><br/>
	<label>Authorization:<span class="small">1=Read,2=Edit,4=Adm</span></label>
	<input type="text" name="auth" value=""/><br/>
	<p style="margin: 0px; text-align: center">
		<input type="button" name="sendbutton" value="send" onclick="sendPopupAuth(); return false;" /> <input type="button" value="cancel" onclick="closePopup(); return false" />
	</p>
	</form>
EOPART2
	print "<TABLE><TR style=\"vertical-align: top;\">";
	print "<TD style=\"border: none; vertical-align: top;\">";
	for my $i (qw(view proc form)) {
		print <<"EOAUTH1"
		<fieldset style="float:left"><legend><b>$i</b></A></legend>
		<div class="dauth-container" style="float: left">
			<div class="dauth">
				<table class="dauth">
				<thead><tr><th style=\"width:12px\"><a href="#AUTH" onclick="openPopupAuth('$i',-1);return false"><img title="define new authorization" src="/icons/modif.png"></a>
				<th style=\"width:12px\" class="tdlock">&nbsp;
				<th>Uid<th>Rname<th>Auth
				</tr></thead>
				<tbody>
				$TA{$i}{dauth}
				</tbody>
				</table>
			</div>
		</div>
		</fieldset>
EOAUTH1
	}
	print "</TR></TABLE>";

	print "<TABLE><TR style=\"vertical-align: top;\">";
	print "<TD style=\"border: none; vertical-align: top;\">";
	for my $i (qw(wiki misc)) {
		print <<"EOAUTH2"
		<fieldset style="float:left"><legend><b>$i</b></A></legend>
		<div class="dauth-container" style="float: left">
			<div class="dauth">
				<table class="dauth">
				<thead><tr><th style=\"width:12px\"><a href="#AUTH" onclick="openPopupAuth('$i',-1);return false"><img title="define new authorization" src="/icons/modif.png"></a>
				<th style=\"width:12px\" class="tdlock">&nbsp;
				<th>Uid<th>Rname<th>Auth
				</tr></thead>
				<tbody>
				$TA{$i}{dauth}
				</tbody>
				</table>
			</div>
		</div>
		</fieldset>
EOAUTH2
}
print "</TR></TABLE>";
print "</div>";
print "</div>";

# ---- That's all folks: end html 
print "<br>\n</body>\n</html>\n";
exit;

# ---- helper: execute the non-select sql statement in $_[0] 
# ------------------------------------------------------------------------------
sub dbu {
	$lastDBIerrstr = "";
	my $dbh = DBI->connect("dbi:SQLite:dbname=$WEBOBS{SQL_DB_USERS}", '', '') or die "$DBI::errstr" ;
	my $rv = $dbh->do($_[0]);
	$rv = 0 if ($rv == 0E0); 
	$lastDBIerrstr = sprintf("(%d row%s) %s",$rv,($rv<=1)?"":"s",$DBI::errstr);
	$dbh->disconnect();
	return $rv;
}

# ---- helper: execute the sql unit of work made up of $_[0]...$_[3] sql statements
# ------------------------------------------------------------------------------
sub dbuow {
	$lastDBIerrstr = "";
	my $rv = 0;
	my $dbh = DBI->connect("dbi:SQLite:dbname=$WEBOBS{SQL_DB_USERS}", '', '',{AutoCommit => 0, RaiseError => 1,}) or die "$DBI::errstr" ;
	eval {
		$dbh->do($_[0]);
		$dbh->do($_[1]);
		$rv = $dbh->do($_[2]);
		$dbh->do($_[3]);
		$rv = 0 if ($rv == 0E0);
		$lastDBIerrstr = sprintf("(%d row%s) %s",$rv,($rv<=1)?"":"s",$DBI::errstr);
		$dbh->commit();
	};
	if ($@) {
        $rv = 0; 
		$lastDBIerrstr = sprintf("(0 row) %s",$@);
		$dbh->rollback();
	}
	$dbh->disconnect();
	return $rv;
}

__END__

=pod

=head1 AUTHOR(S)

Didier Lafon, François Beauducel

=head1 COPYRIGHT

Webobs - 2012-2019 - Institut de Physique du Globe Paris

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

