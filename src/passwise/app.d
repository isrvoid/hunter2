module passwise.app;

import std.traits : isSomeString;
import std.stdio : writeln;
import passwise.shovelnode;
import passwise.dnode;
import passwise.store;
import passwise.entropy;

void main()
{
    // TODO getopt
    const pwListsDir = "/home/user/devel/SecLists/Passwords"; // github.com/danielmiessler/SecLists
    const fileName = "/home/user/tmp/nodes";
    generateIndexFile(pwListsDir, fileName);
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
    DNode root;
    foreach (i, name; names)
    {
        writeln("Parsing list ", i + 1, "/", names.length, ": '", name.baseName, "'");
        indexListFile(name, root);
    }

    writeln("Packing");
    normalize(root);
    return compact(root);
}

void indexListFile(string name, ref DNode root, size_t shovelSize = 25_000)
{
    import std.algorithm : each;
    import std.array : array;
    import std.range : take;
    import std.stdio : File;
    import std.string : strip;
    import std.uni : asUpperCase;
    import std.encoding : isValid, codePoints;
    import passwise.util;
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
            .asUpperCase
            .limitRepetitions!3
            .take(32)
            .array;

        normLine.pack.diff.index(shovel);

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
