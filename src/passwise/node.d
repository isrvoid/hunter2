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

ubyte[4] getCrc(in NodeStore ns)
{
    import std.digest.crc : CRC32;
    CRC32 crc;
    foreach (e; ns)
        crc.put(cast(const ubyte[]) e);
    return crc.finish();
}
