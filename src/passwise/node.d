module passwise.node;

import std.typecons : Tuple;

static assert(Node.sizeof == 8);
struct Node
{
    ushort v;
    Ratio f;
    uint child;
}

struct Ratio
{
    import std.math : exp, log;

    this(double val) pure nothrow
    in (val >= 0.0 && val <= 1.0)
    {
        if (val <= zeroStep)
            ratio = ushort.max;
        else
            ratio = cast(ushort)(log(val) / f + 0.5);
    }

    double toDouble() const
    out (r; r >= 0.0 && r <= 1.0)
    {
        return ratio == ushort.max ? 0.0 : exp(ratio * f);
    }
    alias toDouble this;

    void opAssign(double rhs) pure nothrow
    {
        this = Ratio(rhs);
    }

private:
    enum zeroStep = 1e-7;
    enum f = log(zeroStep) / (ushort.max - 1);
    ushort ratio = ushort.max;
}

@("Ratio.init") unittest
{
    Ratio r;
    assert(0.0 == r);
}

@("Ratio ctor min max") unittest
{
    assert(0.0 == Ratio(0.0));
    assert(1.0 == Ratio(1.0));
}

@("Ratio assign min max") unittest
{
    Ratio r;
    r = 0.0;
    assert(0.0 == r);
    r = 1.0;
    assert(1.0 == r);
}

version (unittest)
{
    import std.math : sqrt, approxEqual;
    import std.range : iota;
    enum goldenRatio = (1 + sqrt(5.0)) / 2;
    enum ratioRelPrecision = 1.25e-4;
}

@("Ratio precision") unittest
{
    enum inc = goldenRatio * 1e-3;
    foreach (v; iota(0.0, 1.0, inc))
        assert(approxEqual(v, Ratio(v), ratioRelPrecision, 1e-7));
}

@("Ratio precision around 0") unittest
{
    enum inc = goldenRatio * 1e-8;
    foreach (v; iota(0.0, 1e-5, inc))
        assert(approxEqual(v, Ratio(v), ratioRelPrecision, 1e-7));
}

@("Ratio precision around 1") unittest
{
    enum inc = goldenRatio * 1e-6;
    foreach (v; iota(0.999, 1.0, inc))
        assert(approxEqual(v, Ratio(v), ratioRelPrecision, 1e-7));
}

const(Node)[] child(ref const NodeStore ns, Node n) pure
{
    if (!n.child)
        return [];

    if (n.child < NodeIndexLimit.end1)
        return ns[0][n.child .. n.child + 1];

    if (n.child < NodeIndexLimit.end2)
    {
        const i = (n.child - NodeIndexLimit.start2) * 2;
        return ns[1][i .. i + 2];
    }

    const i = n.child - NodeIndexLimit.startMult;
    return ns[3][ns[2][i] .. ns[2][i + 1]];
}

enum NodeIndexLimit : uint
{
    start1 = 0,
    end1 = start2,
    start2 = 0b11 << 30,
    end2 = startMult,
    startMult = 0b111 << 29,
    endMult = uint.max
}

alias NodeStore = Tuple!(Node[], Node[], uint[], Node[]);

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

ubyte[4] getCrc(in NodeStore ns)
{
    import std.digest.crc : CRC32;
    CRC32 crc;
    foreach (e; ns)
        crc.put(cast(const ubyte[]) e);
    return crc.finish();
}

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
