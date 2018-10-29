-- once was actual changes to WEBOBSUSERS.db
-- from 1.4.5 
-- rename column MAILID in 'notifications' table
BEGIN TRANSACTION;
ALTER TABLE notifications RENAME TO oldnotifications;
create table notifications (EVENT text NOT NULL, 
                            VALIDITY NOT NULL default 'Y', 
							UID text default '-', 
							MAILSUBJECT text default '-', 
							MAILATTACH text default '-', 
							ACTION text default '-' ) ;
INSERT INTO notifications (EVENT,VALIDITY,UID,MAILSUBJECT,MAILATTACH,ACTION)
SELECT EVENT,VALIDITY,MAILID,MAILSUBJECT,MAILATTACH,ACTION FROM oldnotifications;
DROP TABLE oldnotifications;
COMMIT;

