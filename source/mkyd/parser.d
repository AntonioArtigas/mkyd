module mkyd.parser;

import std.conv : to, ConvException;
import std.format : format;

import mkyd.lexer;
import mkyd.token;
import mkyd.ast;

alias PrefixParseFn = Expression delegate();
alias InfixParseFn = Expression delegate(Expression);

/// Determines a tokens precedence in parsing
enum Precedence : uint
{
    LOWEST = 0,
    EQUALS,
    LESSGREATER,
    SUM,
    PRODUCT,
    PREFIX,
    CALL,
    INDEX
}

class Parser
{
public:
    /// Create a new Parse using the lexer given
    this(Lexer* lexer)
    {
        precedences = [
            TokenType.EQ : Precedence.EQUALS,
            TokenType.NOT_EQ : Precedence.EQUALS,
            TokenType.LT : Precedence.LESSGREATER,
            TokenType.GT : Precedence.LESSGREATER,
            TokenType.PLUS : Precedence.SUM,
            TokenType.MINUS : Precedence.SUM,
            TokenType.SLASH : Precedence.PRODUCT,
            TokenType.STAR : Precedence.PRODUCT,
            TokenType.LPAREN : Precedence.CALL,
            TokenType.LBRACKET : Precedence.INDEX
        ];

        registerPrefix(TokenType.IDENT, &parseIdentifier);
        registerPrefix(TokenType.INT, &parseIntegerLiteral);
        registerPrefix(TokenType.TRUE, &parseBoolean);
        registerPrefix(TokenType.FALSE, &parseBoolean);
        registerPrefix(TokenType.LPAREN, &parsedGroupedExpression);
        registerPrefix(TokenType.IF, &parseIfExpression);
        registerPrefix(TokenType.FUNCTION, &parseFunctionLiteral);
        registerPrefix(TokenType.BANG, &parsePrefixExpression);
        registerPrefix(TokenType.MINUS, &parsePrefixExpression);
        registerPrefix(TokenType.STRING, &parseStringLiteral);
        registerPrefix(TokenType.LBRACKET, &parseArrayLiteral);
        registerPrefix(TokenType.LBRACE, &parseHashLiteral);

        registerInfix(TokenType.PLUS, &parseInfixExpression);
        registerInfix(TokenType.MINUS, &parseInfixExpression);
        registerInfix(TokenType.SLASH, &parseInfixExpression);
        registerInfix(TokenType.STAR, &parseInfixExpression);
        registerInfix(TokenType.EQ, &parseInfixExpression);
        registerInfix(TokenType.NOT_EQ, &parseInfixExpression);
        registerInfix(TokenType.LT, &parseInfixExpression);
        registerInfix(TokenType.GT, &parseInfixExpression);
        registerInfix(TokenType.LPAREN, &parseCallExpression);
        registerInfix(TokenType.LBRACKET, &parseIndexExpression);

        this.lexer = lexer;
        curToken = lexer.nextToken();
        peekToken = lexer.nextToken();
    }

    Program parseProgram()
    {
        Program program = new Program();

        while (curToken.type != TokenType.EOF)
        {
            auto stmt = parseStatement();
            if (stmt !is null)
            {
                program.statements ~= stmt;
            }
            nextToken();
        }

        return program;
    }

    string[] errors;

private:
    /// Lexer to extract tokens from
    Lexer* lexer;

    /// Current token being inspected
    Token curToken;

    /// Token ahead of curToken
    Token peekToken;

    PrefixParseFn[TokenType] prefixParseFns;
    InfixParseFn[TokenType] infixParseFns;

    Precedence[TokenType] precedences;

    void registerPrefix(TokenType type, PrefixParseFn fn)
    {
        prefixParseFns[type] = fn;
    }

    void registerInfix(TokenType type, InfixParseFn fn)
    {
        infixParseFns[type] = fn;
    }

    void nextToken()
    {
        curToken = peekToken;
        peekToken = lexer.nextToken();
    }

    void peekError(TokenType type)
    {
        auto msg = format("expected next token to be %s, got %s instead",
                type, peekToken.type);
        errors ~= msg;
    }

    /// Returns: Whether current token is of type given
    bool curTokenIs(TokenType type)
    {
        return curToken.type == type;
    }

    /// Returns: Whether the next token is of type given
    bool peekTokenIs(TokenType type)
    {
        return peekToken.type == type;
    }

