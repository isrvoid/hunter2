module passwise.store;

import std.typecons : Tuple;
import passwise.dnode : DNode, compact;
import passwise.node;

@safe:

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
    uint dataOffset;
}

private ubyte[4] crc32Of(in NodeStore nodes) pure nothrow
{
    import std.digest.crc : CRC32;
    CRC32 crc;
    foreach (e; nodes)
        crc.put(cast(const ubyte[]) e);
    return crc.finish();
}

void writeFile(in NodeStore nodes, string name)
{
    import std.stdio : File;

    auto makeHeader()
    {
        StoreHeader h;
        h.groupCount[0] = cast(uint) nodes[0].length;
        h.groupCount[1] = cast(uint) nodes[1].length / 2;
        h.groupCount[2] = cast(uint) nodes[2].length - 1;
        h.crc = crc32Of(nodes);
        h.dataOffset = 64;
        return h;
    }

    const h = makeHeader();
    auto file = File(name, "wb");
    file.rawWrite([h]);

    file.seek(h.dataOffset);
    foreach (e; nodes)
        file.rawWrite(e);
}

NodeStore readFile(string name)
{
    import std.stdio : File;
    auto file = File(name);
    const h = file.rawRead([StoreHeader()])[0];
    if (h._version != StoreHeader.init._version)
        throw new Exception("Version mismatch: " ~ name);

    file.seek(h.dataOffset);
    NodeStore ns;
    ns[0].length = h.groupCount[0];
    ns[1].length = h.groupCount[1] * 2;
    ns[2].length = h.groupCount[2] + 1;
    const nodesSizeWithoutLastArray = (cast(ubyte[]) ns[0]).length +
        (cast(ubyte[]) ns[1]).length + (cast(ubyte[]) ns[2]).length;
    ns[3].length = (file.size - h.dataOffset - nodesSizeWithoutLastArray) / Node.sizeof;

    foreach (e; ns)
        file.rawRead(e);

    if (h.crc != crc32Of(ns))
        throw new Exception("CRC mismatch: " ~ name);

    return ns;
}
