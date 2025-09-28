SRCD=./src
OBJD=./build
OBJ=$(OBJD)/taggy.o $(OBJD)/guile_db.so $(OBJD)/guile_db.o
BINNAME=taggy

CC=gcc
GC=guild

CFLAGS=`pkg-config guile-3.0 --cflags` -Wall -std=c99 -c
GFLAGS=compile
LIBGUILE_FLAG=`pkg-config --cflags guile-3.0` -c -fPIC

all : $(OBJ)
	$(CC) -o $(OBJD)/taggy $(OBJD)/taggy.o `pkg-config guile-3.0 --libs`

$(OBJD)/taggy.o : $(SRCD)/taggy.c
	$(CC) $(CFLAGS) -o $(OBJD)/taggy.o $(SRCD)/taggy.c

$(OBJD)/taggy.go : $(SRCD)/taggy.scm
	$(GC) $(GFLAGS) -o $(OBJD)/taggy.go $(SRCD)/taggy.scm

$(OBJD)/guile_db.so : $(OBJD)/guile_db.o
	$(CC) -shared -o $(OBJD)/guile_db.so $(OBJD)/guile_db.o -lsqlite3

$(OBJD)/guile_db.o : $(SRCD)/guile_db.c
	$(CC) $(LIBGUILE_FLAG) -o $(OBJD)/guile_db.o $(SRCD)/guile_db.c

.PHONY : clean
clean :
	rm $(OBJD)/taggy $(OBJ)
