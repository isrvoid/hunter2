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

    {
        const rand = maxRandomProb(s);
        size_t i;
        slide.each!((ref a) => a ~= rand[i++]);
    }

    for (size_t i; s.length; ++i, s = s[1 .. $])
        foreach (j, e; singleTravProb(s, index).dropLikelyRandomTailHit)
            slide[i + j] ~= e;

    return slide.map!(fold!max).array;
}

private float[] maxRandomProb(dstring s) pure nothrow
{
    import std.array : array;
    import std.range : zip, chain, only;
    import passwise.util : maxRandomProb, maxRandomFreq;
    if (!s.length)
        return null;

    auto freq = s.map!maxRandomFreq;
    uint prev = s[0];
    auto diff = s[1 .. $].map!((a) { const diff = a - prev; prev = a; return maxRandomProb(diff); });
    auto pair = zip(freq, chain(0.0f.only, diff));
    return pair.map!"max(a[0], a[1])".array;
}

private float[] singleTravProb(dstring s, ref in Index index) pure nothrow
{
    import std.range : assumeSorted;
    import passwise.node;
    import passwise.util : frequency;
    float[] res;
    if (!s.length)
        return res;

    res.reserve(15);
    res ~= frequency(cast(ushort) s[0], index.freq);
    Node prevNode = index.nodes[0][0];
    int prevC = s[0];
    s = s[1 .. $];
    foreach (c; s)
    {
        const delta = cast(short)(c - prevC);
        prevC = c;
        const curr = child(index.nodes, prevNode);
        auto lower = curr.assumeSorted!"a.v < b.v".lowerBound(Node(delta));
        if (lower.length == curr.length || curr[lower.length].v != delta)
            break;

        prevNode = curr[lower.length];
        res ~= curr[lower.length].f.toDouble;
    }
    return res;
}

private float[] dropLikelyRandomTailHit(float[] prob) pure nothrow
in (prob.length)
{
    const tail = prob[$ - 1];
    if (tail > 0.618 && (prob.length <= 5 || prob[$ - 3] + prob[$ - 2] < tail * 1.236))
        return prob[0 .. $ - 1];

    return prob;
}
