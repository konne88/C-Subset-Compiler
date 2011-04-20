%{

// flex quadComp.l; bison -d -b y quadComp.y; flex quadComp.l; gcc lex.yy.c y.tab.c -lfl -lm -o quad; cat input.c | ./quad

#include <stdio.h>

//Prologue
void yyerror(char * message);

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

%token  '('
%token  ')'
%token  ','

%right '='

%left  NOT_EQUAL
%left  EQUAL
%left  GREATER_OR_EQUAL
%left  LESS_OR_EQUAL
%left  '<'
%left  '>'

%left  LOG_AND
%left  LOG_OR
%left  SHIFTLEFT

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

%%    // grammar rules


programm
    : function                  
    | programm function         
    ;

function
    : var_type id '(' parameter_list ')' ';'
    | var_type id '(' parameter_list ')' function_body
    ;

function_body
    : '{' statement_list  '}'
    | '{' declaration_list statement_list '}'
    ;

declaration_list
    : declaration ';'
    | declaration_list declaration ';'
    ;

declaration
    : INT id
    | FLOAT id
    | declaration ',' id
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
    : INT 
    | VOID
    | FLOAT
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
    | '{' '}'                                                                                                                                                                                       
    ;

unmatched_statement
    : IF '(' assignment ')' statement                       
    | WHILE '(' assignment ')' unmatched_statement          
    | IF '(' assignment ')' matched_statement ELSE unmatched_statement 
    ;


assignment
    : expression                 
    | id '='          expression 
    ;

expression
    : INC_OP expression                        
    | DEC_OP expression                        
    | expression LOG_OR           expression   
    | expression LOG_AND          expression   
    | expression NOT_EQUAL        expression   
    | expression EQUAL            expression   
    | expression GREATER_OR_EQUAL expression   
    | expression LESS_OR_EQUAL    expression   
    | expression '>'              expression   
    | expression '<'              expression   
    | expression SHIFTLEFT        expression   
    | expression '+'              expression   
    | expression '-'              expression   
    | expression '*'              expression   
    | expression '/'              expression   
    | expression '%'              expression   
    | '!' expression                           
    | '+' expression %prec U_PLUS              
    | '-' expression %prec U_MINUS             
    | CONSTANT                                 
    | '(' expression ')'                       
    | id '(' exp_list ')'                      
    | id '('  ')'                              
    | id
    ;

exp_list
    : expression
    | exp_list ',' expression	
    ;

id
    : IDENTIFIER	
    ;
    
%%

int main() {
    yyparse();
    return 0;
}

void yyerror(char * message) {
    printf("error message <%s>",message);
}

//Epilogue