-- make sure table users has unique UID + unique LOGIN
-- and has a validity column (ATT: validity is forced to 'Y')
BEGIN TRANSACTION;
ALTER TABLE users RENAME TO oldusers;
create table users (UID text NOT NULL UNIQUE, FULLNAME text NOT NULL, LOGIN text NOT NULL UNIQUE, EMAIL text, VALIDITY text NOT NULL default 'Y');
INSERT INTO users SELECT UID,FULLNAME,LOGIN,EMAIL,'Y' FROM oldusers;
DROP TABLE oldusers;
CREATE TRIGGER deluid after delete on users for each row
begin 
  delete from groups where uid = OLD.uid; 
  delete from authviews where uid = OLD.uid; 
  delete from authprocs where uid = OLD.uid; 
  delete from authforms where uid = OLD.uid; 
  delete from authwikis where uid = OLD.uid; 
  delete from authmisc  where uid = OLD.uid; 
  delete from notifications where uid = OLD.uid; 
end;
COMMIT;

