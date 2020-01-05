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
    uint freqLength;
    uint[3] groupCount;
    ubyte[4] crc;
    uint dataOffset;
}

alias Index = Tuple!(ushort[], "freq", NodeStore, "nodes");

private ubyte[4] crc32Of(in Index index) pure nothrow
{
    import std.digest.crc : CRC32;
    CRC32 crc;
    crc.put(cast(const ubyte[]) index.freq);
    foreach (e; index.nodes)
        crc.put(cast(const ubyte[]) e);
    return crc.finish();
}

void writeFile(in Index index, string name)
{
    import std.stdio : File;

    auto makeHeader()
    {
        StoreHeader h;
        h.freqLength = cast(uint) index.freq.length;
        h.groupCount[0] = cast(uint) index.nodes[0].length;
        h.groupCount[1] = cast(uint) index.nodes[1].length / 2;
        h.groupCount[2] = cast(uint) index.nodes[2].length - 1;
        h.crc = crc32Of(index);
        h.dataOffset = 64;
        return h;
    }

    const h = makeHeader();
    auto file = File(name, "wb");
    file.rawWrite([h]);

    file.seek(h.dataOffset);
    file.rawWrite(index.freq);
    foreach (e; index.nodes)
        file.rawWrite(e);
}

Index readFile(string name)
{
    import std.stdio : File;
    import passwise.util : frequencyIndexLength;
    auto file = File(name);
    const h = file.rawRead([StoreHeader()])[0];
    if (h._version != StoreHeader.init._version)
        throw new Exception("Version mismatch: " ~ name);

    if (h.freqLength != frequencyIndexLength)
        throw new Exception("Frequency index length mismatch");

    file.seek(h.dataOffset);
    Index res;
    res.freq = file.rawRead(new ushort[](h.freqLength));

    NodeStore ns;
    ns[0].length = h.groupCount[0];
    ns[1].length = h.groupCount[1] * 2;
    ns[2].length = h.groupCount[2] + 1;
    const nodesSizeWithoutLastArray = (cast(ubyte[]) ns[0]).length +
        (cast(ubyte[]) ns[1]).length + (cast(ubyte[]) ns[2]).length;
    const nodesOffset = h.dataOffset + h.freqLength * ushort.sizeof;
    ns[3].length = (file.size - nodesOffset - nodesSizeWithoutLastArray) / Node.sizeof;

    foreach (e; ns)
        file.rawRead(e);

    res.nodes = ns;

    if (h.crc != crc32Of(res))
        throw new Exception("CRC mismatch: " ~ name);

    return res;
}
