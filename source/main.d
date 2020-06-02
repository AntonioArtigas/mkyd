import std.stdio;

import mkyd.environment;
import mkyd.eval;
import mkyd.lexer;
import mkyd.parser;

// REPL
void main()
{
    auto env = new Environment();

    while (true)
    {
        write("> ");
        string line = readln();
        auto lexer = new Lexer(line);
        auto parser = new Parser(&lexer);
        auto prg = parser.parseProgram();
        if (parser.errors.length > 0) {
            foreach (string err; parser.errors)
            {
                writeln(err);
            }
            continue;
        }

        auto result = eval(prg, env);
        if (result !is null)
        {
            writeln("uh: ", result.inspect());
        }
    }
}
