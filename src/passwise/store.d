module passwise.store;

import passwise.dnode : DNode, compact;
import passwise.node;

struct StoreHeader
{
    union
    {
        struct
        {
            ubyte number = 1;
            ubyte nodeSize = Node.sizeof;
        }
        ulong _version;
    }
    uint[3] groupCount;
    ubyte[4] crc;
    ushort dataOffset;
}

void store(DNode root, string name)
{
    import std.stdio : writeln;
    writeln("Packing");
    const nodes = compact(root);
    writeln("Writing: '", name, "'");
    writeFile(nodes, name);
}

void writeFile(in NodeStore ns, string name)
{
    import std.stdio : File;
    auto file = File(name, "wb");
    auto makeHeader()
    {
        StoreHeader h;
        h.groupCount[0] = cast(uint) ns[0].length;
        h.groupCount[1] = cast(uint) ns[1].length / 2;
        h.groupCount[2] = cast(uint) ns[2].length - 1;
        h.crc = getCrc(ns);
        h.dataOffset = 64;
        return h;
    }
    const h = makeHeader();
    file.rawWrite([h]);

    file.seek(h.dataOffset);
    foreach (e; ns)
        file.rawWrite(e);
}

NodeStore readFile(string name)
{
    import std.stdio : File;
    auto file = File(name);
    const h = file.rawRead(new StoreHeader[](1))[0];
    if (h._version != StoreHeader.init._version)
        throw new Exception("Version mismatch: " ~ name);

    NodeStore ns;
    ns[0].length = h.groupCount[0];
    ns[1].length = h.groupCount[1] * 2;
    ns[2].length = h.groupCount[2] + 1;
    ns[3].length = (file.size - h.dataOffset - (cast(ubyte[]) ns[0]).length -
        (cast(ubyte[]) ns[1]).length - (cast(ubyte[]) ns[2]).length) / Node.sizeof;

    file.seek(h.dataOffset);
    foreach (e; ns)
        file.rawRead(e);

    if (h.crc != getCrc(ns))
        throw new Exception("CRC mismatch: " ~ name);

    return ns;
}
