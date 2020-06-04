module mkyd.lexer;

import std.ascii : isAlpha, isDigit, isWhite;
import std.conv : to;

import mkyd.token;

/// Parse a source string into tokens
class Lexer
{
public:
    // Make private?
    string input;
    int pos;
    int readPos;
    char ch;

    /// Create a new lexer from the source given
    this(string input)
    {
        this.input = input;
        readChar();
    }

    /// Returns: the next token in the source
    Token nextToken()
    {
        Token token;

        skipWhitespace();

        switch (ch)
        {
        case '"':
            auto strLiteral = readString();
            return Token(TokenType.STRING, strLiteral);
        case '=':
            if (peekChar() == '=')
            {
                token = Token(TokenType.EQ, "==");
                readChar();
            }
            else
            {
                token = single(TokenType.ASSIGN);
            }
            break;
        case '!':
            if (peekChar() == '=')
            {
                token = Token(TokenType.NOT_EQ, "!=");
                readChar();
            }
            else
            {
                token = single(TokenType.BANG);
            }
            break;
        case '+':
            token = single(TokenType.PLUS);
            break;
        case '-':
            token = single(TokenType.MINUS);
            break;
        case '/':
            token = single(TokenType.SLASH);
            break;
        case '*':
            token = single(TokenType.STAR);
            break;
        case '<':
            token = single(TokenType.LT);
            break;
        case '>':
            token = single(TokenType.GT);
            break;
        case ',':
            token = single(TokenType.COMMA);
            break;
        case ';':
            token = single(TokenType.SEMICOLON);
            break;
        case ':':
            token = single(TokenType.COLON);
            break;
        case '(':
            token = single(TokenType.LPAREN);
            break;
        case ')':
            token = single(TokenType.RPAREN);
            break;
        case '{':
            token = single(TokenType.LBRACE);
            break;
        case '}':
            token = single(TokenType.RBRACE);
            break;
        case '[':
            token = single(TokenType.LBRACKET);
            break;
        case ']':
            token = single(TokenType.RBRACKET);
            break;
        case '\0': // EOF
            token = Token(TokenType.EOF, "");
            break;
        default:
            if (isAlpha(ch)) // Handle identifiers/names
            {
                string literal = readIdentifer();
                TokenType type = lookupIdentifer(literal);
                return Token(type, literal);
            }
            else if (isDigit(ch)) // Handle numbers
            {
                string number = readNumber();
                return Token(TokenType.INT, number);
            }
            else // Uh oh
            {
                token = single(TokenType.ILLEGAL);
            }
        }

        readChar();

        return token;
    }

private:

    // Is this cursed?
    static this()
    {
        KEYWORDS = [
            "fn": TokenType.FUNCTION,
            "let": TokenType.LET,
            "true": TokenType.TRUE,
            "false": TokenType.FALSE,
            "if": TokenType.IF,
            "else": TokenType.ELSE,
            "return": TokenType.RETURN
        ];
    }

    static TokenType[string] KEYWORDS;

    static TokenType lookupIdentifer(string literal)
    {
        return KEYWORDS.get(literal, TokenType.IDENT);
    }

    /// Helper function to create single-char tokens easier
    Token single(TokenType t)
    {
        // Maybe try just [ch] instead of to!string(ch)?
        return Token(t, to!string(ch));
    }

    /// Increment lexer pos until we're not at whitespace
    void skipWhitespace()
    {
        while (isWhite(ch))
        {
            readChar();
        }
    }

    void readChar()
    {
        if (readPos >= input.length)
        {
            ch = '\0';
        }
        else
        {
            ch = input[readPos];
        }

        pos = readPos;
        readPos += 1;
    }

    string readString()
    {
        immutable startPos = pos + 1;
        while (true)
        {
            readChar();
            if (ch == '"' || ch == '\0')
            {
                break;
            }
        }

        string slice = input[startPos .. pos];
        readChar();
        return slice;
    }

    char peekChar()
    {
        if (readPos >= input.length)
        {
            return '\0';
        }
        else
        {
            return input[readPos];
        }
    }

    string readIdentifer()
    {
        immutable int prevPos = pos;

        while (isAlpha(ch))
        {
            readChar();
        }

        return input[prevPos .. pos];
    }

    string readNumber()
    {
        immutable int prevPos = pos;

        while (isDigit(ch))
        {
            readChar();
        }

        return input[prevPos .. pos];
    }
}
