SRCD=./src
OBJD=./build
OBJ=$(OBJD)/taggy.o
BINNAME=taggy

CC=gcc
GC=guild

CFLAGS=`pkg-config guile-3.0 --cflags` -Wall -std=c99 -c -fPIC -o
GFLAGS=compile -o
LIBGUILE_FLAG=`pkg-config --cflags guile-3.0` -shared -o $(OBJD)/guile_db.so -fPIC


all : $(OBJ)
	$(CC) `pkg-config guile-3.0 --libs` -o $(OBJD)/taggy $(OBJ)

$(OBJD)/taggy.o : $(SRCD)/taggy.c
	$(CC) $(CFLAGS) $(OBJD)/taggy.o $(SRCD)/taggy.c

$(OBJD)/taggy.go : $(SRCD)/taggy.scm
	$(GC) $(GFLAGS) $(OBJD)/taggy.go $(SRCD)/taggy.scm

$(OBJD)/guile_db.so : $(SRCD)/guile_db.c
	$(CC) $(LIBGUILE_FLAG) --debug $(SRCD)/guile_db.c

.PHONY : clean
clean :
	rm $(OBJD)/taggy $(OBJ)
