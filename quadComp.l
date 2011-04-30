%{

    #include "global.h"
    #include "y.tab.h"
    
    void print(char *s){
     //   printf(s);
     //   printf("\n");
    }
%}

%%

\/\/[^\n]* {}

do { print("do"); return DO; }

else { print("else"); return ELSE; }

if { print("if"); return IF; }

return { print("return"); return RETURN; }

while { print("while"); return WHILE; }

void { print("void"); return VOID; }

float { print("float"); return FLOAT; }

int { print("int"); return INT; }

([1-9][0-9]*|0)(\.[0-9]+)? { print("const"); return CONSTANT; }

[a-zA-Z_][a-zA-Z_0-9]* { print("id"); strcpy(yylval.str, yytext); return IDENTIFIER; }

\( {print("("); return '('; }

\) {print(")"); return ')'; }

\} {print("}"); return '}'; }

\{ {print("{"); return '{'; }

\; {print(";"); return ';'; }

\+\+ {print("++"); return INC_OP; }

\-\- { print("--"); return DEC_OP; }

\=\= { print("=="); return EQUAL; }

\+ { print("+"); return '+'; }

\- { print("-"); return '-'; }

\* { print("*"); return '*'; }

\/ { print("/"); return '/'; }

\% { print("%%"); return '%'; }

\! { print("!"); return '!'; }

\= { print("="); return '='; }

\&\& { print("&&"); return LOG_AND; }

\|\| { print("|"); return LOG_OR; }

\!\= { print("!="); return NOT_EQUAL; }

\>\= { print(">="); return GREATER_OR_EQUAL; }

\<\= { print("<="); return LESS_OR_EQUAL; }

\> { print(">"); return '>'; }

\< { print("<"); return '<'; }

\, { print(","); return ','; }

\<\< { print("<<"); return SHIFTLEFT; }

[ \t\n]+ {}
