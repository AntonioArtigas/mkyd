module tests.lexertest;

import std.stdio : writeln;

import mkyd.token;
import mkyd.lexer;

/// Utility function to compare tokens parsed by a lexer to the expected ones
private bool compareTokens(ref Lexer lexer, const ref Token[] expectedTokens)
{
    foreach (t; expectedTokens) {
        immutable token = lexer.nextToken();

        // writeln(tcoken); // for debug

        if (token.type != t.type)
        {
            return false;
        }
    }

    return true;
}

// Single tokens
unittest {
    immutable string input = "=+(){},;";

    immutable Token[] expectedTokens = [
        Token(TokenType.ASSIGN, "="),
        Token(TokenType.PLUS, "+"),
        Token(TokenType.LPAREN, "("),
        Token(TokenType.RPAREN, ")"),
        Token(TokenType.LBRACE, "{"),
        Token(TokenType.RBRACE, "}"),
        Token(TokenType.COMMA, ","),
        Token(TokenType.SEMICOLON, ";")
    ];

    Lexer lexer = new Lexer(input);

    assert(compareTokens(lexer, expectedTokens));
}

unittest {
    immutable string input = "-!*/<>";

    immutable Token[] expectedTokens = [
        Token(TokenType.MINUS, "-"),
        Token(TokenType.BANG, "!"),
        Token(TokenType.STAR, "*"),
        Token(TokenType.SLASH, "/"),
        Token(TokenType.LT, "<"),
        Token(TokenType.GT, ">"),
    ];

    Lexer lexer = new Lexer(input);

    assert(compareTokens(lexer, expectedTokens));
}

// Simple statement
unittest {
    immutable string input = "let bruh = 64;";

    immutable Token[] expectedTokens = [
        Token(TokenType.LET, "let"),
        Token(TokenType.IDENT, "bruh"),
        Token(TokenType.ASSIGN, "="),
        Token(TokenType.INT, "64"),
        Token(TokenType.SEMICOLON, ";")
    ];

    Lexer lexer = new Lexer(input);

    assert(compareTokens(lexer, expectedTokens));
}

// function decl
unittest {
    immutable string input = "let add = fn (a, b) { a + b; };";

    immutable Token[] expectedTokens = [
        Token(TokenType.LET, "let"),
        Token(TokenType.IDENT, "add"),
        Token(TokenType.ASSIGN, "="),
        Token(TokenType.FUNCTION, "fn"),
        Token(TokenType.LPAREN, "("),
        Token(TokenType.IDENT, "a"),
        Token(TokenType.COMMA, ","),
        Token(TokenType.IDENT, "b"),
        Token(TokenType.RPAREN, ")"),
        Token(TokenType.LBRACE, "{"),
        Token(TokenType.IDENT, "a"),
        Token(TokenType.PLUS, "+"),
        Token(TokenType.IDENT, "b"),
        Token(TokenType.SEMICOLON, ";"),
        Token(TokenType.RBRACE, "}"),
        Token(TokenType.SEMICOLON, ";")
    ];

    Lexer lexer = new Lexer(input);

    assert(compareTokens(lexer, expectedTokens));
}

unittest {
    immutable string input = "== !=";

    immutable Token[] expectedTokens = [
        Token(TokenType.EQ, "=="),
        Token(TokenType.NOT_EQ, "!=")
    ];

    Lexer lexer = new Lexer(input);

    assert(compareTokens(lexer, expectedTokens));
}