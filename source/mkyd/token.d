module mkyd.token;

/// Denotes the type of a token
enum TokenType
{
    ILLEGAL,
    EOF, // End Of File

    // Strings, identifiers and literals
    IDENT, // foo
    INT, // 123
    STRING, // "bruh"
    
    // Operators
    ASSIGN, // =
    PLUS, // +
    MINUS, // -
    BANG, // !
    SLASH, // /
    STAR, // *
    LT, // <
    GT, // >
    EQ, // ==
    NOT_EQ, // !=


    // Delimeters
    COMMA, // ,
    SEMICOLON, // ;
    COLON, // :

    LPAREN, // (
    RPAREN, // )
    LBRACE, // {
    RBRACE, // }
    LBRACKET, // [
    RBRACKET, // ]

    // Keywords
    FUNCTION, // fn bar(...)
    LET, // let
    TRUE,
    FALSE,
    IF,
    ELSE,
    RETURN // return
}

/// Represents a simple lexical token
struct Token
{
    /// Type of token
    TokenType type;

    /// String that makes up the token
    string literal;
}
