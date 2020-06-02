module mkyd.eval;

import std.conv : to;
import std.stdio;

import mkyd.ast;
import mkyd.environment;
import mkyd.object;

private static BooleanValue TRUE;
private static BooleanValue FALSE;
private static NullValue NULL;

private static BuiltinFunction[string] BUILTINS;

static this()
{
    TRUE = new BooleanValue(true);
    FALSE = new BooleanValue(false);
    NULL = new NullValue();
    BUILTINS = [
        "len": new BuiltinFunction(&mkyLen),
        "puts": new BuiltinFunction(&mkyPuts)
    ];
}

// TODO: Move to builtin.d file
private MkyObject mkyLen(MkyObject[] args...)
{
    if (args.length != 1)
    {
        return ErrorObject.newError("Wrong number of args: got %d, expected %1", args.length);
    }

    auto firstArg = args[0];
    switch (firstArg.type())
    {
        case MkyObjectType.STRING:
            StringObject strObj = cast(StringObject) firstArg;
            return new IntegerValue(cast(int) strObj.value.length);
        
        case MkyObjectType.ARRAY:
            ArrayObject arrObj = cast(ArrayObject) firstArg;
            return new IntegerValue(cast(int) arrObj.elements.length);
        
        default:
            return ErrorObject.newError("Argument to `len` not supported, got %s", firstArg.type());
    }
}

private MkyObject mkyPuts(MkyObject[] args...)
{
    foreach (arg; args)
    {
        writeln(arg.inspect());
    }
    
    return NULL;
}

/// Evaulate a node
MkyObject eval(Node node, Environment env)
{
    switch (node.type())
    {
        // Statements
        case NodeType.PROGRAM:
            Program p = cast(Program) node;
            return evalProgram(p, env);
        
        case NodeType.EXPRESSION: // ExpressionStatement
            ExpressionStatement es = cast(ExpressionStatement) node;
            return eval(es.expression, env);

        case NodeType.RETURN:
            ReturnStatement rs = cast(ReturnStatement) node;
            auto returnVal = eval(rs.returnValue, env);
            return (isError(returnVal))
                ? returnVal
                : new ReturnValue(returnVal);

        case NodeType.LET:
            LetStatement ls = cast(LetStatement) node;
            auto letVal = eval(ls.value, env);
            if (isError(letVal))
            {
                return letVal;
            }

            return env.set(ls.ident.value, letVal);

        // Expressions
        case NodeType.IDENTIFER:
            Identifier id = cast(Identifier) node;
            return evalIdentifier(id, env);

        case NodeType.INTEGER:
            IntegerLiteral il = cast(IntegerLiteral) node;
            return new IntegerValue(il.value);
        
        case NodeType.BOOL:
            BooleanLiteral bl = cast(BooleanLiteral) node;
            return (bl.value) ? TRUE : FALSE;

        case NodeType.STRING:
            StringLiteral sl = cast(StringLiteral) node;
            return new StringObject(sl.value);

        case NodeType.ARRAY:
            ArrayLiteral al = cast(ArrayLiteral) node;
            auto elements = evalExpressions(al.elements, env);
            if (elements.length == 1 && isError(elements[0]))
            {
                return elements[0];
            }
            return new ArrayObject(elements);
        
        case NodeType.INDEX:
            IndexExpression ie = cast(IndexExpression) node;
            auto left = eval(ie.left, env);
            if (isError(left))
            {
                return left;
            }
            auto index = eval(ie.index, env);
            if (isError(index))
            {
                return index;
            }
            return evalIndexExpression(left, index);
        
        case NodeType.HASH:
            HashLiteral hl = cast(HashLiteral) node;
            return evalHashExpression(hl, env);

        case NodeType.PREFIX:
            PrefixExpression pe = cast(PrefixExpression) node;
            auto rightExpr = eval(pe.right, env);

            return (isError(rightExpr))
                ? rightExpr
                : evalPrefixExpression(pe.operator, rightExpr);

        case NodeType.INFIX:
            InfixExpression ie = cast(InfixExpression) node;
            auto right = eval(ie.right, env);
            auto left = eval(ie.left, env);
            
            // Return an error if left or right expressions we're errors
            if (isError(left))
            {
                return left;
            }

            if (isError(right))
            {
                return right;
            }

            return evalInfixExpression(ie.operator, left, right);

        case NodeType.BLOCK:
            BlockStatement bs = cast(BlockStatement) node;
            return evalBlockStatement(bs, env);
        
        case NodeType.IF:
            IfExpression ife = cast(IfExpression) node;
            return evalIfExpression(ife, env);

        case NodeType.FUNCTION:
            FunctionLiteral fl = cast(FunctionLiteral) node;
            return new FunctionObject(fl.params, fl.body, env);
        
        case NodeType.CALL:
            CallExpression ce = cast(CallExpression) node;
            auto func = eval(ce.func, env);
            if (isError(func))
            {
                return func;
            }

            auto args = evalExpressions(ce.arguments, env);
            if (args.length == 1 && isError(args[0]))
            {
                return args[0];
            }

            return applyFunction(func, args);

        default:
            return null;
    }
}

