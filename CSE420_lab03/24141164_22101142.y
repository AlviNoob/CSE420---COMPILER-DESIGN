%{

#include "symbol_table.h"

#define YYSTYPE symbol_info*
#include <string>
#include <cstring>
#include <sstream>
#include <unordered_set>



extern FILE *yyin;
int yyparse(void);
int yylex(void);

extern YYSTYPE yylval;

// create your symbol table here.
// You can store the pointer to your symbol table in a global variable
// or you can create an object

symbol_table *table; 



int lines = 1;

ofstream outlog;
ofstream errorlog;
int error_count = 0;



string current_type;
string current_func_name;
string current_func_return_type;
vector<pair<string,string> > current_func_params;
bool is_function_definition = false;
bool error_found = false;



void yyerror(char *s)
{
	outlog<<"Error at line "<<lines<<": "<<s <<endl <<endl;

    // you may need to reinitialize variables if you find an error
	error_found = true;
}

bool is_variable_declared_current_scope(string name) {
    symbol_info* temp = new symbol_info(name, "ID");
    symbol_info* found = table->lookup_current_scope(temp);
    delete temp;
    return found != NULL;
}

bool is_function_declared(string name) {
    symbol_info* temp = new symbol_info(name, "ID");
    symbol_info* found = table->lookup(temp);
    delete temp;
    return found != NULL && found->get_is_function();
}

%}

%token IF ELSE FOR WHILE DO BREAK INT CHAR FLOAT DOUBLE VOID RETURN SWITCH CASE DEFAULT CONTINUE PRINTLN ADDOP MULOP INCOP DECOP RELOP ASSIGNOP LOGICOP NOT LPAREN RPAREN LCURL RCURL LTHIRD RTHIRD COMMA SEMICOLON CONST_INT CONST_FLOAT ID

%nonassoc LOWER_THAN_ELSE
%nonassoc ELSE

%%

start : program
	{
		outlog<<"At line no: "<<lines<<" start : program "<<endl<<endl;
		outlog<<"Symbol Table"<<endl<<endl;
		
		// Print your whole symbol table here
		table->print_all_scopes(outlog);
	}
	;

program : program unit
	{
		outlog<<"At line no: "<<lines<<" program : program unit "<<endl<<endl;
		outlog<<$1->getname()+"\n"+$2->getname()<<endl<<endl;
		
		$$ = new symbol_info($1->getname()+"\n"+$2->getname(),"program");
	}
	| unit
	{
		outlog<<"At line no: "<<lines<<" program : unit "<<endl<<endl;
		outlog<<$1->getname()<<endl<<endl;
		
		$$ = new symbol_info($1->getname(),"program");
	}
	;

unit : var_declaration
	 {
		outlog<<"At line no: "<<lines<<" unit : var_declaration "<<endl<<endl;
		outlog<<$1->getname()<<endl<<endl;
		
		$$ = new symbol_info($1->getname(),"unit");
	 }
     | func_definition
     {
		outlog<<"At line no: "<<lines<<" unit : func_definition "<<endl<<endl;
		outlog<<$1->getname()<<endl<<endl;
		
		$$ = new symbol_info($1->getname(),"unit");
	 }
     ;

func_definition : type_specifier ID LPAREN parameter_list RPAREN {

	    current_func_name = $2->getname();
        unordered_set<string> param_names;
        for (auto &param : current_func_params) {
            if (!param.second.empty()) {
                if (param_names.count(param.second)) {
                    errorlog << "At line no: " << lines << " Multiple declaration of variable " << param.second << " in parameter of " << current_func_name << endl << endl;
                    error_count++;
                }
				else {
                    param_names.insert(param.second);
                     }
            }
        }
        symbol_info temp_var($2->getname(), "ID");
        symbol_info* found_var = table->lookup(&temp_var);
        if (found_var != NULL && !found_var->get_is_function()) {
            errorlog << "At line no: " << lines << " Multiple declaration of function " << $2->getname() << endl << endl;
            error_count++;
        }


		if (!is_function_declared($2->getname())) {
			vector<pair<string, string> > params = current_func_params;
			symbol_info* func = new symbol_info($2->getname(),"ID",$1->getname());
			func->set_as_function($1->getname(),params);
			table->insert(func);
		}

	}
	compound_statement
		{	
			outlog<<"At line no: "<<lines<<" func_definition : type_specifier ID LPAREN parameter_list RPAREN compound_statement "<<endl<<endl;
			outlog<<$1->getname()<<" "<<$2->getname()<<"("+$4->getname()+")\n"<<$7->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname()+" "+$2->getname()+"("+$4->getname()+")\n"+$7->getname(),"func_def");	
			
			
			current_func_params.clear();
		}

		| type_specifier ID LPAREN RPAREN {
			current_func_name = $2->getname();
			unordered_set<string> param_names;
			for (auto &param : current_func_params) {
				if (!param.second.empty()) {
					if (param_names.count(param.second)) {
						errorlog << "At line no: " << lines << " Multiple declaration of variable " << param.second << " in parameter of " << current_func_name << endl << endl;
						error_count++;
					}
					else {
						param_names.insert(param.second);
					}
				}
			}
			if(!is_function_declared($2->getname())) {
				vector<pair<string, string> > params;
				symbol_info* func = new symbol_info($2->getname(), "ID", $1->getname());
				func->set_as_function($1->getname(), params);
				table->insert(func);

			}
		}
		
		 compound_statement
		{
			
			outlog<<"At line no: "<<lines<<" func_definition : type_specifier ID LPAREN RPAREN compound_statement "<<endl<<endl;
			outlog<<$1->getname()<<" "<<$2->getname()<<"()\n"<<$6->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname()+" "+$2->getname()+"()\n"+$6->getname(),"func_def");	
			
			
		}
 		;

