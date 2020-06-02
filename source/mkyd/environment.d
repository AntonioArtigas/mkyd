module mkyd.environment;

import std.stdio;

import mkyd.object : MkyObject;

class Environment
{
    MkyObject[string] store;

    Environment outer;

    this(Environment outer = null)
    {
        this.outer = outer;
    }
    
    MkyObject get(string name)
    {
        auto attempt = store.get(name, null);
        if (attempt is null && outer !is null)
        {
            return outer.get(name);
        }
        return attempt;
    }

    MkyObject set(string name, MkyObject val)
    {
        store[name] = val;
        return val;
    }

    static Environment enclosedEnv(Environment outer)
    {
        return new Environment(outer);
    }
}
