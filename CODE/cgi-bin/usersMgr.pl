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

=item B<uid=>, B<gid=>, B<fullname=>, B<login=>, B<email=>, B<event=>, B<valid=>, B<enddate>, B<comment=>, B<mailsub=>, B<mailatt=>, B<act=>, B<res=>, B<auth=>

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
use Try::Tiny;
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
my $db_rows;
my $buildTS = strftime("%Y-%m-%d %H:%M:%S %z",localtime(int(time())));
my $today = strftime("%Y-%m-%d",localtime(int(time())));
my $userMsg="$buildTS ";
my $userMsgColor='black';
my $notfMsg="$buildTS ";
my $notfMsgColor='black';
my $authMsg="$buildTS ";
my $authMsgColor='black';
my $refMsg = my $refMsgColor = "";

# ---- special functions only for the WebObs Owner
my $isWO = WebObs::Users::clientIsWO;

# ---- any reasons why we couldn't go on ?
# ----------------------------------------
if ( ! WebObs::Users::clientHasAdm(type=>"authmisc",name=>"users")) {
    die "You are not authorized." ;
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
$QryParm->{'valid'}     ||= "N";
$QryParm->{'enddate'}   ||= "";
$QryParm->{'comment'}   ||= "";
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
        $q = "insert into $WEBOBS{SQL_TABLE_USERS} values(\'$QryParm->{'uid'}\',\'$QryParm->{'fullname'}\',";
        $q .= "\'$QryParm->{'login'}\',\'$QryParm->{'email'}\',\'$QryParm->{'valid'}\',\'$QryParm->{'enddate'}\',\'$QryParm->{'comment'}\')";
        $refMsg = \$userMsg; $refMsgColor = \$userMsgColor;
    }
    elsif ($QryParm->{'tbl'} eq "group") {
        $q = "insert into $WEBOBS{SQL_TABLE_GROUPS} values(\'$QryParm->{'gid'}\',\'$QryParm->{'uid'}\')";
        $refMsg = \$userMsg; $refMsgColor = \$userMsgColor;
    }
    elsif ($QryParm->{'tbl'} eq "notification") {
        $q = "insert into $WEBOBS{SQL_TABLE_NOTIFICATIONS} values(\'$QryParm->{'event'}\',\'$QryParm->{'valid'}\',";
        $q .= "\'$QryParm->{'uid'}\',\'$QryParm->{'mailsub'}\',\'$QryParm->{'mailatt'}\',\'$QryParm->{'act'}\')";
        $refMsg = \$notfMsg; $refMsgColor = \$notfMsgColor;
    }
    elsif ($authtable ne "") {
        $q = "insert into $authtable values(\'$QryParm->{'uid'}\',\'$QryParm->{'res'}\',\'$QryParm->{'auth'}\')";
        $q = "" if ( $QryParm->{'uid'} eq '!' && !$isWO );
        $refMsg = \$authMsg; $refMsgColor = \$authMsgColor;
    } else { die "$QryParm->{'action'} for unknown table"; }

    my $err = execute_queries($WEBOBS{SQL_DB_USERS}, $q);
    if ($err) {
        $$refMsg .= " failed to insert new $QryParm->{'tbl'} ($err) ";
        $$refMsgColor = "red";
    } else {
        $$refMsg .= " successfully inserted new $QryParm->{'tbl'} ";
        $$refMsgColor = "green" if ($$refMsgColor ne "red");
    }
}

