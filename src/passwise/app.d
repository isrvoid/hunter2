module passwise.app;

import std.stdio : writeln;

import passwise.shovelnode;
import passwise.dnode;

enum seclistsDir = "/home/user/devel/SecLists"; // path to github.com/danielmiessler/SecLists

enum pwDir = seclistsDir ~ "/Passwords/";
enum pwLists = [pwDir ~ "bt4-password.txt",
             pwDir ~ "darkc0de.txt",
             pwDir ~ "openwall.net-all.txt",
             pwDir ~ "Leaked-Databases/alleged-gmail-passwords.txt",
             pwDir ~ "Leaked-Databases/md5decryptor.uk.txt",
             //pwDir ~ "Leaked-Databases/rockyou.txt", // needs extracted rockyou.txt.tar.gz
];

void main()
{
    // TODO getopt
version (unittest) { }
else
{
    DNode root = parseLists(pwLists);
    store(root, "/tmp/nodes");
}
}

DNode parseLists(string[] names)
{
    import std.path : baseName;
    DNode root;
    foreach (i, name; names)
    {
        writeln("Parsing list ", i + 1, "/", pwLists.length, ": '", name.baseName, "'");
        indexListFile(name, root);
    }

    normalize(root);
    return root;
}

void store(DNode root, string name)
{
    import passwise.node : writeFile;
    writeln("Packing");
    const nodes = compact(root);
    writeln("Writing: '", name, "'");
    writeFile(nodes, name);
}

void indexListFile(string name, ref DNode root, size_t shovelSize = 25_000)
{
    import std.algorithm : any;
    import std.array : array;
    import std.range : take;
    import std.stdio : File;
    import std.string : strip;
    import std.uni : asLowerCase;
    import std.utf : validate, UTFException;
    import passwise.util : limitRepetitions;
    ShovelNode shovel;
    size_t lineCount;
    size_t invalidCount;
    foreach (line; File(name).byLineCopy)
    {
        try
            validate(line);
        catch (UTFException e)
        {
            ++invalidCount;
            continue;
        }

        if (line.any!"a > ushort.max") // DNode => Node requirement
            continue;

        line.strip
            .asLowerCase
            .limitRepetitions!3
            .take(28)
            .array
            .indexSlide!12(shovel);

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
