-- from 1.5.0 
-- now jid is text, maxinstances is gone
BEGIN TRANSACTION;
ALTER TABLE jobs RENAME TO oldjobs;
CREATE TABLE jobs( 
	JID            text NOT NULL primary key,
	VALIDITY       text not null default 'Y',
	RES            text not null default '',            
	XEQ1           text not null default '',
	XEQ2           text not null default '',
	XEQ3           text not null default '',
	RUNINTERVAL    integer NOT NULL,
	MAXSYSLOAD     real NOT NULL default 0.7,
	LOGPATH        text,
	LASTSTRTS      integer not null default 0
);
INSERT INTO jobs (JID,VALIDITY,RES,XEQ1,XEQ2,XEQ3,RUNINTERVAL,MAXSYSLOAD,LOGPATH,LASTSTRTS)
SELECT JID,VALIDITY,RES,XEQ1,XEQ2,XEQ3,RUNINTERVAL,MAXSYSLOAD,LOGPATH,LASTSTRTS FROM oldjobs;
DROP TABLE oldjobs;

ALTER TABLE runs RENAME TO oldruns;
CREATE TABLE runs( 
	JID            text NOT NULL,
	KID            integer,
	ORG            text,
	STARTTS        integer NOT NULL default 0,
	ENDTS          integer NOT NULL default 0,
	CMD            text,
	STDPATH        text,
	RC             integer,
	RCMSG          text
);
INSERT INTO runs (JID,KID,ORG,STARTTS,ENDTS,CMD,STDPATH,RC,RCMSG)
SELECT JID,KID,ORG,STARTTS,ENDTS,CMD,STDPATH,RC,RCMSG FROM oldruns;
DROP TABLE oldruns;
COMMIT;

