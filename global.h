#ifndef GLOBAL_H_
#define GLOBAL_H_

typedef enum symtab_EntryType {INTEGER, REAL, BOOL, PROC, NOP, ARR, FUNC, PROG, PRG_PARA}
	symtabEntryType;

typedef struct a_symtabEntry{
	char * name;
	symtabEntryType type;
	symtabEntryType internType;
	int offset;
	int line;
	int index1;
	int index2;
	struct a_symtabEntry * vater;
	int parameter;
	int number;
	float value;
	struct a_symtabEntry * next;
} symtabEntry;

struct {
    int no;
    int next;
} ifStmt;

symtabEntry* lookup_in_function(char* str, symtabEntry* function);
symtabEntry* lookup(char* str);
symtabEntry* addSymboltableEntry (symtabEntry * Symboltable,char * name,symtabEntryType type,symtabEntryType internType,int offset,int line,int index1,int index2,symtabEntry * vater,int parameter);
void  getSymbolTypePrintout(symtabEntryType type, char * writeIn);
void  writeSymboltable (symtabEntry * Symboltable, FILE * outputFile);

extern symtabEntry * theSymboltable;    // dafür gehörst du geschlagen


#endif /*GLOBAL_H_*/        // dafür gehörst du geschlagen

