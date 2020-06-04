module mkyd.object;

import std.algorithm : map;
import std.array : appender, join;
import std.conv : to;
import std.format : format;
import std.stdio;

import mkyd.ast : Identifier, BlockStatement;
import mkyd.environment : Environment;
import mkyd.fnv1 : fnv1a;

enum MkyObjectType
{
    INT,
    BOOL,
    NULL,
    RETURN,
    ERROR,
    FUNCTION,
    STRING,
    BUILTIN,
    ARRAY,
    HASH
}

interface MkyObject
{
    MkyObjectType type();
    string inspect();
    bool isHashable();
}

/// IntegerValue value
class IntegerValue : MkyObject, Hashable
{
    int value;

    this(int value)
    {
        this.value = value;
    }

    string inspect()
    {
        return to!string(value);
    }

    MkyObjectType type()
    {
        return MkyObjectType.INT;
    }

    HashKey hash()
    {
        return HashKey(type(), value);
    }

    bool isHashable()
    {
        return true;
    }
}

/// True or false value
class BooleanValue : MkyObject, Hashable
{
    bool value;

    this(bool value)
    {
        this.value = value;
    }

    string inspect()
    {
        return (value) ? "true" : "false";
    }

    MkyObjectType type()
    {
        return MkyObjectType.BOOL;
    }

    HashKey hash()
    {
        return HashKey(type(), (value) ? 1 : 0);
    }

    bool isHashable()
    {
        return true;
    }
}

/// Welp there goes a billion dollars
class NullValue : MkyObject
{
    string inspect()
    {
        return "null";
    }

    MkyObjectType type()
    {
        return MkyObjectType.NULL;
    }

    bool isHashable()
    {
        return false;
    }
}

class ReturnValue : MkyObject
{
    MkyObject value;

    this(MkyObject value)
    {
        this.value = value;
    }

    MkyObjectType type()
    {
        return MkyObjectType.RETURN;
    }

    string inspect()
    {
        return value.inspect();
    }

    bool isHashable()
    {
        return false;
    }
}

class ErrorObject : MkyObject
{
    string message;

    this(string message)
    {
        this.message = message;
    }

    MkyObjectType type()
    {
        return MkyObjectType.ERROR;
    }

    string inspect()
    {
        return "Error: " ~ message;
    }

    static ErrorObject newError(T...)(string formatStr, T t)
    {
        return new ErrorObject(format(formatStr, t));
    }

    bool isHashable()
    {
        return false;
    }
}

class FunctionObject : MkyObject
{
    Identifier[] params;
    BlockStatement body;
    Environment env;

    this(Identifier[] params,
            BlockStatement body, Environment env)
    {
        this.params = params;
        this.body = body;
        this.env = env;
    }

    MkyObjectType type()
    {
        return MkyObjectType.FUNCTION;
    }

    string inspect()
    {
        auto buffer = appender!string;

        auto paramStr = params.map!(a => a.nodeString());

        buffer.put("fn(");
        buffer.put(paramStr.join(", "));
        buffer.put(") {\n");
        buffer.put(body.nodeString());
        buffer.put("\n");
        buffer.put("}");

        return buffer.data;
    }

    bool isHashable()
    {
        return false;
    }
}

class StringObject : MkyObject, Hashable
{
    string value;

    this(string value)
    {
        this.value = value;
    }

    MkyObjectType type()
    {
        return MkyObjectType.STRING;
    }

    string inspect()
    {
        return value;
    }

    HashKey hash()
    {
        return HashKey(MkyObjectType.STRING, fnv1a(value));
    }

    bool isHashable()
    {
        return true;
    }
}

class BuiltinFunction : MkyObject
{
    // NOTE: Does this even work?
    // Different types allowed?
    // No type safety?
    // no idea
    MkyObject function(MkyObject[]...) fn;

    this(MkyObject function(MkyObject[]...) fn)
    {
        this.fn = fn;
    }

    MkyObjectType type()
    {
        return MkyObjectType.BUILTIN;
    }

    string inspect()
    {
        return "builtin object";
    }

    bool isHashable()
    {
        return true;
    }
}

class ArrayObject : MkyObject
{
    MkyObject[] elements;

    this(MkyObject[] elements)
    {
        this.elements = elements;
    }

    MkyObjectType type()
    {
        return MkyObjectType.ARRAY;
    }

    string inspect()
    {
        auto buffer = appender!string;

        buffer.put("[");
        foreach (MkyObject key; elements)
        {
            // TODO: Find way to use join on these
            buffer.put(key.inspect());
            buffer.put(", ");
        }
        buffer.put("]");

        return buffer.data;    
    }

    bool isHashable()
    {
        return false;
    }
}

// Hashing
class HashObject : MkyObject
{
    HashPair[HashKey] pairs;

    this(HashPair[HashKey] pairs)
    {
        this.pairs = pairs;
    }

    MkyObjectType type()
    {
        return MkyObjectType.HASH;
    }

    string inspect()
    {
        auto buffer = appender!string;

        buffer.put("{ HashObject.inspect(): TODO }");

        return buffer.data;
    }

    bool isHashable()
    {
        return false;
    }
}

// TODO: Find out why this as a struct works but not a class
struct HashKey
{
    MkyObjectType type;
    ulong value;

    this(MkyObjectType type, ulong value)
    {
        this.type = type;
        this.value = value;
    }
}

class HashPair
{
    MkyObject key;
    MkyObject value;

    this(MkyObject key, MkyObject value)
    {
        this.key = key;
        this.value = value;
    }
}

// Implemented by int, bool, and strings
interface Hashable
{
    HashKey hash();
}