# Language Specification

    module      -> function* ;

    function    -> "fn" identifier "(" parameters? ")" "->" type block ;

    parameters  -> identifier ":" type ( "," identifier ":" type )* ;

    block       -> "{" statement* "}" ;

    statement   -> return_statement
                | expression_statement ;

    return_statement  -> "return" expression? ";" ;

    expression_statement  -> call ;

    call        -> identifier "(" arguments? ")" ";" ;

    arguments   -> expression ( "," expression )* ;

    type        -> "void" ;

    expression  -> ... ;

## Keywords

- `fn`
- `void`
- `return`

## Main function

An application must contain exactly on function called `main` in one of its
modules with the signature `fn main() -> void`.
