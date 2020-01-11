module passwise.app;

import std.traits : isSomeString;
import std.stdio : writeln;
import passwise.shovelnode;
import passwise.dnode;
import passwise.store;

void main()
{
    // TODO getopt
    const pwListsDir = "/home/user/devel/SecLists/Passwords"; // github.com/danielmiessler/SecLists
    const fileName = "/home/user/tmp/nodes";
    generateIndexFile(pwListsDir, fileName);
}

void printProb(R)(R s, ref in Index index)
if (isSomeString!R)
{
    import std.algorithm : find;
    import std.range : front, popFront, empty;
    import std.stdio : write;
    import passwise.node;

    if (s.empty)
        return;

    const ns = index.nodes;
    Node prev = ns[0][0];

    dchar prevC = s.front;
    s.popFront();
    float freq; // FIXME
    write(prevC, ":", freq, "; ");
    foreach (c; s)
    {
        ushort diff = cast(ushort)(c - prevC);
        prevC = c;
        auto search = child(ns, prev).find!"a.v == b"(diff);
        if (search.empty)
        {
            write(c, ":'not found'");
            break;
        }
        prev = search.front;

        write(c, ":", search.front.f.toDouble, "; ");
    }
    writeln();
}

void generateIndexFile(string listFilesSearchDir, string outputFileName)
{
    import passwise.util : findListFiles;
    const exclude = [r".*\.csv", r".*\.md", r".*\.[t]?gz", ".*count.*"];
    const listFiles = findListFiles(listFilesSearchDir, exclude, 10_000);
    auto index = indexListFiles(listFiles);
    writeln("Writing: '", outputFileName, "'");
    writeFile(index, outputFileName);
}

auto indexListFiles(in string[] names)
{
    import std.path : baseName;
    import passwise.util : frequency;
    auto count = new size_t[](ushort.max + 1);
    DNode root;
    foreach (i, name; names)
    {
        writeln("Parsing list ", i + 1, "/", names.length, ": '", name.baseName, "'");
        indexListFile(name, count, root);
    }

    writeln("Packing");
    normalize(root);
    return Index(frequency(count), compact(root));
}

void indexListFile(string name, size_t[] count, ref DNode root, size_t shovelSize = 25_000)
in (count.length == ushort.max + 1)
{
    import std.algorithm : each;
    import std.array : array;
    import std.range : take;
    import std.stdio : File;
    import std.string : strip;
    import std.uni : asLowerCase;
    import std.encoding : isValid, codePoints;
    ShovelNode shovel;
    size_t lineCount;
    size_t invalidCount;
    foreach (line; File(name).byLine)
    {
        if (!isValid(line))
        {
            ++invalidCount;
            continue;
        }

        const normLine = codePoints(cast(immutable char[]) line)
            .array
            .strip
            .asLowerCase
            .take(32)
            .array;

        normLine.each!(a => ++count[cast(ushort) a]);

        normLine.slide!(indexDiff, 12, 5)(shovel);

        if (++lineCount % shovelSize == 0)
        {
            merge(root, shovel.to!DNode);
            shovel = ShovelNode();
        }
    }
    merge(root, shovel.to!DNode);

    if (invalidCount)
        writeln("warning: invalid UTF-8 lines skipped: ", invalidCount);
}
