%{

// flex quadComp.l; bison -d -b y quadComp.y; flex quadComp.l; gcc global.c lex.yy.c y.tab.c -lfl -lm -o quad; cat input.c | ./quad

#include <stdio.h>
#include "global.h"
#include <stdlib.h>
#include <string.h>

//Prologue
void yyerror(char * message);

int rel_addr = 0; // relative (to ebp) addr of current local variable 
symtabEntry *current_function = NULL;

symtabEntry* create_helper_variable(symtabEntryType type) {
    static help_num = 0;   // current helper variable number

    char* str = malloc(1000);

    sprintf(str,"__H%d",help_num);

    ++help_num;

    symtabEntry* entry = addSymboltableEntry(theSymboltable, str, type, NOP, rel_addr, 0, 0, 0, 0, 0);
    ++rel_addr;
    
    return entry;
}


symtabEntry* 
print_binary_expression (char* op, symtabEntryType type, 
                         symtabEntry* a, symtabEntry* b) 
{
    symtabEntry* c = create_helper_variable(type);
    printf("%s := %s %s %s\n",c->name,a->name,op,b->name);
    return c;
}

symtabEntry* 
print_unary_expression (char* op, symtabEntryType type, symtabEntry* a) 
{
    symtabEntry* c = create_helper_variable(type);
    printf("%s := %s %s\n",c->name,op,a->name);
    return c;
}

%}

// left means, build the tree from left to right

// right left
// bottom high prio
// top low prio

// left assoziativ
// a+b+c = (a+b)+c

// ++a

//Bison declarations

%token CONSTANT
%token DO
%token ELSE
%token FLOAT
%token IDENTIFIER
%token IF
%token INT
%token RETURN
%token VOID
%token WHILE

%token '{'
%token '}'                                                 
%token ';'

%token '('
%token ')'
%token ','

%right '='

%left  LOG_AND
%left  LOG_OR
%left  SHIFTLEFT

%left  NOT_EQUAL
%left  EQUAL
%left  GREATER_OR_EQUAL
%left  LESS_OR_EQUAL
%left  '<'
%left  '>'

%left  '+'
%left  '-'

%left  '*'
%left  '/'
%left  '%'

%left DEC_OP
%left INC_OP
%left '!'
%left U_MINUS
%left U_PLUS

%type <type> INT
%type <type> FLOAT
%type <type> VOID
%type <type> var_type

%type <str> id
%type <type> declaration
%type <entry> expression;
%type <str> CONSTANT;

%union
{   // defines yylval
    char str[1000];
    int integer;
    float real;
    symtabEntryType type;
    symtabEntry* entry;
//    struct CharQueue *queue;
}

%%    // grammar rules


programm
    : function                  
    | programm function         
    ;

function
    : var_type id '(' parameter_list ')' ';'  
    {
        if(lookup($2)) {
            yyerror("Function defined twice.");
        }
        addSymboltableEntry(theSymboltable, $2, FUNC, $1, 0, 0, 0, 0, 0, 0);
    }
    | var_type id '(' parameter_list ')' function_body 
    {
        current_function = lookup($2);
        if(current_function == NULL){
            addSymboltableEntry(theSymboltable, $2, FUNC, $1, 0, 0, 0, 0, 0, 0);
        } else {
            if($1 != current_function->internType){
                yyerror("Function's return type differs from declaration.");
            }
        }
        rel_addr = 0;      // reset stack pointer
    }
    ;

function_body
    : '{' statement_list '}'
    | '{' declaration_list statement_list '}'
    ;

declaration_list
    : declaration ';'
    | declaration_list declaration ';'
    ;

declaration
    : INT id   
    {
        if(lookup($2)) {
            yyerror("Integer variable defined twice.");
        }
        addSymboltableEntry(theSymboltable, $2, INTEGER, NOP, rel_addr, 0, 0, 0, 0, 0);
        rel_addr += sizeof(int);
        $$ = INTEGER;
    }
    | FLOAT id 
    {
        if(lookup($2)) {
            yyerror("Float variable defined twice.");
        }
        addSymboltableEntry(theSymboltable, $2, REAL, NOP, rel_addr, 0, 0, 0, 0, 0);
        rel_addr += sizeof(float);
        $$ = REAL;
    }
    | declaration ',' id
    {
        if(lookup($3)) {
            yyerror("Declarationlist variable defined twice.");
        }
        addSymboltableEntry(theSymboltable, $3, $1, NOP, rel_addr, 0, 0, 0, 0, 0);
        rel_addr += sizeof(float);
        $$ = $1
    }
    ;

