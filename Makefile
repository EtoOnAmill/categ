SRCD=./src
OBJD=./build
OBJ=$(OBJD)/categ.o $(OBJD)/guile_db.so $(OBJD)/guile_db.o
BINNAME=categ

CC=gcc
GC=guild

CFLAGS=`pkg-config guile-3.0 --cflags` -Wall -std=c99 -c
GFLAGS=compile
LIBGUILE_FLAG=`pkg-config --cflags guile-3.0` -c -fPIC

all : $(OBJ)
	$(CC) -o $(OBJD)/categ $(OBJD)/categ.o `pkg-config guile-3.0 --libs`

$(OBJD)/categ.o : $(SRCD)/categ.c
	$(CC) $(CFLAGS) -o $(OBJD)/categ.o $(SRCD)/categ.c

$(OBJD)/categ.go : $(SRCD)/categ.scm
	$(GC) $(GFLAGS) -o $(OBJD)/categ.go $(SRCD)/categ.scm

$(OBJD)/guile_db.so : $(OBJD)/guile_db.o
	$(CC) -shared -o $(OBJD)/guile_db.so $(OBJD)/guile_db.o -lsqlite3

$(OBJD)/guile_db.o : $(SRCD)/guile_db.c
	$(CC) $(LIBGUILE_FLAG) -o $(OBJD)/guile_db.o $(SRCD)/guile_db.c

.PHONY : clean
clean :
	rm $(OBJD)/categ $(OBJ)
