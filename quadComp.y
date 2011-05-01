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

int get_type_size(symtabEntryType type) {
    return 4;   // int and real are of the size 4
}

symtabEntry* declare_function(char* name, symtabEntryType returnType) {
    if(lookup(name)) {
        yyerror("Function defined twice.");
    }
    return addSymboltableEntry(theSymboltable, name, FUNC, returnType, 0, 0, 0, 0, 0, 0);
}

symtabEntry* create_variable(symtabEntryType type, char* name) {
    symtabEntry* entry = addSymboltableEntry(theSymboltable, name, type, NOP, rel_addr, 0, 0, 0, current_function, 0);
    rel_addr += get_type_size(type);
    return entry;
}

symtabEntry* create_helper_variable(symtabEntryType type) {
    static help_num = 0;   // current helper variable number

    char* str = malloc(1000);

    sprintf(str,"__H%d",help_num);

    ++help_num;

    return create_variable(type,str);
}

symtabEntry* variable_lookup(char* id){
    symtabEntry* e = lookup(id);
    return (e != NULL && e->vater == current_function) ? e : NULL;
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

symtabEntry* print_cast(symtabEntry* a, symtabEntryType castTo) {
    if(a->type != castTo){
        a = print_unary_expression(castTo==REAL?"tofloat":"toint",castTo,a);
    }
    return a;
}

symtabEntry* 
print_binary_cast_expression ( char* op, symtabEntry* a, symtabEntry* b)
{
    symtabEntryType type = (a->type == INTEGER && b->type == INTEGER)?INTEGER:REAL;
    
    // cast
    if(type == REAL) {
        a = print_cast(a, REAL);
        b = print_cast(b, REAL);
    }
    
    return print_binary_expression(op,type,a,b);
}

symtabEntry* 
print_binary_integer_only_expression (char* op, symtabEntry* a, symtabEntry* b)
{
    if(a->type != INTEGER || a->type != INTEGER){
        yyerror("Passing non integer to interger only operation");
    }
    return print_binary_expression(op,INTEGER,a,b);
}

symtabEntry* print_constant_assignment(symtabEntryType type, char* value) {
    symtabEntry* c = create_helper_variable(type);
    printf("%s := %s\n",c->name,value);
    return c;
}

symtabEntry* print_variable_assignment(symtabEntry* a,symtabEntry* b) {
    printf("%s := %s\n",a->name,b->name);
    return a;
}

void print_pass_param(symtabEntry* a) {
    printf("param %s\n",a->name);
    return a;
}

symtabEntry* print_function_call(symtabEntry* f, int params){
    if(f->internType == NOP) {
        printf("call %s, %d\n",f->name,params);
        return NULL;
    } else {
        symtabEntry* r = create_helper_variable(f->internType);
        printf("%s := call %s, %d\n",r->name,f->name,params);
        return r;
    }
}

void print_conditional_jump(symtabEntry* boolean) {
    printf("if %s == 0 goto M\n",boolean);
}

void print_return(symtabEntry* a) {
    if(a == NULL) {     // void
        if(current_function->internType != NOP) {
            yyerror("Returning nothing from non-void function.");
        }
        printf("return\n");
    } else {    // non void
        if(current_function->internType == NOP) {
            yyerror("Void function may not return a value.");
        }
        a = print_cast(a, current_function->internType);

        printf("return %s\n",a->name);
    }
}

%}

// TODO how does a functioncall work? how do i know where to jump?
// TODO how does receiving function parameters work?
// TODO how do jumps work?

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
%type <entry> assignment;
%type <integer> exp_list;

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
        declare_function($2,$1);
    }
    
    | var_type id '(' parameter_list ')' 
    {
        // check declaration
        current_function = lookup($2);
        if(current_function == NULL){
            current_function = declare_function($2,$1);
        } else {
            if($1 != current_function->internType){
                yyerror("Function's return type differs from declaration.");
            }
        }
        
        // reset relative stack pointer
        rel_addr = 0;      
    }
    function_body
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
        if(variable_lookup($2)) {
            printf($2);
            yyerror("Integer variable defined twice.");
        }
        addSymboltableEntry(theSymboltable, $2, INTEGER, NOP, rel_addr, 0, 0, 0, current_function, 0);
        rel_addr += sizeof(int);
        $$ = INTEGER;
    }
    | FLOAT id 
    {
        if(variable_lookup($2)) {
            yyerror("Float variable defined twice.");
        }
        addSymboltableEntry(theSymboltable, $2, REAL, NOP, rel_addr, 0, 0, 0, current_function, 0);
        rel_addr += sizeof(float);
        $$ = REAL;
    }
    | declaration ',' id
    {
        if(variable_lookup($3)) {
            yyerror("Declarationlist variable defined twice.");
        }
        addSymboltableEntry(theSymboltable, $3, $1, NOP, rel_addr, 0, 0, 0, current_function, 0);
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
    : IF '(' assignment ')'
    matched_statement ELSE matched_statement
    | assignment ';'                                                
    | RETURN ';' { print_return(NULL); }                                             
    | RETURN assignment { print_return($2);}  ';'                 
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
        $$ = variable_lookup($1);
        if($$ == NULL){
            yyerror("Assignment to undeclared variable.");
        }
        print_variable_assignment($$,$3);
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
    | expression LOG_OR expression
    {    
        $$ = print_binary_integer_only_expression("||",$1,$3);
    }
    | expression LOG_AND expression   
    {
        $$ = print_binary_integer_only_expression("&&",$1,$3);
    }
    | expression NOT_EQUAL expression
    {    
        $$ = print_binary_expression("!=",INTEGER,$1,$3);
    }
    | expression EQUAL expression   
    {    
        $$ = print_binary_expression("==",INTEGER,$1,$3);
    }
    | expression GREATER_OR_EQUAL expression   
    {    
        $$ = print_binary_expression(">=",INTEGER,$1,$3);
    }
    | expression LESS_OR_EQUAL expression   
    {    
        $$ = print_binary_expression("<=",INTEGER,$1,$3);
    }
    | expression '>' expression
    {    
        $$ = print_binary_expression(">",INTEGER,$1,$3);
    }
    | expression '<' expression   
    {    
        $$ = print_binary_expression("<",INTEGER,$1,$3);
    }
    | expression SHIFTLEFT expression   
    {    
        $$ = print_binary_integer_only_expression("<<",$1,$3);
    }
    | expression '+' expression
    {    
        $$ = print_binary_cast_expression("+",$1,$3);
    }
    | expression '-' expression   
    {    
        $$ = print_binary_cast_expression("-",$1,$3);
    }
    | expression '*' expression   
    {    
        $$ = print_binary_cast_expression("*",$1,$3);
    }
    | expression '/' expression   
    {    
        $$ = print_binary_cast_expression("/",$1,$3);
    }
    | expression '%' expression   
    {    
        $$ = print_binary_integer_only_expression("%",$1,$3);
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
        $$ = print_constant_assignment(strchr($1,'.')==NULL ? INTEGER:REAL, $1);
    }
    | '(' expression ')'                       
    {
        $$ = $2;
    }
    | id '(' exp_list ')' {
        symtabEntry* e = lookup($1);
        if(e == NULL) {
            yyerror("Trying to call undecared function");
        }
        $$ = print_function_call(e,$3);
    }
    | id
    {
        $$ = variable_lookup($1);
        if($$ == NULL){
            yyerror("Usage of undeclared variable.");
        }
    }
    ;

exp_list
    : {$$ = 0;}
    | expression    {print_pass_param($1); $$ = 1;}
    | exp_list ',' expression   {print_pass_param($3); $$ = ++$1}
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
