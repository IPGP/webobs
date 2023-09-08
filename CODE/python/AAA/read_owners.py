#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sqlite3
import pandas as pd
import csv

try:

    # Connect to DB and create a cursor
    sqliteConnection = sqlite3.connect('/home/lucas/webobs/SETUP/WEBOBSOWNER.db')
    cursor = sqliteConnection.cursor()
    print('DB Init')
    
    # Write a query and execute it with cursor
    query = 'pragma table_info("producer");'
    cursor.execute(query)
    
    # Fetch and output result
    result = cursor.fetchall()
    #print(result)
    
    # field names
    fields = []
    for i in range(1, len(result)):
        fields.append(result[i][1])
    #print(fields)
    
    query = 'select * from producer'
    cursor.execute(query)
    result = cursor.fetchall()
    #print(result)
    
    # data rows of csv file
    rows = [[]]
    for i in range(1,len(result[0])):
        if '_' in result[0][i]:
            lst_result = result[0][i].replace('_,','_,\n')
            rows[0].append(lst_result)
        else:
            rows[0].append(result[0][i])
    #print(rows)
    
    # Close the cursor
    cursor.close()
    
# Handle errors
except sqlite3.Error as error:
    print('Error occured - ', error)
    
# Close DB Connection irrespective of success
# or failure

finally:

    if sqliteConnection:
        sqliteConnection.close()
        print('SQLite Connection closed')

# name of csv file
filename = 'producer.csv'

# creating a DataFrame with pandas
df = pd.DataFrame(rows, columns=fields)

df.to_csv('producer.csv', index=False, sep=';')

#print(df)
print(fields)
print(rows)