parameter_list : parameter_list COMMA type_specifier ID
		{
			outlog<<"At line no: "<<lines<<" parameter_list : parameter_list COMMA type_specifier ID "<<endl<<endl;
			outlog<<$1->getname()<<","<<$3->getname()<<" "<<$4->getname()<<endl<<endl;
					
			$$ = new symbol_info($1->getname()+","+$3->getname()+" "+$4->getname(),"param_list");
			
            // store the necessary information about the function parameters
            // They will be needed when you want to enter the function into the symbol table
			pair<string, string> param($3->getname(), $4->getname());
			current_func_params.push_back(param);

		}
		| parameter_list COMMA type_specifier
		{
			outlog<<"At line no: "<<lines<<" parameter_list : parameter_list COMMA type_specifier "<<endl<<endl;
			outlog<<$1->getname()<<","<<$3->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname()+","+$3->getname(),"param_list");
			
            // store the necessary information about the function parameters
            // They will be needed when you want to enter the function into the symbol table
			pair<string, string> param($3->getname(), "");
			current_func_params.push_back(param);
		}
 		| type_specifier ID
 		{
			outlog<<"At line no: "<<lines<<" parameter_list : type_specifier ID "<<endl<<endl;
			outlog<<$1->getname()<<" "<<$2->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname()+" "+$2->getname(),"param_list");
			
            // store the necessary information about the function parameters
            // They will be needed when you want to enter the function into the symbol table
			
			pair<string, string> param($1->getname(), $2->getname());
			current_func_params.push_back(param);
		}
		| type_specifier
		{
			outlog<<"At line no: "<<lines<<" parameter_list : type_specifier "<<endl<<endl;
			outlog<<$1->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname(),"param_list");
			
            // store the necessary information about the function parameters
            // They will be needed when you want to enter the function into the symbol table

			pair<string, string> param($1->getname(), "");
			current_func_params.push_back(param);
		}
 		;

compound_statement : LCURL {

			table->enter_scope();
		
			if(!current_func_params.empty()) {
				for(auto param : current_func_params) {
					if(!param.second.empty()) {
						symbol_info* param_symbol = new symbol_info(param.second, "ID", param.first);
						table->insert(param_symbol);
					}
				}
			}
		
		
		
		
		} statements RCURL
			{ 
 		    	outlog<<"At line no: "<<lines<<" compound_statement : LCURL statements RCURL "<<endl<<endl;
				outlog<<"{\n"+$3->getname()+"\n}"<<endl<<endl;
				
				table->print_current_scope();
		

				table->exit_scope();
				$$ = new symbol_info("{\n"+$3->getname()+"\n}","comp_stmnt");
 		    }

 		    | LCURL {
				table->enter_scope();

			}
			
			RCURL
 		    { 
 		    	outlog<<"At line no: "<<lines<<" compound_statement : LCURL RCURL "<<endl<<endl;
				outlog<<"{\n}"<<endl<<endl;
				
				
				
				// The compound statement is complete.
                // Print the symbol table here and exit the scope
				table->print_current_scope();

				table->exit_scope();

				$$ = new symbol_info("{\n}","comp_stmnt");
 		    }
 		    ;
 		    