    bool expectPeek(TokenType expected)
    {
        if (peekTokenIs(expected))
        {
            nextToken();
            return true;
        }
        else
        {
            peekError(expected);
            return false;
        }
    }

    Expression parseIntegerLiteral()
    {
        auto intToken = curToken;

        try
        {
            auto value = to!int(intToken.literal);
            return new IntegerLiteral(intToken, value);
        }
        catch (ConvException e)
        {
            errors ~= format("literal %s is not valid integer", intToken.literal);
            return null;
        }
    }

    Expression parseIdentifier()
    {
        return new Identifier(curToken, curToken.literal);
    }

    Expression parsePrefixExpression()
    {
        auto prefixToken = curToken;
        auto operator = curToken.literal;

        nextToken();

        auto exprRight = parseExpression(Precedence.PREFIX);

        return new PrefixExpression(prefixToken, operator, exprRight);
    }

    Expression parseInfixExpression(Expression left)
    {
        auto infixToken = curToken;
        auto operator = curToken.literal;

        auto prec = curPrecedence();
        nextToken();

        return new InfixExpression(
            infixToken, left, operator, parseExpression(prec)
        );
    }

    Expression parseBoolean()
    {
        return new BooleanLiteral(curToken, curTokenIs(TokenType.TRUE));
    }

    // V2 of method
    Expression parseExpression(Precedence pre)
    {
        immutable prefix = prefixParseFns.get(curToken.type, null);
        if (prefix is null)
        {
            errors ~= format("no prefix parse function for %s found", curToken.type);
            return null;
        }

        auto leftExpr = prefix();

        while (!peekTokenIs(TokenType.SEMICOLON) && pre < peekPrecedence())
        {
            immutable infix = infixParseFns[peekToken.type];
            if (infix is null)
            {
                return leftExpr;
            }

            nextToken();

            leftExpr = infix(leftExpr);
        }

        return leftExpr;
    }

    LetStatement parseLetStatement()
    {
        auto letToken = curToken;

        if (!expectPeek(TokenType.IDENT))
        {
            return null;
        }

        auto nameStmt = new Identifier(curToken,
                curToken.literal);

        if (!expectPeek(TokenType.ASSIGN))
        {
            return null;
        }

        nextToken();

        auto stmtVal = parseExpression(Precedence.LOWEST);

        if (peekTokenIs(TokenType.SEMICOLON))
        {
            nextToken();
        }

        return new LetStatement(letToken, nameStmt, stmtVal);
    }

    ReturnStatement parseReturnStatement()
    {
        auto retToken = curToken;

        nextToken();

        auto retValue = parseExpression(Precedence.LOWEST);

        if (peekTokenIs(TokenType.SEMICOLON))
        {
            nextToken();
        }

        return new ReturnStatement(retToken, retValue);
    }

    ExpressionStatement parseExpressionStatement()
    {
        auto exprToken = curToken;

        auto expr = parseExpression(Precedence.LOWEST);

        if (peekTokenIs(TokenType.SEMICOLON))
        {
            nextToken();
        }

        return new ExpressionStatement(exprToken, expr);
    }

    Expression parsedGroupedExpression()
    {
        nextToken();

        auto expr = parseExpression(Precedence.LOWEST);

        if (!expectPeek(TokenType.RPAREN))
        {
            return null;
        }

        return expr;
    }

    Expression parseIfExpression()
    {
        auto ifToken = curToken;

        if (!expectPeek(TokenType.LPAREN))
        {
            return null;
        }

        nextToken();

        auto cond = parseExpression(Precedence.LOWEST);

        if (!expectPeek(TokenType.RPAREN))
        {
            return null;
        }

        if (!expectPeek(TokenType.LBRACE))
        {
            return null;
        }

        auto cons = parseBlockStatement();

        // Handle an if else expression
        if (peekTokenIs(TokenType.ELSE))
        {
            nextToken();

            if (!expectPeek(TokenType.LBRACE))
            {
                return null;
            }

            return new IfExpression(ifToken, cond, cons, parseBlockStatement());
        }

        return new IfExpression(ifToken, cond, cons, null);
    }

