module passwise.entropy;

import std.algorithm;
import passwise.store : Index;

@safe:

size_t bits(in float[] prob) pure nothrow
{
    import std.math : log2, round;
    return cast(size_t) log2(1.0 / prob.fold!"a * b"(1.0L)).round;
}

float[] prob(dstring s, ref in Index index) pure
{
    import std.array : array;
    auto slide = new float[][](s.length);
    slide.each!((ref a) => a.reserve(15));

    for (size_t i; s.length; ++i, s = s[1 .. $])
        foreach (j, e; singleWalkProb(s, index))
            slide[i + j] ~= e;

    return slide.map!(fold!max).array;
}

// TODO move min capping into prob() (single pass)
float[] singleWalkProb(dstring s, ref in Index index) pure nothrow
{
    import std.range : assumeSorted;
    import passwise.node;
    import passwise.util : frequency, probMin;

    float[] res;
    if (!s.length)
        return res;

    res.reserve(15);
    res ~= frequency(cast(ushort) s[0], index.freq);
    Node prevNode = index.nodes[0][0];
    dchar prevC = s[0];
    s = s[1 .. $];
    foreach (c; s)
    {
        const delta = cast(ushort)(c - prevC);
        prevC = c;
        const curr = child(index.nodes, prevNode);
        auto lower = curr.assumeSorted!"a.v < b.v".lowerBound(Node(delta));
        if (lower.length == curr.length || curr[lower.length].v != delta)
        {
            res ~= probMin(delta);
            break;
        }
        prevNode = curr[lower.length];
        res ~= max(probMin(delta), curr[lower.length].f.toDouble);
    }
    return res;
}