var_declaration : type_specifier declaration_list SEMICOLON
		 {
			outlog<<"At line no: "<<lines<<" var_declaration : type_specifier declaration_list SEMICOLON "<<endl<<endl;
			outlog<<$1->getname()<<" "<<$2->getname()<<";"<<endl<<endl;
			
			$$ = new symbol_info($1->getname()+" "+$2->getname() + ";","var_dec");
			
			// Insert necessary information about the variables in the symbol 
			current_type = $1->getname();
			
			
			if(current_type == "void") {
                errorlog << "At line no: " << lines << " variable type can not be void" << endl << endl;
                error_count++;
			// mark the type as error so inserted symbols get an error data type
			current_type = "error";
            }
		 
		 }
 		 ;

type_specifier : INT
		{
			outlog<<"At line no: "<<lines<<" type_specifier : INT "<<endl<<endl;
			outlog<<"int"<<endl<<endl;
			
			$$ = new symbol_info("int","type");
			current_type = "int";
	    }
 		| FLOAT
 		{
			outlog<<"At line no: "<<lines<<" type_specifier : FLOAT "<<endl<<endl;
			outlog<<"float"<<endl<<endl;
			
			$$ = new symbol_info("float","type");
			current_type = "float";
	    }
 		| VOID
 		{
			outlog<<"At line no: "<<lines<<" type_specifier : VOID "<<endl<<endl;
			outlog<<"void"<<endl<<endl;
			
			$$ = new symbol_info("void","type");
			current_type = "void";
	    }
 		;

declaration_list : declaration_list COMMA ID //edit // confusion
		  {
 		  	outlog<<"At line no: "<<lines<<" declaration_list : declaration_list COMMA ID "<<endl<<endl;
 		  	outlog<<$1->getname()+","<<$3->getname()<<endl<<endl;

            // you may need to store the variable names to insert them in symbol table here or later
			
			$$ = new symbol_info($1->getname() + "," + $3->getname(), "decl_list");
			if(is_variable_declared_current_scope($3->getname())) {
                errorlog << "At line no: " << lines << " Multiple declaration of variable " << $3->getname() << endl << endl;
				error_count++;
                $$ = new symbol_info($1->getname() + "," + $3->getname(), "decl_list");
            } else {
 
                symbol_info* new_var = new symbol_info($3->getname(), "ID", current_type);
                table->insert(new_var);
                $$ = new symbol_info($1->getname() + "," + $3->getname(), "decl_list");
            }
 		  }
 		  | declaration_list COMMA ID LTHIRD CONST_INT RTHIRD //array after some declaration
 		  {
 		  	outlog<<"At line no: "<<lines<<" declaration_list : declaration_list COMMA ID LTHIRD CONST_INT RTHIRD "<<endl<<endl;
 		  	outlog<<$1->getname()+","<<$3->getname()<<"["<<$5->getname()<<"]"<<endl<<endl;

            // you may need to store the variable names to insert them in symbol table here or later
			$$ = new symbol_info($1->getname() + "," + $3->getname() + "[" + $5->getname() + "]", "decl_list");

 
            if(is_variable_declared_current_scope($3->getname())) {
				errorlog << "At line no: " << lines << " Multiple declaration of variable " << $3->getname() << endl << endl;
				error_count++;
                $$ = new symbol_info($1->getname() + "," + $3->getname() + "[" + $5->getname() + "]", "decl_list");
            } else { 

                int size = stoi($5->getname());
                symbol_info* new_array = new symbol_info($3->getname(), "ID", current_type, size);
                table->insert(new_array);
                $$ = new symbol_info($1->getname() + "," + $3->getname() + "[" + $5->getname() + "]", "decl_list");
            
			}  

 		  }
 		  |ID
 		  {
 		  	outlog<<"At line no: "<<lines<<" declaration_list : ID "<<endl<<endl;
			outlog<<$1->getname()<<endl<<endl;

            // you may need to store the variable names to insert them in symbol table here or later
			$$ = new symbol_info($1->getname(), "decl_list");
			if(is_variable_declared_current_scope($1->getname())) {
				errorlog << "At line no: " << lines << " Multiple declaration of variable " << $1->getname() << endl << endl;
				error_count++;
                $$ = new symbol_info($1->getname(), "decl_list");
            } else {

                symbol_info* new_var = new symbol_info($1->getname(), "ID", current_type);
                table->insert(new_var);
                $$ = new symbol_info($1->getname(), "decl_list");
            }
 		  }
 		  | ID LTHIRD CONST_INT RTHIRD //array
 		  {
 		  	outlog<<"At line no: "<<lines<<" declaration_list : ID LTHIRD CONST_INT RTHIRD "<<endl<<endl;
			outlog<<$1->getname()<<"["<<$3->getname()<<"]"<<endl<<endl;

            // you may need to store the variable names to insert them in symbol table here or later
            $$ = new symbol_info($1->getname() + "[" + $3->getname() + "]", "decl_list");


            if(is_variable_declared_current_scope($1->getname())) {
				errorlog << "At line no: " << lines << " Multiple declaration of variable " << $1->getname() << endl << endl;
				error_count++;
                $$ = new symbol_info($1->getname() + "[" + $3->getname() + "]", "decl_list");
            } else {
 
                int size = stoi($3->getname());
                symbol_info* new_array = new symbol_info($1->getname(), "ID", current_type, size);
                table->insert(new_array);
                $$ = new symbol_info($1->getname() + "[" + $3->getname() + "]", "decl_list");
            }
 		  }
 		  ;
 		  