    BlockStatement parseBlockStatement()
    {
        auto blockToken = curToken;
        Statement[] stmts = [];

        nextToken();

        while (!curTokenIs(TokenType.RBRACE) && !curTokenIs(TokenType.EOF))
        {
            auto stmt = parseStatement();
            if (stmt !is null)
            {
                stmts ~= stmt;
            }
            nextToken();
        }

        return new BlockStatement(blockToken, stmts);
    }

    Identifier[] parseFunctionParameters()
    {
        Identifier[] params = [];

        if (peekTokenIs(TokenType.RPAREN))
        {
            nextToken();
            return params;
        }

        nextToken();

        params ~= new Identifier(curToken, curToken.literal);

        while (peekTokenIs(TokenType.COMMA))
        {
            nextToken(); // skip cur arg
            nextToken(); // skip comma

            params ~= new Identifier(curToken, curToken.literal);
        }

        if (!expectPeek(TokenType.RPAREN))
        {
            return null;
        }

        return params;
    }

    Expression parseFunctionLiteral()
    {
        auto fnToken = curToken;

        if (!expectPeek(TokenType.LPAREN))
        {
            return null;
        }

        auto params = parseFunctionParameters();

        if (!expectPeek(TokenType.LBRACE))
        {
            return null;
        }

        auto body = parseBlockStatement();

        return new FunctionLiteral(fnToken, params, body);
    }

    Expression parseCallExpression(Expression func)
    {
        return new CallExpression(
            curToken, func, parseExpressionList(TokenType.RPAREN)
        );
    }

    Expression parseIndexExpression(Expression left)
    {
        auto lBracket = curToken;
        nextToken();

        auto index = parseExpression(Precedence.LOWEST);

        if (!expectPeek(TokenType.RBRACKET))
        {
            return null;
        }

        return new IndexExpression(lBracket, left, index);
    }

    /// Deprecated
    Expression[] parseCallArguments()
    {
        Expression[] args = [];

        if (peekTokenIs(TokenType.RPAREN))
        {
            nextToken();
            return args;
        }

        nextToken();
        args ~= parseExpression(Precedence.LOWEST);

        while (peekTokenIs(TokenType.COMMA))
        {
            nextToken();
            nextToken();
            args ~= parseExpression(Precedence.LOWEST);
        }

        if (!expectPeek(TokenType.RPAREN))
        {
            return null;
        }

        return args;
    }

    Statement parseStatement()
    {
        switch (curToken.type)
        {
        case TokenType.LET:
            return parseLetStatement();
        case TokenType.RETURN:
            return parseReturnStatement();
        default:
            return parseExpressionStatement();
        }
    }

    Expression parseStringLiteral()
    {
        return new StringLiteral(curToken, curToken.literal);
    }

    Expression[] parseExpressionList(TokenType end)
    {
        Expression[] list = [];

        if (peekTokenIs(end))
        {
            nextToken();
            return list;
        }

        nextToken();
        list ~= parseExpression(Precedence.LOWEST);

        while (peekTokenIs(TokenType.COMMA))
        {
            nextToken();
            nextToken();
            list ~= parseExpression(Precedence.LOWEST);
        }

        if (!expectPeek(end))
        {
            return null;
        }

        return list;
    }

    Expression parseArrayLiteral()
    {
        auto leftBracket = curToken;

        auto arrElements = parseExpressionList(TokenType.RBRACKET);

        return new ArrayLiteral(leftBracket, arrElements);
    }

    Expression parseHashLiteral()
    {
        auto lBrace = curToken;
        Expression[Expression] pairs;
        while (!peekTokenIs(TokenType.RBRACE))
        {
            nextToken();
            auto key = parseExpression(Precedence.LOWEST);
            if (!expectPeek(TokenType.COLON))
            {
                return null;
            }

            nextToken();

            auto value = parseExpression(Precedence.LOWEST);
            pairs[key] = value;

            if (!peekTokenIs(TokenType.RBRACE) && !expectPeek(TokenType.COMMA))
            {
                return null;
            }
        }

        if (!expectPeek(TokenType.RBRACE))
        {
            return null;
        }

        return new HashLiteral(lBrace, pairs);
    }

    Precedence peekPrecedence()
    {
        if (peekToken.type in precedences)
        {
            return precedences[peekToken.type];
        }

        return Precedence.LOWEST;
    }

    Precedence curPrecedence()
    {
        if (curToken.type in precedences)
        {
            return precedences[curToken.type];
        }

        return Precedence.LOWEST;
    }
}
