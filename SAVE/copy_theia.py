import sqlite3


# Table observed_properties
conn1 = sqlite3.connect('WEBOBSMETA_old.db')
conn2 = sqlite3.connect('WEBOBSMETA_new.db')

cur1 = conn1.cursor()
cur2 = conn2.cursor()

cur1.execute("SELECT NAME, UNIT, THEIACATEGORIES FROM observed_properties")
rows = cur1.fetchall()

for row in rows:
    N, U, T = row
    cur2.execute("UPDATE observed_properties SET THEIACATEGORIES = ? WHERE NAME = ? AND UNIT = ?", (T, N, U))

conn2.commit()
conn1.close()
conn2.close()


# Table observations
conn1 = sqlite3.connect('WEBOBSMETA_old.db')
conn2 = sqlite3.connect('WEBOBSMETA_new.db')

cur1 = conn1.cursor()
cur2 = conn2.cursor()

cur1.execute("SELECT PROCESSINGLEVEL, OBSERVEDPROPERTY FROM observations")
rows = cur1.fetchall()

for row in rows:
    P, O = row
    cur2.execute("UPDATE observations SET PROCESSINGLEVEL = ? WHERE OBSERVEDPROPERTY = ?", (P, O))

conn2.commit()
conn1.close()
conn2.close()