statements : statement
	   {
	    	outlog<<"At line no: "<<lines<<" statements : statement "<<endl<<endl;
			outlog<<$1->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname(),"stmnts");
	   }
	   | statements statement
	   {
	    	outlog<<"At line no: "<<lines<<" statements : statements statement "<<endl<<endl;
			outlog<<$1->getname()<<"\n"<<$2->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname()+"\n"+$2->getname(),"stmnts");
	   }
	   ;
	   
statement : var_declaration
	  {
	    	outlog<<"At line no: "<<lines<<" statement : var_declaration "<<endl<<endl;
			outlog<<$1->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname(),"stmnt");
	  }
	  | func_definition
	  {
	  		outlog<<"At line no: "<<lines<<" statement : func_definition "<<endl<<endl;
            outlog<<$1->getname()<<endl<<endl;

            $$ = new symbol_info($1->getname(),"stmnt");
	  		
	  }
	  | expression_statement
	  {
	    	outlog<<"At line no: "<<lines<<" statement : expression_statement "<<endl<<endl;
			outlog<<$1->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname(),"stmnt");
	  }
	  | compound_statement
	  {
	    	outlog<<"At line no: "<<lines<<" statement : compound_statement "<<endl<<endl;
			outlog<<$1->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname(),"stmnt");
	  }
	  | FOR LPAREN expression_statement expression_statement expression RPAREN statement
	  {
	    	outlog<<"At line no: "<<lines<<" statement : FOR LPAREN expression_statement expression_statement expression RPAREN statement "<<endl<<endl;
			outlog<<"for("<<$3->getname()<<$4->getname()<<$5->getname()<<")\n"<<$7->getname()<<endl<<endl;
			
			$$ = new symbol_info("for("+$3->getname()+$4->getname()+$5->getname()+")\n"+$7->getname(),"stmnt");
	  }
	  | IF LPAREN expression RPAREN statement %prec LOWER_THAN_ELSE
	  {
	    	outlog<<"At line no: "<<lines<<" statement : IF LPAREN expression RPAREN statement "<<endl<<endl;
			outlog<<"if("<<$3->getname()<<")\n"<<$5->getname()<<endl<<endl;
			
			$$ = new symbol_info("if("+$3->getname()+")\n"+$5->getname(),"stmnt");
	  }
	  | IF LPAREN expression RPAREN statement ELSE statement
	  {
	    	outlog<<"At line no: "<<lines<<" statement : IF LPAREN expression RPAREN statement ELSE statement "<<endl<<endl;
			outlog<<"if("<<$3->getname()<<")\n"<<$5->getname()<<"\nelse\n"<<$7->getname()<<endl<<endl;
			
			$$ = new symbol_info("if("+$3->getname()+")\n"+$5->getname()+"\nelse\n"+$7->getname(),"stmnt");
	  }
	  | WHILE LPAREN expression RPAREN statement
	  {
	    	outlog<<"At line no: "<<lines<<" statement : WHILE LPAREN expression RPAREN statement "<<endl<<endl;
			outlog<<"while("<<$3->getname()<<")\n"<<$5->getname()<<endl<<endl;
			
			$$ = new symbol_info("while("+$3->getname()+")\n"+$5->getname(),"stmnt");
	  }
	  | PRINTLN LPAREN ID RPAREN SEMICOLON //edit
	  {
	    	outlog<<"At line no: "<<lines<<" statement : PRINTLN LPAREN ID RPAREN SEMICOLON "<<endl<<endl;
			outlog<<"printf("<<$3->getname()<<");"<<endl<<endl; 
			symbol_info* sym = table->lookup($3);
			if(sym == NULL) {
				errorlog << "At line no: " << lines << " Undeclared variable " << $3->getname() << endl << endl;
				error_count++;
			}
			$$ = new symbol_info("printf("+$3->getname()+");","stmnt");
	  }
	  | RETURN expression SEMICOLON 
	  {
	    	outlog<<"At line no: "<<lines<<" statement : RETURN expression SEMICOLON "<<endl<<endl;
			outlog<<"return "<<$2->getname()<<";"<<endl<<endl;
			
			$$ = new symbol_info("return "+$2->getname()+";","stmnt");
	  }
	  ;
	  