parameter_list
    : INT id
    | FLOAT id
    | parameter_list ',' INT id
    | parameter_list ',' FLOAT id
    | VOID
    |                          
    ;

var_type
    : INT   {$$ = INTEGER;}
    | VOID  {$$ = NOP;}
    | FLOAT {$$ = REAL;}
    ;



statement_list
    : statement
    | statement_list statement  
    ;

statement
    : matched_statement
    | unmatched_statement
    ;

matched_statement
    : IF '(' assignment ')' matched_statement ELSE matched_statement
    | assignment ';'                                                
    | RETURN ';'                                                 
    | RETURN assignment ';'                                                  
    | WHILE '(' assignment ')' matched_statement                             
    | DO statement WHILE '(' assignment ')' ';'                              
    | '{' statement_list '}'                                                 
    | '{''}'                                                                                                                
    ;

unmatched_statement
    : IF '(' assignment ')' statement                       
    | WHILE '(' assignment ')' unmatched_statement          
    | IF '(' assignment ')' matched_statement ELSE unmatched_statement 
    ;

assignment
    : expression
    | id '=' expression 
    {
        printf("%s := %s\n",$1,$3->name);
        
        // TODO make sure the type is right
        
        if(lookup($1) == NULL){
            error("Usage of undeclared variable.");
        }
    }
    ;


expression
    : INC_OP expression  
    {
        $$ = print_unary_expression("++",$2->type,$2);
    }
    | DEC_OP expression
    {
        $$ = print_unary_expression("--",$2->type,$2);
    }
    | expression LOG_OR           expression
    {    
        $$ = print_binary_expression("||",INTEGER,$1,$3);
    }
    | expression LOG_AND          expression   
    {
        $$ = print_binary_expression("&&",INTEGER,$1,$3);
    }
    | expression NOT_EQUAL        expression
    {    
        $$ = print_binary_expression("!=",INTEGER,$1,$3);
    }
    | expression EQUAL            expression   
    {    
        $$ = print_binary_expression("==",INTEGER,$1,$3);
    }
    | expression GREATER_OR_EQUAL expression   
    {    
        $$ = print_binary_expression(">=",INTEGER,$1,$3);
    }
    | expression LESS_OR_EQUAL    expression   
    {    
        $$ = print_binary_expression("<=",INTEGER,$1,$3);
    }
    | expression '>'              expression
    {    
        $$ = print_binary_expression(">",INTEGER,$1,$3);
    }
    | expression '<'              expression   
    {    
        $$ = print_binary_expression("<",INTEGER,$1,$3);
    }
    | expression SHIFTLEFT        expression   
    {    
        $$ = print_binary_expression("<<",INTEGER,$1,$3);
    }
    | expression '+'              expression
    {    
        $$ = print_binary_expression("+",INTEGER,$1,$3);
    }
    | expression '-'              expression   
    {    
        $$ = print_binary_expression("-",INTEGER,$1,$3);
    }
    | expression '*'              expression   
    {    
        $$ = print_binary_expression("*",INTEGER,$1,$3);
    }
    | expression '/'              expression   
    {    
        $$ = print_binary_expression("/",INTEGER,$1,$3);
    }
    | expression '%'              expression   
    {    
        $$ = print_binary_expression("%",INTEGER,$1,$3);
    }
    | '!' expression             
    {
        $$ = print_unary_expression("!",INTEGER,$2);
    }
    | '+' expression %prec U_PLUS              
    {
        $$ = $2
    }
    | '-' expression %prec U_MINUS             
    {
        $$ = print_unary_expression("-",INTEGER,$2);
    }              
    | CONSTANT
    {
        $$ = create_helper_variable(strchr($1,'.')==NULL ? REAL:INTEGER);
        printf("%s := %s;\n",$$->name,$1);
    }
    | '(' expression ')'                       
    {
        $$ = $2;
    }
    | id '(' exp_list ')'
    | id '('  ')' {
        
        $$ = create_helper_variable( ? REAL:INTEGER);
        printf("%s := %s;\n",$$->name,$1);
    }               
    | id
    {
        $$ = lookup($1);
        if($$ == NULL){
            error("Usage of undeclared variable.");
        }
    }
    ;

exp_list
    : expression
    | exp_list ',' expression
    ;

id
    : IDENTIFIER  { strcpy($$,yylval.str); }
    ;
    
%%

int main() {
    yyparse();
    
    writeSymboltable(theSymboltable, stdout);
    
    return 0;
}

void yyerror(char * message) {
    printf("error message <%s>\n",message);
    exit(1);
}

//Epilogue
