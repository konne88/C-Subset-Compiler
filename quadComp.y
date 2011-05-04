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
int instructionCounter = 0;

char instructions[10000][1000];

int get_type_size(symtabEntryType type) {
    return 4;   // int and real are of the size 4
}

void patch(int ic) {
    sprintf(instructions[ic],"%s %d",instructions[ic],instructionCounter);
}

symtabEntry* declare_function(char* name, symtabEntryType returnType) {
    symtabEntry* f = lookup(name);
    if(f){
        if(f->internType != returnType) {
            yyerror("Function defined twice with differing return type.");
        }
    }
    else {
        f = addSymboltableEntry(theSymboltable, name, FUNC, returnType, 0, 0, 0, 0, 0, -1);
    }
    return f;
}

symtabEntry* variable_lookup(char* id){
    symtabEntry* e = lookup(id);
    return (e != NULL && e->vater == current_function) ? e : NULL;
}

symtabEntry* create_variable(symtabEntryType type, char* name) {
    if(variable_lookup(name)) {
        yyerror("Variable defined twice.");
    }

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

symtabEntry* create_parameter(symtabEntryType type, char* name, int param) {
    // we ignore the fact that parameters in declarations may have 
    // differing or no names.

    symtabEntry* v = variable_lookup(name);
    if(!v) {
        v = create_variable(type,name);
        v->parameter = param;
    } else {
        if(v->type != type){
            yyerror("Function parameters differ in type.");
        }
    }
    return v;
}

int
print_if (symtabEntry* check) 
{
    sprintf(instructions[instructionCounter],"if %s == 0 goto",check->name);
    return instructionCounter++;
}

int
print_goto () 
{
    sprintf(instructions[instructionCounter],"goto");
    return instructionCounter++;
}

void
print_full_not_if (symtabEntry* check, int target) 
{
    sprintf(instructions[instructionCounter++],"if %s != 0 goto %d",check->name,target);
}

void
print_full_goto (int target) 
{
    sprintf(instructions[instructionCounter++],"goto %d",target);
}


symtabEntry* 
print_binary_expression (char* op, symtabEntryType type, 
                         symtabEntry* a, symtabEntry* b) 
{
    symtabEntry* c = create_helper_variable(type);
    sprintf(instructions[instructionCounter++],"%s := %s %s %s",c->name,a->name,op,b->name);
    
    return c;
}

symtabEntry* 
print_unary_expression (char* op, symtabEntryType type, symtabEntry* a) 
{
    symtabEntry* c = create_helper_variable(type);
    sprintf(instructions[instructionCounter++],"%s := %s %s",c->name,op,a->name);
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
    sprintf(instructions[instructionCounter++],"%s := %s",c->name,value);
    return c;
}

symtabEntry* print_variable_assignment(symtabEntry* a,symtabEntry* b) {
    sprintf(instructions[instructionCounter++],"%s := %s",a->name,b->name);
    return a;
}

void print_pass_param(symtabEntry* a) {
    sprintf(instructions[instructionCounter++],"param %s",a->name);
}

symtabEntry* print_function_call(symtabEntry* f, int params){
    if(f->internType == NOP) {
        sprintf(instructions[instructionCounter++],"call %s, %d",f->name,params);
        return NULL;
    } else {
        symtabEntry* r = create_helper_variable(f->internType);
        sprintf(instructions[instructionCounter++],"%s := call %s, %d",r->name,f->name,params);
        return r;
    }
}

void print_conditional_jump(symtabEntry* boolean) {
    sprintf(instructions[instructionCounter++],"if %s == 0 goto M",boolean);
}

void print_return(symtabEntry* a) {
    if(a == NULL) {     // void
        if(current_function->internType != NOP) {
            yyerror("Returning nothing from non-void function.");
        }
        sprintf(instructions[instructionCounter++],"return");
    } else {    // non void
        if(current_function->internType == NOP) {
            yyerror("Void function may not return a value.");
        }
        a = print_cast(a, current_function->internType);

        sprintf(instructions[instructionCounter++],"return %s",a->name);
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
%type <entry> expression
%type <str> CONSTANT
%type <entry> assignment
%type <integer> exp_list
%type <integer> parameter_list
%type <integer> if_start
%type <integer> else_start
%type <integer> while_start
%type <integer> do_start

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

function_start 
    : var_type id 
    {
        current_function = declare_function($2,$1);
    }
    '(' parameter_list ')'
    {
        if(current_function->parameter == -1){ 
            // first declaration
            // update parameter amount in symboltable
            current_function->parameter = $5;
        } else {
            if(current_function->parameter != $5){
                yyerror("Function declared again with wrong amount of parameters.");            
            }
        }
    }
    ;
    
function
    : function_start ';'
    | function_start 
    {
        current_function->line = instructionCounter;
        // reset relative stack pointer
        // int and float have the same size
        rel_addr = current_function->parameter*sizeof(int);      
    }
    function_body
    {
        if(current_function->internType == NOP){
            print_return(NULL);
        }
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
        create_variable(INTEGER,$2);
        $$ = INTEGER;
    }
    | FLOAT id 
    {
        create_variable(REAL,$2);
        $$ = REAL;
    }
    | declaration ',' id
    {
        create_variable($1,$3);
        $$ = $1
    }
    ;

parameter_list
    : INT id
    {
        $$ = 1;
        create_parameter(INTEGER,$2,$$);
    }
    | FLOAT id
    {
        $$ = 1;
        create_parameter(REAL,$2,$$);
    }
    | parameter_list ',' INT id
    {
        $$ = $1+1;
        create_parameter(INTEGER,$4,$$);
    }
    | parameter_list ',' FLOAT id
    {
        $$ = $1+1;
        create_parameter(REAL,$4,$$);
    }
    | VOID
    { $$ = 0; }
    | 
    { $$ = 0; }                         
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

if_start
    : IF '(' assignment ')'
    {
        $$ = print_if($3);
    }
    ;

else_start
    : if_start matched_statement ELSE 
    {
        $$ = print_goto();
        // backpatch if
        patch($1);
    }
    ;
    
while_start 
    : WHILE '(' assignment ')'
    {
        $$ = print_if($3);
    }
    ;
    
do_start
    : DO
    {
        $$ = instructionCounter;
    }
    ;
    
matched_statement
    : else_start matched_statement 
    {
        // backpatch else
        patch($1);
    }
    
    | assignment ';'                                          
    | RETURN ';'
    {
        print_return(NULL); 
    }                                             
    | RETURN assignment ';'
    { 
        print_return($2);
    }  
    | while_start matched_statement      
    {
        print_full_goto($1);
        // backpatch while
        patch($1);
    }
    | do_start statement WHILE '(' assignment ')' ';' 
    {
        print_full_not_if($5,$1);
    }                      
    | '{' statement_list '}'     
    | '{''}'                
    ;

unmatched_statement
    : if_start statement 
    {
        // backpatch if
        patch($1);
    }
    | else_start unmatched_statement 
    {
        // backpatch else
        patch($1);
    }
    | while_start unmatched_statement          
    {
        print_full_goto($1);
        // backpatch while
        patch($1);
    }
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
    
    int i;
    
    for(i=0 ; i<instructionCounter ; ++i){
        printf("%3d:  %s\n",i,instructions[i]);
    }
    
    writeSymboltable(theSymboltable, stdout);
    
    return 0;
}

void yyerror(char * message) {
    printf("error message <%s>\n",message);
    exit(1);
}

//Epilogue