expression_statement : SEMICOLON
			{
				outlog<<"At line no: "<<lines<<" expression_statement : SEMICOLON "<<endl<<endl;
				outlog<<";"<<endl<<endl;
				
				$$ = new symbol_info(";","expr_stmt");
	        }			
			| expression SEMICOLON 
			{
				outlog<<"At line no: "<<lines<<" expression_statement : expression SEMICOLON "<<endl<<endl;
				outlog<<$1->getname()<<";"<<endl<<endl;
				
				$$ = new symbol_info($1->getname()+";","expr_stmt");
	        }
			;
	    
variable : ID 	//edit
      {
	    outlog<<"At line no: "<<lines<<" variable : ID "<<endl<<endl;
		outlog<<$1->getname()<<endl<<endl;
		symbol_info* sym = table->lookup($1);	
		$$ = new symbol_info($1->getname(),"varbl");
		if (sym != NULL) {
			$$->set_data_type(sym->get_data_type());
		}
		
	 }	
	 | ID LTHIRD expression RTHIRD 
	 {
	 	outlog<<"At line no: "<<lines<<" variable : ID LTHIRD expression RTHIRD "<<endl<<endl;
		outlog<<$1->getname()<<"["<<$3->getname()<<"]"<<endl<<endl;
		
		$$ = new symbol_info($1->getname()+"["+$3->getname()+"]","varbl");

		symbol_info temp($1->getname(), "ID");
		symbol_info* sym = table->lookup(&temp);
		if (sym == NULL) {
			errorlog << "At line no: " << lines << " Undeclared variable " << $1->getname() << endl << endl;
			error_count++;
		}
		else if (!sym->get_is_array()) {
		errorlog << "At line no: " << lines << " variable is not of array type : " << $1->getname() << endl << endl;
    	error_count++;
    	$$->set_data_type("error");
}
		if (sym != NULL && sym->get_is_array()) {
			$$->set_data_type(sym->get_data_type());
		}

		if($3->get_data_type() != "int") {
			errorlog << "At line no: " << lines << " array index is not of integer type : " << $1->getname() << endl << endl;
			error_count++;
			$$->set_data_type("error");
		}
		
		
	 }
	 ;
	 
expression : logic_expression
	   {
	    	outlog<<"At line no: "<<lines<<" expression : logic_expression "<<endl<<endl;
			outlog<<$1->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname(),"expr");
			$$->set_data_type($1->get_data_type());
	   }
	   | variable ASSIGNOP logic_expression 	
	   {
	    	outlog<<"At line no: "<<lines<<" expression : variable ASSIGNOP logic_expression "<<endl<<endl;
			outlog<<$1->getname()<<"="<<$3->getname()<<endl<<endl;


		    std::string var_name = $1->getname();
    		size_t bracket_pos = var_name.find('[');
    		if (bracket_pos != std::string::npos) {
        		var_name = var_name.substr(0, bracket_pos);
    		}	
			symbol_info temp(var_name, "ID");
			symbol_info* sym = table->lookup(&temp);
			if (sym == NULL) {
				errorlog << "At line no: " << lines << " Undeclared variable " << var_name << endl << endl;
        		error_count++;
			}

   			 if ($1->get_data_type() == "error" || $3->get_data_type() == "error") {
        		$$ = new symbol_info($1->getname() + "=" + $3->getname(), "expr");
        		$$->set_data_type($1->get_data_type());
    		} 
			else if ($1->get_data_type() == "void" || $3->get_data_type() == "void") {
        		errorlog << "At line no: " << lines << " operation on void type" << endl << endl;
        		error_count++;
        		$$ = new symbol_info($1->getname() + "=" + $3->getname(), "expr");
        		$$->set_data_type("error");
			}
    		else {
        
        		if ($1->get_data_type() == "int" && $3->get_data_type() == "float") {
            		errorlog << "At line no: " << lines << " Warning: Assignment of float value into variable of integer type" << endl << endl;
            		error_count++;
        		}
				else if ($1->get_data_type() == "int" && $3->get_data_type() != "int") {
            		errorlog << "At line no: " << lines << " Type mismatch on assignment to int variable" << endl << endl;
            		error_count++;
        		}
        
        		if (sym != NULL && sym->get_is_array()) {
            
            		if ($1->getname().find('[') == std::string::npos) {
                	errorlog << "At line no: " << lines << " variable is of array type : " << sym->getname() << endl << endl;
                	error_count++;
            		}
        		} 
				else if (sym != NULL && $1->get_data_type() != $3->get_data_type() && !($1->get_data_type() == "int" && $3->get_data_type() == "float")) {
            		errorlog << "At line no: " << lines << " variable is of " << $1->get_data_type() << " type : " << $1->getname() << endl << endl;
            		error_count++;
        		}

        		if ($3->get_data_type() == "bool" && $1->get_data_type() != "int") {
            		errorlog << "At line no: " << lines << " Result of relational/logical operation must be assigned to an int variable." << endl << endl;
            		error_count++;
        		}
			}	
			
			$$ = new symbol_info($1->getname()+"="+$3->getname(),"expr");
			$$->set_data_type($1->get_data_type());
	   }
	   ;
			
