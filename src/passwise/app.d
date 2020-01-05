module passwise.app;

import std.stdio : writeln;
import passwise.shovelnode;
import passwise.dnode;
import passwise.store;

enum seclistsDir = "/home/user/devel/SecLists"; // path to github.com/danielmiessler/SecLists

void main()
{
    // TODO getopt
    import passwise.util : findListFiles;
    // TODO extract function
    const exclude = [r".*\.csv", r".*\.md", r".*\.[t]?gz", ".*count.*"];
    const listFiles = findListFiles(seclistsDir ~ "/Passwords", exclude, 10_000);
    auto index = indexListFiles(listFiles);
    const fileName = "/tmp/nodes";
    writeln("Writing: '", fileName, "'");
    writeFile(index, fileName);
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
            .limitRepetitions!3
            .take(28)
            .array;

        normLine
            .filter!(a => a < frequencyIndexLength)
            .each!(a => ++freq[a]);

        normLine.slide!(indexDiff, 12, 4)(shovel);

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