MkyObject[] evalExpressions(Expression[] exprs, Environment env)
{
    MkyObject[] result = [];

    foreach (e; exprs)
    {
        auto evaluated = eval(e, env);
        if (isError(evaluated))
        {
            return [evaluated];
        }
        result ~= evaluated;
    }

    return result;
}

MkyObject evalHashExpression(HashLiteral hl, Environment env)
{
    HashPair[HashKey] pairs;

    foreach (pair; hl.pairs.byKeyValue)
    {
        auto key = eval(pair.key, env);
        if (isError(key))
        {
            return key;
        }

        if (!key.isHashable)
        {
            return ErrorObject.newError("Unusuable as hash key: %s", key.type());
        }
        Hashable hashable = cast(Hashable) key;

        auto value = eval(pair.value, env);
        if (isError(value))
        {
            return value;
        }

        auto hashed = hashable.hash();
        pairs[hashed] = new HashPair(key, value);
    }

    return new HashObject(pairs);
}

MkyObject evalIdentifier(Identifier id, Environment env)
{
    auto val = env.get(id.value);

    if (val !is null)
    {
        return val;
    }

    auto builtin = BUILTINS.get(id.value, null);
    if (builtin !is null)
    {
        return builtin;
    }

    return ErrorObject.newError("Variable %s not found", id.value);
}

MkyObject evalProgram(Program program, Environment env)
{
    MkyObject result;

    foreach (stmt; program.statements)
    {
        result = eval(stmt, env);

        if (result.type() == MkyObjectType.RETURN)
        {
            ReturnValue rv = cast(ReturnValue) result;
            return rv.value;
        }
        else if (result.type() == MkyObjectType.ERROR)
        {
            return result;
        }
    }

    return result;
}

MkyObject evalIndexExpression(MkyObject left, MkyObject index)
{
    if (left.type() == MkyObjectType.ARRAY && index.type() == MkyObjectType.INT)
    {
        return evalArrayIndexExpression(left, index);
    }

    if (left.type() == MkyObjectType.HASH)
    {
        return evalHashIndexExpression(left, index);
    }

    return ErrorObject.newError("Index operator not supported: %s", left.type());
}

MkyObject evalArrayIndexExpression(MkyObject left, MkyObject index)
{
    ArrayObject leftArr = cast(ArrayObject) left;
    IntegerValue indexObj = cast(IntegerValue) index;
    int indexInt = indexObj.value;
    ulong maxIndex = to!int(leftArr.elements.length - 1);
    if (indexInt < 0 || indexInt > maxIndex)
    {
        return NULL;
    }

    return leftArr.elements[indexInt];
}

MkyObject evalHashIndexExpression(MkyObject hash, MkyObject index)
{
    HashObject hashObj = cast(HashObject) hash;

    if (!index.isHashable())
    {
        return ErrorObject.newError("Unusuable as hash key: %s", index.type);
    }

    Hashable hashable = cast(Hashable) index;

    auto pair = hashObj.pairs.get(hashable.hash(), null);
    if (pair is null)
    {
        return NULL;
    }

    return pair.value;
}

MkyObject evalBlockStatement(BlockStatement block, Environment env)
{
    MkyObject result;

    foreach (stmt; block.statements)
    {
        result = eval(stmt, env);

        if (result !is null)
        {
            auto objectType = result.type();
            if (objectType == MkyObjectType.RETURN || objectType == MkyObjectType.ERROR)
            {
                return result;
            }
        }
    }

    return result;
}

MkyObject evalPrefixExpression(string operator, MkyObject right)
{
    switch (operator)
    {
        case "!":
            return evalBangOperator(right);
        case "-":
            return evalMinusOperator(right);
        default:
            return ErrorObject.newError("Unknown operator: %s%s", operator, right.type());
    }
}