logic_expression : rel_expression
	     {
	    	outlog<<"At line no: "<<lines<<" logic_expression : rel_expression "<<endl<<endl;
			outlog<<$1->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname(),"lgc_expr");
			$$->set_data_type($1->get_data_type()); //edit
	     }	
		 | rel_expression LOGICOP rel_expression 
		 {
	    	outlog<<"At line no: "<<lines<<" logic_expression : rel_expression LOGICOP rel_expression "<<endl<<endl;
			outlog<<$1->getname()<<$2->getname()<<$3->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname()+$2->getname()+$3->getname(),"lgc_expr");
			$$->set_data_type("bool"); //edit
	     }	
		 ;
			
rel_expression	: simple_expression
		{
	    	outlog<<"At line no: "<<lines<<" rel_expression : simple_expression "<<endl<<endl;
			outlog<<$1->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname(),"rel_expr");
			$$->set_data_type($1->get_data_type()); //edit
	    }
		| simple_expression RELOP simple_expression
		{
	    	outlog<<"At line no: "<<lines<<" rel_expression : simple_expression RELOP simple_expression "<<endl<<endl;
			outlog<<$1->getname()<<$2->getname()<<$3->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname()+$2->getname()+$3->getname(),"rel_expr");
			$$->set_data_type("bool"); //edit
	    }
		;
				
simple_expression : term //edit
          {
	    	outlog<<"At line no: "<<lines<<" simple_expression : term "<<endl<<endl;
			outlog<<$1->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname(),"simp_expr");
			$$->set_data_type($1->get_data_type());
			
	      }
		  | simple_expression ADDOP term 
		  {
	    	outlog<<"At line no: "<<lines<<" simple_expression : simple_expression ADDOP term "<<endl<<endl;
			outlog<<$1->getname()<<$2->getname()<<$3->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname()+$2->getname()+$3->getname(),"simp_expr");
            if ($1->get_data_type() == "float" || $3->get_data_type() == "float")
                $$->set_data_type("float");
            else
                $$->set_data_type("int");			
	      }
		  ;
					
term :	unary_expression // edit
     {
	    	outlog<<"At line no: "<<lines<<" term : unary_expression "<<endl<<endl;
			outlog<<$1->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname(),"term");
			$$->set_data_type($1->get_data_type());
			
	 }
     |  term MULOP unary_expression
     {
	    	outlog<<"At line no: "<<lines<<" term : term MULOP unary_expression "<<endl<<endl;
			outlog<<$1->getname()<<$2->getname()<<$3->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname()+$2->getname()+$3->getname(),"term");

        	if ($1->get_data_type() == "void" || $3->get_data_type() == "void") {
            	errorlog << "At line no: " << lines << " operation on void type" << endl << endl;
            	error_count++;
            	$$->set_data_type("error");
        	} 
			else if ($2->getname() == "%") {
            	if ($1->get_data_type() != "int" || $3->get_data_type() != "int") {
                	errorlog << "At line no: " << lines << " Modulus operator on non integer type" << endl << endl;
                	error_count++;
            	}
            	if ($3->getname() == "0") {
                	errorlog << "At line no: " << lines << " Modulus by 0" << endl << endl;
                	error_count++;
            	}
            	$$->set_data_type("int");
        	} 
			else if ($2->getname() == "/" || $2->getname() == "*") {
            	if ($1->get_data_type() == "float" || $3->get_data_type() == "float")
                	$$->set_data_type("float");
            	else
                	$$->set_data_type("int");
        	} 
			else {
            	if ($1->get_data_type() == "float" || $3->get_data_type() == "float")
                	$$->set_data_type("float");
            	else
                	$$->set_data_type("int");
        	}			
			
	 }
     ;

