SRCD=./src
OBJD=./build
OBJ=$(OBJD)/taggy.o
BINNAME=taggy

DC=dmd

DFLAGS=-debug -g -w -c -I=$(SRCD) -od=$(OBJD)


all : $(OBJ)
	$(DC) -of=$(OBJD)/taggy $(OBJ) -L=-lsqlite3

$(OBJD)/taggy.o : $(SRCD)/taggy.d
	$(DC) $(DFLAGS) $(SRCD)/taggy.d

.PHONY : clean
clean :
	rm $(OBJD)/taggy $(OBJ)
