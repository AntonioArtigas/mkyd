module mkyd.ast;

import std.algorithm;
import std.array : appender, join;

import mkyd.token;

/// Discern between the different kinds of nodes
enum NodeType
{
    PROGRAM,
    IDENTIFER,
    LET,
    RETURN,
    EXPRESSION,
    INTEGER,
    PREFIX,
    INFIX,
    BOOL,
    IF,
    BLOCK,
    FUNCTION,
    CALL,
    STRING,
    ARRAY,
    INDEX, // For arrays
    HASH
}

/// A node within the AST
interface Node
{
    /// Return string representation of token
    string tokenLiteral();

    /// Debug string representation
    string nodeString();

    /// Returns: Type of node via NodeType enum
    NodeType type();
}

/// Statments do not evaluate to a value
interface Statement : Node
{
}

/// Expressions evaluate to a value
interface Expression : Node
{
}

/// Base node of the ast
class Program : Node
{
    string tokenLiteral()
    {
        if (statements.length > 0)
        {
            return statements[0].tokenLiteral();
        }
        else
        {
            return "";
        }
    }

    Statement[] statements;

    string nodeString()
    {
        auto buffer = appender!string;

        foreach (stmt; statements)
        {
            buffer.put(stmt.nodeString());
        }

        return buffer.data;
    }

    NodeType type()
    {
        return NodeType.PROGRAM;
    }
}

/// A named expression, variable binding
class Identifier : Expression
{
    Token token;
    string value;

    /// Create a new identifier
    this(Token token, string value)
    {
        this.token = token;
        this.value = value;
    }

    string tokenLiteral()
    {
        return token.literal;
    }

    string nodeString()
    {
        return value;
    }

    NodeType type()
    {
        return NodeType.IDENTIFER;
    }
}

/// let <name> = <expression>
class LetStatement : Statement
{
    Token token;
    Identifier ident;
    Expression value;

    this(Token token, Identifier ident, Expression value)
    {
        this.token = token;
        this.ident = ident;
        this.value = value;
    }

    string tokenLiteral()
    {
        return token.literal;
    }

    string nodeString()
    {
        auto buffer = appender!string;

        buffer.put(tokenLiteral ~ " ");
        buffer.put(ident.nodeString());
        buffer.put(" = ");
        buffer.put((value !is null)
                ? value.nodeString() : "null");

        return buffer.data;
    }

    NodeType type()
    {
        return NodeType.LET;
    }
}

/// return <expression>
class ReturnStatement : Statement
{
    Token token;
    Expression returnValue;

    this(Token token, Expression returnValue)
    {
        this.token = token;
        this.returnValue = returnValue;
    }

    string tokenLiteral()
    {
        return token.literal;
    }

    string nodeString()
    {
        auto buffer = appender!string;

        buffer.put(tokenLiteral ~ " ");
        buffer.put((returnValue !is null)
                ? returnValue.tokenLiteral : "null");

        buffer.put(";");

        return buffer.data;
    }

    NodeType type()
    {
        return NodeType.RETURN;
    }
}

class ExpressionStatement : Statement
{
    Token token;
    Expression expression;

    this(Token token, Expression expression)
    {
        this.token = token;
        this.expression = expression;
    }

    string tokenLiteral()
    {
        return token.literal;
    }

    string nodeString()
    {
        return (expression !is null) ? expression.nodeString()
            : "null";
    }

    NodeType type()
    {
        return NodeType.EXPRESSION;
    }
}

/// IntegerValue on the AST
class IntegerLiteral : Expression
{
    Token token;
    int value;

    this(Token token, int value)
    {
        this.token = token;
        this.value = value;
    }

    string tokenLiteral()
    {
        return token.literal;
    }

    string nodeString()
    {
        return token.literal;
    }

    NodeType type()
    {
        return NodeType.INTEGER;
    }
}

/// Stuff like (!foo) and (-bar)
class PrefixExpression : Expression
{
    /// Prefix like
    Token token;
    string operator;
    Expression right;

    this(Token token, string operator, Expression right)
    {
        this.token = token;
        this.operator = operator;
        this.right = right;
    }

    string tokenLiteral()
    {
        return token.literal;
    }

    string nodeString()
    {
        auto buffer = appender!string;

        buffer.put("(");
        buffer.put(operator);
        buffer.put(right.nodeString());
        buffer.put(")");

        return buffer.data;
    }

    NodeType type()
    {
        return NodeType.PREFIX;
    }
}

/// Stuff like (foo + bar) and (baz * bam) 
class InfixExpression : Expression
{
    Token token;
    Expression left;
    string operator;
    Expression right;

    this(Token token, Expression left,
            string operator, Expression right)
    {
        this.token = token;
        this.left = left;
        this.operator = operator;
        this.right = right;
    }

    string tokenLiteral()
    {
        return token.literal;
    }

    string nodeString()
    {
        auto buffer = appender!string;

        buffer.put("(");
        buffer.put(left.nodeString());
        buffer.put(" " ~ operator ~ " ");
        buffer.put(right.nodeString());
        buffer.put(")");

        return buffer.data;
    }

    NodeType type()
    {
        return NodeType.INFIX;
    }
}

class BooleanLiteral : Expression
{
    Token token;
    bool value;

