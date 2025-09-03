CC = g++
CFLAGS =  -w -g
# CFLAGS = -Wall -w -g -fpermissive
LDFLAGS = 
INCFLAGS = 
LIBDIRFLAGS = 

all :   DOWNFLOW.o
	$(CC) $(CFLAGS) $(INCFLAGS) $(LIBDIRFLAGS) DOWNFLOW.o -o DOWNFLOW $(LDFLAGS)

DOWNFLOW.o : DOWNFLOW.cpp
	$(CC) $(CFLAGS) $(INCFLAGS) -c DOWNFLOW.cpp 
        
