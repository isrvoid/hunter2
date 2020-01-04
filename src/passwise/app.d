module passwise.app;

import std.stdio : writeln;

import passwise.shovelnode;
import passwise.dnode;

enum seclistsDir = "/home/user/devel/SecLists"; // path to github.com/danielmiessler/SecLists

enum pwDir = seclistsDir ~ "/Passwords/";
enum pwLists = [pwDir ~ "bt4-password.txt",
             pwDir ~ "darkc0de.txt",
             pwDir ~ "openwall.net-all.txt",
             pwDir ~ "xato-net-10-million-passwords.txt",
             pwDir ~ "Leaked-Databases/alleged-gmail-passwords.txt",
             pwDir ~ "Leaked-Databases/md5decryptor-uk.txt",
             //pwDir ~ "Leaked-Databases/rockyou.txt", // needs extracted rockyou.txt.tar.gz
];

void main()
{
    // TODO getopt
    import passwise.store : store;
    auto index = indexListFiles(pwLists);
    store(index.node, "/tmp/nodes");
}

auto indexListFiles(string[] names)
{
    import std.typecons : tuple;
    import std.path : baseName;
    import passwise.util : frequencyIndex, frequencyIndexLength;
    auto freq = new size_t[](frequencyIndexLength);
    DNode root;
    foreach (i, name; names)
    {
        writeln("Parsing list ", i + 1, "/", pwLists.length, ": '", name.baseName, "'");
        indexListFile(name, freq, root);
    }

    normalize(root);
    return tuple!("freq", "node")(frequencyIndex(freq), root);
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
