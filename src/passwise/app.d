module passwise.app;

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
    import passwise.util : frequencyIndex, frequencyIndexLength;
    auto freq = new size_t[](frequencyIndexLength);
    DNode root;
    foreach (i, name; names)
    {
        writeln("Parsing list ", i + 1, "/", names.length, ": '", name.baseName, "'");
        indexListFile(name, freq, root);
    }

    writeln("Packing");
    normalize(root);
    return Index(frequencyIndex(freq), compact(root));
}

void indexListFile(string name, size_t[] freq, ref DNode root, size_t shovelSize = 25_000)
{
    import std.algorithm : filter, each;
    import std.array : array;
    import std.range : take;
    import std.stdio : File;
    import std.string : strip;
    import std.uni : asLowerCase;
    import std.encoding : isValid, codePoints;
    import passwise.util : limitRepetitions, frequencyIndexLength;
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

        normLine
            .filter!(a => a < frequencyIndexLength)
            .each!(a => ++freq[a]);

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
