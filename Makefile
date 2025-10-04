SRCD=./src
OBJD=./build
OBJ=$(OBJD)/categ.o $(OBJD)/guile_db.o #$(OBJD)/guile_db.so
BINNAME=categ

CC=gcc
GC=guild

CFLAGS=`pkg-config guile-3.0 --cflags` --debug -Wall -std=c99 -c
GFLAGS=compile
LIBGUILE_FLAG=`pkg-config --cflags guile-3.0` -c -fPIC

all : $(OBJ)
	$(CC) -o $(OBJD)/categ $(OBJ) `pkg-config guile-3.0 --libs` -lsqlite3

$(OBJD)/categ.o : $(OBJD)/guile_db.o $(SRCD)/categ.c
	$(CC) $(CFLAGS) -o $(OBJD)/categ.o $(SRCD)/categ.c

$(OBJD)/guile_db.o : $(SRCD)/guile_db.c
	$(CC) $(CFLAGS) -o $(OBJD)/guile_db.o $(SRCD)/guile_db.c

#$(OBJD)/guile_db.so : $(OBJD)/guile_db.o
	#$(CC) -shared -o $(OBJD)/guile_db.so $(OBJD)/guile_db.o -lsqlite3

$(OBJD)/categ.go : $(SRCD)/categ.scm
	$(GC) $(GFLAGS) -o $(OBJD)/categ.go $(SRCD)/categ.scm

.PHONY : clean
clean :
	rm $(OBJD)/categ $(OBJ)
