# Language Specification

    module     -> function* ;

    function    -> "fn" identifier "(" parameters? ")" "->" type block ;

    parameters  -> identifier ":" type ( "," identifier ":" type )* ;

    block       -> "{" statement* "}" ;

    statement   -> return_statement
                | expression_statement ;

    return_statement  -> "return" ";" ;

    expression_statement  -> call ;

    cal         -> identifier "(" arguments? ")" ";" ;

    arguments   -> expression ( "," expression )* ;

    type        -> "nil" ;

## Keywords

- `fn`
- `nil`
- `return`

## Main function

An application must contain exactly on function called `main` in one of its
modules with the signature `fn main() -> nil`.