unary_expression : ADDOP unary_expression  // edit
		 {
	    	outlog<<"At line no: "<<lines<<" unary_expression : ADDOP unary_expression "<<endl<<endl;
			outlog<<$1->getname()<<$2->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname()+$2->getname(),"un_expr");
			$$->set_data_type($2->get_data_type());
	     }
		 | NOT unary_expression 
		 {
	    	outlog<<"At line no: "<<lines<<" unary_expression : NOT unary_expression "<<endl<<endl;
			outlog<<"!"<<$2->getname()<<endl<<endl;
			
			$$ = new symbol_info("!"+$2->getname(),"un_expr");
			$$->set_data_type("bool");
	     }
		 | factor 
		 {
	    	outlog<<"At line no: "<<lines<<" unary_expression : factor "<<endl<<endl;
			outlog<<$1->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname(),"un_expr");
			
    		$$->set_data_type($1->get_data_type());
	     }
		 ;
	
factor	: variable //edit
    {
	    outlog<<"At line no: "<<lines<<" factor : variable "<<endl<<endl;
		outlog<<$1->getname()<<endl<<endl;
        std::string var_name = $1->getname();
        size_t bracket_pos = var_name.find('[');
        if (bracket_pos != std::string::npos) {
            var_name = var_name.substr(0, bracket_pos);
        }
        symbol_info temp(var_name, "ID");
        symbol_info* sym = table->lookup(&temp);
        if (!sym) {
            errorlog << "At line no: " << lines << " Undeclared variable " << var_name << endl << endl;
            error_count++;
        }					
		$$ = new symbol_info($1->getname(),"fctr");
		$$->set_data_type($1->get_data_type());
	}
	| ID LPAREN argument_list RPAREN
	{
	    outlog<<"At line no: "<<lines<<" factor : ID LPAREN argument_list RPAREN "<<endl<<endl;
		outlog<<$1->getname()<<"("<<$3->getname()<<")"<<endl<<endl;
		symbol_info temp($1->getname(), "ID");
		symbol_info* func = table->lookup(&temp);
		$$ = new symbol_info($1->getname()+"("+$3->getname()+")","fctr");

        if (!func) {
            errorlog << "At line no: " << lines << " Undeclared function: " << $1->getname() << endl << endl;
            error_count++;
            $$->set_data_type("error");
        } else if (!func->get_is_function()) {
            errorlog << "At line no: " << lines << " A function call cannot be made with non-function type identifier: " << $1->getname() << endl << endl;
            error_count++;
            $$->set_data_type("error");
        } else {
            if ($1->getname() == "printf" && (!func || !func->get_is_function())) {
                errorlog << "At line no: " << lines << " Undeclared function: printf" << endl << endl;
                error_count++;
                $$->set_data_type("error");
            }
            bool is_void_func = (func->get_data_type() == "void");
            if (is_void_func) {
                $$->set_data_type("void");
            }
            const std::vector<std::pair<std::string, std::string>>& params = func->get_parameters();
            std::vector<std::string> arg_types;
            std::string args_str = $3->get_data_type();
            std::stringstream ss(args_str);
            std::string item;
            while (std::getline(ss, item, ',')) {
                if (!item.empty()) arg_types.push_back(item);
            }
            if (arg_types.size() != params.size()) {
                if (!is_void_func || ($$->get_data_type() != "void")) {
                    errorlog << "At line no: " << lines << " Inconsistencies in number of arguments in function call: " << $1->getname() << endl << endl;
                    error_count++;
                    $$->set_data_type("error");
                }
            } else {
                std::vector<std::string> arg_names;
                std::string arg_names_str = $3->getname();
                std::stringstream name_ss(arg_names_str);
                std::string name_item;
                while (std::getline(name_ss, name_item, ',')) {
                    arg_names.push_back(name_item);
                }
                bool func_arg_error = false;
for (size_t i = 0; i < arg_types.size(); ++i) {

	std::string arg_name = (i < arg_names.size()) ? arg_names[i] : "?";

    if (params[i].first != "array" && arg_types[i] == "array") {
        
        errorlog << "At line no: " << lines << " variable is of array type : " << arg_name << endl << endl;
        error_count++;
        func_arg_error = true;
    }
    else if ((params[i].first == "int" || params[i].first == "float") && 
         (arg_types[i] == "int" || arg_types[i] == "float") &&
         params[i].first != arg_types[i]) {
        errorlog << "At line no: " << lines << " argument " << (i+1) << " type mismatch in function call: " << $1->getname() << endl << endl;
        error_count++;
        func_arg_error = true;
    }
}
if (func_arg_error) {
    $$->set_data_type("error");
}
            }
        }		
	}
	| LPAREN expression RPAREN
	{
	   	outlog<<"At line no: "<<lines<<" factor : LPAREN expression RPAREN "<<endl<<endl;
		outlog<<"("<<$2->getname()<<")"<<endl<<endl;
		
		$$ = new symbol_info("("+$2->getname()+")","fctr");
		$$->set_data_type($2->get_data_type());
	}
	| CONST_INT 
	{
	    outlog<<"At line no: "<<lines<<" factor : CONST_INT "<<endl<<endl;
		outlog<<$1->getname()<<endl<<endl;
			
		$$ = new symbol_info($1->getname(),"fctr");
		$$->set_data_type("int");
	}
	| CONST_FLOAT
	{
	    outlog<<"At line no: "<<lines<<" factor : CONST_FLOAT "<<endl<<endl;
		outlog<<$1->getname()<<endl<<endl;
			
		$$ = new symbol_info($1->getname(),"fctr");
		$$->set_data_type("float");
	}
	| variable INCOP 
	{
	    outlog<<"At line no: "<<lines<<" factor : variable INCOP "<<endl<<endl;
		outlog<<$1->getname()<<"++"<<endl<<endl;
			
		$$ = new symbol_info($1->getname()+"++","fctr");
	}
	| variable DECOP
	{
	    outlog<<"At line no: "<<lines<<" factor : variable DECOP "<<endl<<endl;
		outlog<<$1->getname()<<"--"<<endl<<endl;
			
		$$ = new symbol_info($1->getname()+"--","fctr");
	}
	;
	
