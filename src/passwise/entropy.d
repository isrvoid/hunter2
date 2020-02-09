module passwise.entropy;

import std.algorithm;
import passwise.node : NodeStore;
import passwise.util;

@safe:

size_t bits(in float[] prob) pure nothrow
{
    import std.math : log2, round;
    return cast(size_t) log2(1.0 / prob.fold!"a * b"(1.0L)).round;
}

// FIXME rework
float[] prob(dstring s, ref in NodeStore nodes) pure
{
    import std.array : array;
    auto slide = new float[][](s.length);
    slide.each!((ref a) => a.reserve(15));

    {
        const rand = randomProb(s);
        size_t i;
        slide.each!((ref a) => a ~= rand[i++]);
    }

    for (size_t i; s.length; ++i, s = s[1 .. $])
        foreach (j, e; singleTravProb(s, nodes).dropLikelyRandomTailHit)
            slide[i + j] ~= e;

    return slide.map!(fold!max).array;
}

// FIXME rework using pack
float[] randomProb(R)(R r) pure nothrow
{
    import std.array : array;
    import std.range : chain, only, empty, front;
    if (r.empty)
        return null;

    auto first = r.front.randomValueProb;
    auto diff = r.diff.map!randomDiffProb;
    return chain(first.only, diff).array; 
}

private float[] singleTravProb(dstring s, ref in NodeStore nodes) pure nothrow
{
    import std.range : assumeSorted;
    import passwise.node;
    float[] res;
    if (!s.length)
        return res;

    res.reserve(15);
    res ~= randomValueProb(s[0]);
    Node prevNode = nodes[0][0];
    int prevC = s[0];
    s = s[1 .. $];
    foreach (c; s)
    {
        const delta = cast(short)(c - prevC);
        prevC = c;
        const curr = child(nodes, prevNode);
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