# ---- process (execute) sql update a row of table 'tbl'
# ----------------------------------------------------------------------------
if ($QryParm->{'action'} eq 'update') {

    # query-string must contain all required DB columns values for an sql insert
    my $q='';
    if ($QryParm->{'tbl'} eq "user") {
        $q = "update $WEBOBS{SQL_TABLE_USERS} set UID=\'$QryParm->{'uid'}\',";
        $q .= " FULLNAME=\'$QryParm->{'fullname'}\', LOGIN=\'$QryParm->{'login'}\',";
        $q .= " EMAIL=\'$QryParm->{'email'}\', VALIDITY=\'$QryParm->{'valid'}\',";
        $q .= " ENDDATE=\'$QryParm->{'enddate'}\', COMMENT=\'$QryParm->{'comment'}\'";
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

    my $err = execute_queries($WEBOBS{SQL_DB_USERS}, $q);
    if ($err) {
        $$refMsg .= " failed to update $QryParm->{'tbl'} ($err) ";
        $$refMsgColor = "red";
    } else {
        $$refMsg .= " successfully updated $QryParm->{'tbl'} ";
        $$refMsgColor = "green" if ($$refMsgColor ne "red" );
    }
}

# ---- process (execute) sql update table 'groups' after user insert or update
# ----------------------------------------------------------------------------
if (($QryParm->{'action'} eq 'insert' || $QryParm->{'action'} eq 'update')
    && $QryParm->{'tbl'} eq "user")
{
    my $err = set_wo_user_groups($QryParm->{'uid'},
        $cgi->multi_param('gid'));
    if ($err) {
        $userMsg .= " ‑ failed to update $WEBOBS{SQL_TABLE_GROUPS} ($err) ";
        $userMsgColor = "red";
    } else {
        $userMsg .= " ‑ $WEBOBS{SQL_TABLE_GROUPS} successfully updated ";
        $userMsgColor = "green" if ($userMsgColor ne "red");
    }

}

# ---- process (execute) sql update table 'groups'
# ----------------------------------------------------------------------------
if ($QryParm->{'action'} eq 'updgrp') {
    my $err = set_wo_group_members($QryParm->{'gid'},
        $cgi->multi_param('uid'));
    if ($err) {
        $userMsg .= " ‑ failed to update $WEBOBS{SQL_TABLE_GROUPS} ($err) ";
        $userMsgColor = "red";
    } else {
        $userMsg .= " ‑ $WEBOBS{SQL_TABLE_GROUPS} successfully updated ";
        $userMsgColor = "green" if ($userMsgColor ne "red");
    }
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

    my $err = execute_queries($WEBOBS{SQL_DB_USERS}, $q);
    if ($err) {
        $$refMsg .= " failed to delete in $QryParm->{'tbl'} ($err) ";
        $$refMsgColor = "red";
    } else {
        $$refMsg .= " successfully deleted in $QryParm->{'tbl'} ";
        $$refMsgColor = "green" if ($$refMsgColor ne "red");
    }
}

# ---- process (execute) sql delete
# ---------------------------------------------------------------------------------------
if ($QryParm->{'action'} eq 'deleteU') {
    if ($QryParm->{'tbl'} eq "group") {
        my $q = "DELETE FROM $WEBOBS{SQL_TABLE_GROUPS}"
          ." WHERE GID='$QryParm->{'gid'}'";

        my $err = execute_queries($WEBOBS{SQL_DB_USERS}, $q);
        if ($err) {
            $userMsg .= " failed to delete $QryParm->{'tbl'} ($err) ";
            $userMsgColor = "red";
        } else {
            $userMsg .= " successfully deleted $QryParm->{'tbl'} ";
            $userMsgColor = "green" if ($userMsgColor ne "red");
        }

    }
    if ($QryParm->{'tbl'} eq "notification") {
        my $q = "DELETE FROM $WEBOBS{SQL_TABLE_NOTIFICATIONS}"
          ." WHERE EVENT='$QryParm->{'event'}'";

        my $err = execute_queries($WEBOBS{SQL_DB_USERS}, $q);
        if ($err) {
            $notfMsg .= " failed to delete $QryParm->{'tbl'} ($err) ";
            $notfMsgColor = "red";
        } else {
            $notfMsg .= " successfully deleted $QryParm->{'tbl'} ";
            $notfMsgColor = "green" if ($notfMsgColor ne "red");
        }
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
<title>User Manager</title>
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
$db_rows = fetch_all($WEBOBS{SQL_DB_USERS},
    "SELECT DISTINCT(UID), FULLNAME"
      ." FROM $WEBOBS{SQL_TABLE_USERS} ORDER BY UID");
my $selusers = "";
for my $uid_name (@$db_rows) {
    my ($uid, $name) = @$uid_name;
    $selusers .= qq(<option value="$uid">$uid &ndash; $name</option>);
}

$db_rows = fetch_all($WEBOBS{SQL_DB_USERS},
    "SELECT DISTINCT(GID) FROM $WEBOBS{SQL_TABLE_GROUPS}"
      ." ORDER BY GID");
my $selgrps = "";
for my $row (@$db_rows) {
    my ($gid) = @$row;
    $selgrps .= "<option>$gid</option>";
}

# ---- build 'users' table result rows
# -----------------------------------------------------------------------------
$db_rows = fetch_all($WEBOBS{SQL_DB_USERS},
    "SELECT u.UID,FULLNAME,LOGIN,EMAIL,VALIDITY,ENDDATE,COMMENT,"
      ."group_concat(GID) AS groups"
      ." FROM $WEBOBS{SQL_TABLE_USERS} u"
      ." LEFT JOIN $WEBOBS{SQL_TABLE_GROUPS} g"
      ." ON (u.uid = g.uid)"
      ." GROUP BY u.UID ORDER BY u.UID");
my $dusers = '';
my $dusersCount = 0;
my $dusersCountValid = 0;
my $dusersId = '';

for my $row (@$db_rows) {
    my ($dusers_uid, $dusers_fullname, $dusers_login, $dusers_email,
        $dusers_validity, $dusers_enddate, $dusers_comment, $dusers_groups) = @$row;
    $dusers_groups //= '';
    $dusers_groups =~ s/,/ /g;
    $dusersCount++;
    $dusersCountValid++ if ($dusers_validity eq 'Y' && ($dusers_enddate eq '' || $dusers_enddate gt $today));
    $dusersId = "udef".$dusersCount;

# Webobs owner and visitor user row should be grayed and have no edition/deletion link
    my $tr_classes = '';
    my $edit_link = '';
    my $del_link = '';
    if ($dusers_uid eq "!" || $dusers_uid eq "?" ) {
        $tr_classes = "trlock";
    } else {
        if ($dusers_validity ne "Y" || ($dusers_enddate ne "" && $dusers_enddate lt $today)) {
            $tr_classes = "troff";
        }
        $edit_link = "<a href=\"#IDENT\" onclick=\"openPopupUser('#$dusersId');return false\">"
          ."<img title=\"edit user\" src=\"/icons/modif.png\"></a>";
        $del_link = "<a href=\"#IDENT\" onclick=\"postDeleteUser('#$dusersId');return false\">"
          ."<img title=\"delete user\" src=\"/icons/no.png\"></a>" if ($isWO);
    }

    # Build user table row (also used as input for the user edition form)
    $dusers .= <<_EOD_;
<tr id="$dusersId" class="$tr_classes">
    <td style="width: 12px" class="tdlock">$edit_link</td>
    <td style="width: 12px" class="tdlock">$del_link</td>
    <td class="user-uid">$dusers_uid</td>
    <td class="user-fullname" nowrap>$dusers_fullname</td>
    <td class="user-login">$dusers_login</td>
    <td class="user-email">$dusers_email</td>
    <td class="user-groups">$dusers_groups</td>
    <td class="user-validity">$dusers_validity</td>
    <td class="user-enddate">$dusers_enddate</td>
    <td class="user-comment">$dusers_comment</td>
</tr>
_EOD_
}

# ---- build 'unique groups' table result rows
# -----------------------------------------------------------------------------
$db_rows = fetch_all($WEBOBS{SQL_DB_USERS},
    "SELECT DISTINCT(GID) FROM $WEBOBS{SQL_TABLE_GROUPS}"
      ." ORDER BY GID");
my $dugrps = '';
my $dugrpsCount = 0;
my $dugrpsId = '';

for my $row (@$db_rows) {
    my ($gid) = @$row;
    $dugrpsCount++;
    $dugrpsId="nudef".$dugrpsCount;
    $dugrps .= <<_EOD_
    <tr id="$dugrpsId">
    <td style="width:12px" class="tdlock">
        <a href="#IDENT" onclick="postDeleteUGroup('#$dugrpsId');return false">
            <img title="delete group" src="/icons/no.png">
        </a>
    </td>
    <td class="tdlock">$gid</td>
    </tr>
_EOD_
}

# ---- build S'groups' table result rows
# -----------------------------------------------------------------------------
$db_rows = fetch_all($WEBOBS{SQL_DB_USERS},
    "SELECT GID,GROUP_CONCAT(UID) AS UIDS"
      ." FROM $WEBOBS{SQL_TABLE_GROUPS}"
      ." GROUP BY GID ORDER BY GID");
my $Sdgrps = '';
my $SdgrpsCount = 0;
my $SdgrpsId = '';

for my $row (@$db_rows) {
    my ($Sdgrps_gid, $Sdgrps_uids) = @$row;
    $Sdgrps_uids =~ s/,/ /g;
    $SdgrpsCount++;
    $SdgrpsId="gdef".$SdgrpsCount;

    $Sdgrps .= <<_EOD_;
<tr id="$SdgrpsId">
    <td style="width:12px" class="tdlock">
        <a href="#IDENT" onclick="openPopupGroup('#$SdgrpsId');return false">
            <img title="edit grp" src="/icons/modif.png">
        </a>
    </td>
    <td style="width:12px" class="tdlock">
        <a href="#IDENT" onclick="postDeleteUGroup('#$SdgrpsId');return false">
            <img title="delete group" src="/icons/no.png">
        </a>
    </td>
    <td class="group-gid">$Sdgrps_gid</td>
    <td class="group-uids">$Sdgrps_uids</td>
</tr>
_EOD_
}

# ---- build 'unique evnt notifications' table result rows
# -----------------------------------------------------------------------------
$db_rows = fetch_all($WEBOBS{SQL_DB_USERS},
    "SELECT DISTINCT(EVENT)"
      ." FROM $WEBOBS{SQL_TABLE_NOTIFICATIONS}"
      ." ORDER BY EVENT");

my $dunotf = '';
my $dunotfCount = 0;
my $dunotfId = '';

for my $row (@$db_rows) {
    my ($event) = @$row;
    $dunotfCount++;
    $dunotfId="nudef".$dunotfCount;
    $dunotf .= <<_EOD_;
<tr id="$dunotfId">
    <td style="width:12px" class="tdlock">
        <a href="#POSTBOARD" onclick="postDeleteUNotf('#$dunotfId');return false">
            <img title="delete group" src="/icons/no.png">
        </a>
    </td>
    <td class="tdlock unotif-event">$event</td>
</tr>
_EOD_
}

# ---- build 'notifications' table result rows
# -----------------------------------------------------------------------------
$db_rows = fetch_all($WEBOBS{SQL_DB_USERS},
    "SELECT EVENT,VALIDITY,UID,MAILSUBJECT,MAILATTACH,ACTION"
      ." FROM $WEBOBS{SQL_TABLE_NOTIFICATIONS}"
      ." ORDER BY 1");
my $dnotf = '';
my $dnotfCount = 0;
my $dnotfId = '';

for my $row (@$db_rows) {
    my ($dnotf_event, $dnotf_valid, $dnotf_mail, $dnotf_mailsubj,
        $dnotf_mailatt, $dnotf_act) = @$row;

    $dnotfCount++;
    $dnotfId="ndef".$dnotfCount;
    $dnotf .= <<_EOD_;
<tr id="$dnotfId">
    <td style="width:12px" class="tdlock">
        <a href="#POSTBOARD" onclick="openPopupNotf('#$dnotfId');return false">
            <img title="edit grp" src="/icons/modif.png">
        </a>
    </td>
    <td style="width:12px" class="tdlock">
        <a href="#POSTBOARD" onclick="postDeleteNotf('#$dnotfId');return false">
            <img title="delete notification" src="/icons/no.png">
        </a>
    </td>
    <td class="notif-event">$dnotf_event</td>
    <td class="notif-validity">$dnotf_valid</td>
    <td class="notif-emailuid">$dnotf_mail</td>
    <td class="notif-emailsubj">$dnotf_mailsubj</td>
    <td class="notif-emailattach">$dnotf_mailatt</td>
    <td class="notif-action">$dnotf_act</td>
</tr>
_EOD_
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
    my %auth_tablenames = (
        "proc" => $WEBOBS{SQL_TABLE_AUTHPROCS},
        "view" => $WEBOBS{SQL_TABLE_AUTHVIEWS},
        "form" => $WEBOBS{SQL_TABLE_AUTHFORMS},
        "wiki" => $WEBOBS{SQL_TABLE_AUTHWIKIS},
        "misc" => $WEBOBS{SQL_TABLE_AUTHMISC},
      );
    $db_rows = fetch_all($WEBOBS{SQL_DB_USERS},
        "SELECT UID,RESOURCE,AUTH FROM $auth_tablenames{$an}"
          ." ORDER BY UID,RESOURCE");
    $TA{$an}{dauth} = '';
    $TA{$an}{dauthCount} = 0;

    for my $row (@$db_rows) {
        my ($dauth_uid, $dauth_res, $dauth_auth) = @$row;

        my $td_modif_auth = '';
        my $td_delete_auth = '';
        $TA{$an}{dauthCount}++;
        my $dauthId="adef$an".$TA{$an}{dauthCount};
        if ($dauth_uid ne '!' || $isWO) {
            $td_modif_auth = "<a href=\"#AUTH\" onclick=\"openPopupAuth('$an', '#$dauthId');return false\">"
              ."<img title=\"edit grp\" src=\"/icons/modif.png\"></a>";
            $td_delete_auth = "<a href=\"#AUTH\" onclick=\"postDeleteAuth('$an', '#$dauthId');return false\">"
              ."<img title=\"delete autorisation\" src=\"/icons/no.png\"></a>";
        }
        $TA{$an}{dauth} .= <<_EOD_;
<tr id="$dauthId">
    <td style="width:12px" class="tdlock">$td_modif_auth</td>
    <td style="width:12px" class="tdlock">$td_delete_auth</td>
    <td class="auth-uid">$dauth_uid</td>
    <td class="auth-res">$dauth_res</td>
    <td class="auth-auth">$dauth_auth</td>
</tr>
_EOD_
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
<h1>WebObs User Manager</h1>

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
    <input type="hidden" name="isWO" value="$isWO">
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
    <select name="gid" id="gid" size="5" multiple>$selgrps</select><br/>
    <label for="valid-user">Validity:
        <span class="small">check to activate account</span></label>
    <input type="checkbox" id="valid-user" name="valid" value="Y"/>
    <label for="end-date">End Date:
        <span class="small">YYYY-MM-DD</span></label>
    <input type="text" name="enddate" maxlength="10" value="" style="width: 100px"/><br/>
    <label for="comment">Comment:<span class="small">free string</span></label>
    <input type="text" name="comment" value=""/><br/>
    <p style="margin: 0px; text-align: center">
        <input type="button" name="sendbutton" value="send" onclick="sendPopupUser(); return false;" />
        <input type="button" value="cancel" onclick="closePopup(); return false" />
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
        <input type="button" name="sendbutton" value="send" onclick="sendPopupGroup(); return false;" />
        <input type="button" value="cancel" onclick="closePopup(); return false" />
    </p>
    </form>

    <fieldset id="users-field"><legend><b>Users</b></A></legend>
        <div style="background: #BBB">
            <b>$dusersCountValid</b>/$dusersCount users valid/defined
        </div>
        <div class="dusers-container">
            <div class="dusers">
                <table class="dusers">
                <thead>
                <tr>
                    <th style=\"width:12px\"><a href="#IDENT" onclick="openPopupUser(); return false">
                        <img title="define a new user" src="/icons/modif.png"></a></th>
                    <th style=\"width:12px\" class="tdlock">&nbsp;</th>
                    <th>Uid</th>
                    <th>Name</th>
                    <th>Login</th>
                    <th>Email</th>
                    <th>Groups</th>
                    <th>Valid</th>
                    <th>Until</th>
                    <th>Comment</th>
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
                <thead><tr><th style=\"width:12px\"><a href="#IDENT" onclick="openPopupGroup();return false"><img title="define new group/user" src="/icons/modif.png"></a>
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
    <label for="valid-notif">Validity:
        <span class="small">check to activate notification</span></label>
    <input type="checkbox" id="valid-notif" name="valid" value="Y"/><br/>
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
                <thead><tr><th style=\"width:12px\"><a href="#POSTBOARD" onclick="openPopupNotf();return false"><img title="define new notification" src="/icons/modif.png"></a>
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
                <thead><tr><th style=\"width:12px\"><a href="#AUTH" onclick="openPopupAuth('$i');return false"><img title="define new authorization" src="/icons/modif.png"></a>
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
                <thead><tr><th style=\"width:12px\"><a href="#AUTH" onclick="openPopupAuth('$i');return false"><img title="define new authorization" src="/icons/modif.png"></a>
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

# Connect to the database and return the handler
# ------------------------------------------------------------------------------
sub db_connect {

    # Open a connection to a SQLite database using RaiseError.
    #
    # Usage example:
    #   my $dbh = db_connect($WEBOBS{SQL_DB_POSTBOARD})
    #     || die "Error connecting to $dbname: $DBI::errstr";
    #
    my $dbname = shift;
    my $opts = shift || {};
    my %default_options = (
        'AutoCommit' => 1,
        'PrintError' => 1,
        'RaiseError' => 1,
      );
    my %options = (%default_options, %$opts);
    return DBI->connect("dbi:SQLite:$dbname", "", "", \%options);
}

# Fetch and return all results of a select statement
# -----------------------------------------------------------------------------
sub fetch_all {
    #
    # Connect to a database, run the given SQL statement, and
    # return a reference to an array of array references.
    #
    my $dbname = shift;
    my $query = shift;

    my $dbh = db_connect($dbname);
    if (not $dbh) {
        logit("Error connecting to $dbname: $DBI::errstr");
        return;
    }

    # Will raise an error if anything goes wrong
    my $ref = $dbh->selectall_arrayref($query);

    $dbh->disconnect()
      or warn "Got warning while disconnecting from $dbname: ".$dbh->errstr;
    return $ref;
}

# Atomatically execute a list of queries
# -----------------------------------------------------------------------------
sub execute_queries {
    #
    # Connect to a database and atomically execute the given SQL
    # statements, using DBI->do().
    # Log error or warning to stderr/logs if anything goes wrong.
    # Return an empty string on success, the error message otherwise.
    #
    my $dbname = shift;
    my @queries = @_;
    my $err_msg = "";

    my $dbh = db_connect($dbname, {'AutoCommit' => 0});
    if (not $dbh) {
        logit("Error connecting to $dbname: $DBI::errstr");
        return $DBI::errstr;
    }
    try {
        for my $q (@queries) {
            $dbh->do($q);
        }
    } catch {

        # Catch errors to show them to the user
        # (Try::Tiny sets $_ to the exception message)
        $err_msg = $_;

        # Log the queries for information (the error is already logged by DBI,
        # as we use the PrintError option).
        warn "Error while executing queries '".join("; ", @queries)
          ." (rolling back)";
        eval { $dbh->rollback() };  # rollback might fail
    };
    if (not $err_msg) {
        $dbh->commit();
    }
    $dbh->disconnect()
      or CORE::warn "Got warning while disconnecting from $dbname: "
      .$dbh->errstr;

    return $err_msg;
}

# ------------------------------------------------------------------------------
# Create or update the members of a (potentially new) group
# Return the empty string on success, or the DBI error message if an error
# occured and the gropu members could not be updated.
#
sub set_wo_group_members {
    my $gid = shift;  # group GID
    my @uids = @_;    # UIDs of group members

    # Insert members of the group
    my @values = map { "('$gid', '$_')" } @uids;
    my $insert_stm = "INSERT OR REPLACE INTO $WEBOBS{SQL_TABLE_GROUPS} VALUES "
      .join(',', @values);

    # Delete any removed members from the group. This is done _after_ we have
    # inserted new members to prevent the group from having no member for a
    # short while, as the SQL trigger on the 'groups' table would remove the
    # group entries in 'auth*' and 'notifications' tables.
    my $delete_stm = "DELETE FROM $WEBOBS{SQL_TABLE_GROUPS}"
      ." WHERE GID='$gid' AND UID NOT IN ("
      .join(",", map { "'$_'" } @uids).")";

    return execute_queries($WEBOBS{SQL_DB_USERS}, $insert_stm, $delete_stm);
}

# ------------------------------------------------------------------------------
# Update the group memberships for a given user
# Return the empty string on success, or the DBI error message if an error
# occured and the memberships could not be updated.
#
sub set_wo_user_groups {
    my $uid = shift;  # user UID
    my @gids = @_;    # GIDs of groups the user is a member of

    # Insert the user in its groups
    my @values = map { "('$_', '$uid')" } @gids;
    my $insert_stm = "INSERT OR REPLACE INTO $WEBOBS{SQL_TABLE_GROUPS} VALUES "
      .join(',', @values);

    # Delete any group membership for the user. This is done _after_ we have
    # inserted new memberships to prevent any group from having no member for
    # a short while, as the SQL trigger on the 'groups' table would remove the
    # group entries in 'auth*' and 'notifications' tables.
    my $delete_stm = "DELETE FROM $WEBOBS{SQL_TABLE_GROUPS} "
      ."WHERE UID='$uid' AND GID NOT IN ("
      .join(",", map { "'$_'" } @gids).")";

    return execute_queries($WEBOBS{SQL_DB_USERS}, $insert_stm, $delete_stm);
}

__END__

=pod

=head1 AUTHOR(S)

Didier Lafon, François Beauducel

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