MkyObject evalBangOperator(MkyObject right)
{
    if (right == TRUE)
    {
        return FALSE;
    }
    
    if (right == FALSE)
    {
        return TRUE;
    }

    if (right == NULL)
    {
        return TRUE;
    }

    return FALSE;
}

MkyObject evalIfExpression(IfExpression ife, Environment env)
{
    auto cond = eval(ife.condition, env);

    if (isError(cond))
    {
        return cond;
    }

    if (isTruthy(cond))
    {
        return eval(ife.consequence, env);
    }
    else if (ife.alternative !is null)
    {
        return eval(ife.alternative, env);
    }
    else
    {
        return NULL;
    }
}

MkyObject evalMinusOperator(MkyObject right)
{
    if (right.type() != MkyObjectType.INT)
    {
        return ErrorObject.newError("Unknown operator -%s", right.type());
    }

    IntegerValue integer = cast(IntegerValue) right;
    return new IntegerValue(-integer.value);
}

MkyObject evalInfixExpression(string operator, MkyObject left, MkyObject right)
{
    if (left.type() == MkyObjectType.INT && right.type == MkyObjectType.INT)
    {
        return evalIntegerInfixExpression(operator, left, right);
    }

    if (operator == "==")
    {
        return boolToMkyObject(left == right);
    }

    if (operator == "!=")
    {
        return boolToMkyObject(left != right);
    }

    if (left.type() != right.type())
    {
        return ErrorObject.newError("Type mismatch: %s %s %s", left.type(), operator, right.type());
    }

    return ErrorObject.newError("Unknown operator: %s %s %s", left.type(), operator, right.type());
}

MkyObject evalIntegerInfixExpression(string operator, MkyObject left , MkyObject right)
{
    int leftInt = (cast(IntegerValue) left).value;
    int rightInt = (cast(IntegerValue) right).value;

    switch (operator)
    {
        case "+":
            return new IntegerValue(leftInt + rightInt);
        case "-":
            return new IntegerValue(leftInt - rightInt);
        case "*":
            return new IntegerValue(leftInt * rightInt);
        case "/":
            return new IntegerValue(leftInt / rightInt);
        case "<":
            return boolToMkyObject(leftInt < rightInt);
        case ">":
            return boolToMkyObject(leftInt > rightInt);
        case "!=":
            return boolToMkyObject(leftInt != rightInt);
        case "==":
            return boolToMkyObject(leftInt == rightInt);
        default:
            return ErrorObject.newError("Unknown operator: %s %s %s", left.type(), operator, right.type());
    }
}

MkyObject evalStringInfixExpression(string operator, MkyObject left, MkyObject right)
{
    if (operator != "+")
    {
        return ErrorObject.newError("Unknown operator: %s %s %s", left.type(), operator, right.type());
    }

    StringObject leftStr = cast(StringObject) left;
    StringObject rightStr = cast(StringObject) right;
    return new StringObject(leftStr.inspect() ~ rightStr.inspect());
}

/// call a monkey function
MkyObject applyFunction(MkyObject funcObj, MkyObject[] args)
{
    switch(funcObj.type())
    {
        case MkyObjectType.FUNCTION:
            FunctionObject func = cast(FunctionObject) funcObj;
            auto extendedEnv = extendFunctionEnv(func, args);
            auto evaluated = eval(func.body, extendedEnv);
            return unwrapReturnValue(evaluated);

        case MkyObjectType.BUILTIN:
            BuiltinFunction builtin = cast(BuiltinFunction) funcObj;
            return builtin.fn(args);
        
        default:
            return ErrorObject.newError("not a function: %s", funcObj.inspect());
    }
}

Environment extendFunctionEnv(FunctionObject func, MkyObject[] args)
{
    auto env = Environment.enclosedEnv(func.env);

    foreach (idx, param; func.params)
    {
        env.set(param.value, args[idx]);
    }

    return env;
}

MkyObject unwrapReturnValue(MkyObject obj)
{
    if (obj !is null && obj.type() == MkyObjectType.RETURN)
    {
        ReturnValue ret = cast(ReturnValue) obj;
        return ret.value;
    }

    return obj;
}

private MkyObject boolToMkyObject(bool value)
{
    return (value) ? TRUE : FALSE;
}

private bool isTruthy(MkyObject obj)
{
    if (obj == NULL)
    {
        return false;
    }

    if (obj == FALSE)
    {
        return false;
    }

    // redundant check?
    // if (obj == TRUE)
    // {
    //     return true;
    // }

    return true;
}

private bool isError(MkyObject obj)
{
    return obj !is null && obj.type() == MkyObjectType.ERROR;
}