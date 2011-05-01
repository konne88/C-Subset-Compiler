This project was created in order to complete a pass/fail college class exam.
The code is very ugly, redundant and makes heavy use of 
strcpy with strings of user controlled sizes.

Maybe, if I wouldn't have to take so many tests, I would
improve the whole thing, but for now it is just a collection
of crap in order to bairly parse the input.c file.

But oh well, it's a proof of concept. If you want to make
a good compiler compiler with little effort just use Java and Antlr.

Run by issuing the following command

flex quadComp.l; bison -d -b y quadComp.y; flex quadComp.l; gcc global.c lex.yy.c y.tab.c -lfl -lm -o quad; ./quad < input.c

Have fun