argument_list : arguments
			  {
					outlog<<"At line no: "<<lines<<" argument_list : arguments "<<endl<<endl;
					outlog<<$1->getname()<<endl<<endl;
						
					$$ = new symbol_info($1->getname(),"arg_list");
					$$->set_data_type($1->get_data_type());
			  }
			  |
			  {
					outlog<<"At line no: "<<lines<<" argument_list :  "<<endl<<endl;
					outlog<<""<<endl<<endl;
						
					$$ = new symbol_info("","arg_list");
					$$->set_data_type("");
			  }
			  ;
	
arguments : arguments COMMA logic_expression
		  {
				outlog<<"At line no: "<<lines<<" arguments : arguments COMMA logic_expression "<<endl<<endl;
				outlog<<$1->getname()<<","<<$3->getname()<<endl<<endl;
						
				$$ = new symbol_info($1->getname()+","+$3->getname(),"arg");

				std::string arg_type = $3->get_data_type();
    			std::string arg_name = $3->getname();
				
				std::string base_var_name = arg_name;
    			size_t bracket_pos = base_var_name.find('[');
				if (bracket_pos != std::string::npos) {
						base_var_name = base_var_name.substr(0, bracket_pos);
				}
	


				symbol_info temp(base_var_name,"ID");
				symbol_info* s = table->lookup(&temp);
				if (s != NULL) {

				    if (arg_name.find('[') == std::string::npos && s->get_is_array()) {
						arg_type = "array"; 
					}
				}


				$$->set_data_type($1->get_data_type() + "," + arg_type);				
		  }
	      | logic_expression
	      {
				outlog<<"At line no: "<<lines<<" arguments : logic_expression "<<endl<<endl;
				outlog<<$1->getname()<<endl<<endl;
						
				$$ = new symbol_info($1->getname(),"arg");
				
				std::string arg_type = $1->get_data_type();
				std::string arg_name = $1->getname();

				    std::string base_var_name = arg_name;
    				size_t bracket_pos = base_var_name.find('[');
    				if (bracket_pos != std::string::npos) {
        				base_var_name = base_var_name.substr(0, bracket_pos);
    				}


				symbol_info temp(base_var_name,"ID");
				symbol_info* s = table->lookup(&temp);
    			if (!s) {	
					
					if (!arg_name.empty() && (isalpha(arg_name[0]) || arg_name[0] == '_')) {
        				errorlog << "At line no: " << lines << " Undeclared variable " << arg_name << endl << endl;
        				error_count++;
    			
					}

				
				 
				} else if (arg_name.find('[') == std::string::npos && s->get_is_array()) {
					    arg_type = "array";
				}


				$$->set_data_type(arg_type);				
		  }
	      ;
 

%%

int main(int argc, char *argv[])
{
	if(argc != 2) 
	{
		cout<<"Please input file name"<<endl;
		return 0;
	}
	yyin = fopen(argv[1], "r");
	outlog.open("24141164_22101142_log.txt", ios::trunc);
	errorlog.open("24141164_22101142_error.txt", ios::trunc);
	
	if(yyin == NULL)
	{
		cout<<"Couldn't open file"<<endl;
		return 0;
	}
	// Enter the global or the first scope here

	table = new symbol_table(10);  

	yyparse();

	delete table;
	
	outlog<<endl<<"Total lines: "<<lines<<endl;
	outlog << "Total errors: " << error_count << endl;
	outlog.close();
	
	errorlog << "Total errors: " << error_count << endl;
	errorlog.close();

	fclose(yyin);
	
	return 0;
}