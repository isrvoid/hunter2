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

size_t[] radix16Bits(ref in Index index, size_t n)
{
    import std.random : Random, uniform, unpredictableSeed;
    import std.algorithm : each, sort;
    auto rnd = Random(unpredictableSeed);
    auto makeString()
    {
        enum lut = "0123456789ABCDEF"d;
        // 256 / log2(16) = 64
        dchar[64] a;
        a.each!((ref a) => a = lut[uniform(0, 16)]);
        return a.idup;
    }

    auto res = new size_t[](n);
    foreach (ref e; res)
        e = makeString.prob(index).bits;

    res.sort;
    return res;
}

size_t[] radix64Bits(ref in Index index, size_t n)
{
    import std.random : Random, uniform, unpredictableSeed;
    import std.algorithm : each, sort;
    auto rnd = Random(unpredictableSeed);
    auto makeString()
    {
        // 256 / log2(64) ~ 43
        dchar[43] a;
        a.each!((ref a) => a = ' ' + uniform(0, 64));
        return a.idup;
    }

    auto res = new size_t[](n);
    foreach (ref e; res)
        e = makeString.prob(index).bits;

    res.sort;
    return res;
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
    import std.uni : asUpperCase;
    import std.encoding : isValid, codePoints;
    import passwise.util : limitRepetitions;
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

        normLine.each!(a => ++count[cast(ushort) a]);

        normLine.slide!(indexDiff, 10, 5)(shovel);

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
