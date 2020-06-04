module mkyd.builtin;

import std.stdio;

import mkyd.eval : NULL;
import mkyd.object;

MkyObject mkyLen(MkyObject[] args...)
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

MkyObject mkyPuts(MkyObject[] args...)
{
    foreach (arg; args)
    {
        writeln(arg.inspect());
    }
    
    return NULL;
}