    this(Token token, bool value)
    {
        this.token = token;
        this.value = value;
    }

    string tokenLiteral()
    {
        return token.literal;
    }

    string nodeString()
    {
        return token.literal;
    }

    NodeType type()
    {
        return NodeType.BOOL;
    }
}

class IfExpression : Expression
{
    Token token;
    Expression condition;
    BlockStatement consequence;
    BlockStatement alternative;

    this(Token token, Expression condition,
            BlockStatement consequence,
            BlockStatement alternative)
    {
        this.token = token;
        this.condition = condition;
        this.consequence = consequence;
        this.alternative = alternative;
    }

    string tokenLiteral()
    {
        return token.literal;
    }

    string nodeString()
    {
        auto buffer = appender!string;

        buffer.put("if");
        buffer.put(condition.nodeString());
        buffer.put(" ");
        buffer.put(consequence.nodeString());

        if (alternative !is null)
        {
            buffer.put("else ");
            buffer.put(alternative.nodeString());
        }

        return buffer.data;
    }

    NodeType type()
    {
        return NodeType.IF;
    }
}

/// A bunch of statements that go together
class BlockStatement : Statement
{
    /// { token
    Token token;
    Statement[] statements;

    this(Token token, Statement[] statements)
    {
        this.token = token;
        this.statements = statements;
    }

    string tokenLiteral()
    {
        return token.literal;
    }

    string nodeString()
    {
        auto buffer = appender!string;

        foreach (Statement stmt; statements)
        {
            buffer.put(stmt.nodeString());
        }

        return buffer.data;
    }

    NodeType type()
    {
        return NodeType.BLOCK;
    }
}

class FunctionLiteral : Expression
{

    /// "fn" token
    Token token;
    Identifier[] params;
    BlockStatement body;

    this(Token token, Identifier[] params,
            BlockStatement body)
    {
        this.token = token;
        this.params = params;
        this.body = body;
    }

    string tokenLiteral()
    {
        return token.literal;
    }

    string nodeString()
    {
        auto buffer = appender!string;

        buffer.put(tokenLiteral());
        buffer.put("(");

        foreach (Identifier ident; params)
        {
            buffer.put(ident.nodeString());
        }

        buffer.put(")");
        buffer.put(body.nodeString());

        return buffer.data;
    }

    NodeType type()
    {
        return NodeType.FUNCTION;
    }
}

class CallExpression : Expression
{

    Token token;
    Expression func;
    Expression[] arguments;

    this(Token token, Expression func,
            Expression[] arguments)
    {
        this.token = token;
        this.func = func;
        this.arguments = arguments;
    }

    string tokenLiteral()
    {
        return token.literal;
    }

    string nodeString()
    {
        auto buffer = appender!string;

        buffer.put(func.nodeString());
        buffer.put("(");
        foreach (Expression arg; arguments)
        {
            buffer.put(arg.nodeString() ~ ", ");
        }
        buffer.put(")");

        // FIXME: Read the docs, replace instances of buffer.data with buffer[];
        return buffer.data;
    }

    NodeType type()
    {
        return NodeType.CALL;
    }
}

class StringLiteral : Expression
{
    Token token;
    string value;

    this(Token token, string value)
    {
        this.token = token;
        this.value = value;
    }

    string tokenLiteral()
    {
        return token.literal;
    }

    string nodeString()
    {
        return token.literal;
    }

    NodeType type()
    {
        return NodeType.STRING;
    }
}

class ArrayLiteral : Expression
{
    Token token; // '[' token
    Expression[] elements;

    this(Token token, Expression[] elements)
    {
        this.token = token;
        this.elements = elements;
    }

    string tokenLiteral()
    {
        return token.literal;
    }

    string nodeString()
    {
        auto buffer = appender!string;

        buffer.put("[");
        foreach (key; elements)
        {
            buffer.put(key.nodeString());
            buffer.put(", ");
        }
        buffer.put("]");

        return buffer.data;
    }

    NodeType type()
    {
        return NodeType.ARRAY;
    }
}

class IndexExpression : Expression
{
    Token token;
    Expression left;
    Expression index;

    this(Token token, Expression left, Expression index)
    {
        this.token = token;
        this.left = left;
        this.index = index;
    }

    NodeType type()
    {
        return NodeType.INDEX;
    }

    string tokenLiteral()
    {
        return token.literal;
    }

    string nodeString()
    {
        auto buffer = appender!string;

        buffer.put("(");
        buffer.put(left.nodeString());
        buffer.put(")");
        buffer.put("[");
        buffer.put(index.nodeString());
        buffer.put("])");

        return buffer.data;
    }
}

class HashLiteral : Expression
{
    Token token;
    Expression[Expression] pairs;

    this(Token token, Expression[Expression] pairs)
    {
        this.token = token;
        this.pairs = pairs;
    }

    NodeType type()
    {
        return NodeType.HASH;
    }

    string tokenLiteral()
    {
        return token.literal;
    }

    string nodeString()
    {
        auto buffer = appender!string;

        foreach (pair; pairs.byKeyValue())
        {
            buffer.put(pair.key.nodeString() ~ " : " ~ pair.value.nodeString() ~ ", ");
        }

        return buffer.data;
    }
}