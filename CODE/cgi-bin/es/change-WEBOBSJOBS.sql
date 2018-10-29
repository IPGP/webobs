-- once was actual changes to WEBOBSJOBS.db
-- from 1.2.+  to  1.2.3

-- rename column LASTRUNTS in 'jobs' table
BEGIN TRANSACTION;
ALTER TABLE jobs RENAME TO oldjobs;
CREATE TABLE jobs( 
	JID            integer NOT NULL primary key autoincrement,
	VALIDITY       text not null default 'Y',
	RES            text not null default '',            
	XEQ1           text not null default '',
	XEQ2           text not null default '',
	XEQ3           text not null default '',
	RUNINTERVAL    integer NOT NULL,
	MAXINSTANCES   integer NOT NULL default 0,
	MAXSYSLOAD     real NOT NULL default 0.7,
	LOGPATH        text,
	LASTSTRTS      integer not null default 0
);
INSERT INTO jobs (JID,VALIDITY,RES,XEQ1,XEQ2,XEQ3,RUNINTERVAL,MAXINSTANCES,MAXSYSLOAD,LOGPATH,LASTSTRTS)
SELECT JID,VALIDITY,'',LAUNCHER,ROUTINE,ARGS,RUNINTERVAL,MAXINSTANCES,MAXSYSLOAD,LOGPATH,LASTSTRTS FROM oldjobs;
DROP TABLE oldjobs;
COMMIT;

