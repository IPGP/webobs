-- 'ids' table is identical in all DBForms

DROP TABLE IF EXISTS ids;
CREATE TABLE ids (id       INTEGER PRIMARY KEY AUTOINCREMENT,
                  ts1      TEXT,
                  ts2      TEXT,
                  node     TEXT NOT NULL,
                  comment  TEXT,
                  hidden   TEXT DEFAULT 'n',
                  tsupd    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                  userupd  TEXT NOT NULL DEFAULT '!'
				 );

-- 'data' table is specific to a DBForm, except column 'ID' is identical in all DBForms

DROP TABLE IF EXISTS data;
CREATE TABLE data (id    INTEGER UNIQUE REFERENCES ids(id) ON DELETE CASCADE ON UPDATE CASCADE,
				   val1  TEXT, 
				   val2  INTEGER  CHECK(val2 > 10),
				   val3  REAL     CHECK (val3 BETWEEN 0.0 AND 1.0)
				  );

