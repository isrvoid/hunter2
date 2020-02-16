module passwise.util;

import std.algorithm;
import std.range;
import std.meta : allSatisfy;
import std.traits : isIntegral, isSomeChar;

@safe:

struct LimitRepetitions(R, size_t maxRep)
if (maxRep >= 1)
{
    private R _input;
    private size_t _repCount;

    this(R input)
    {
        _input = input;
    }

    @property auto ref front()
    {
        return _input.front;
    }

    void popFront()
    {
        assert(!empty);
        auto prev = _input.front;
        _input.popFront();
        if (!_input.empty)
        {
            if (prev != _input.front)
                _repCount = 0;
            else if (++_repCount >= maxRep)
                popFront();
        }
    }

    @property bool empty() nothrow
    {
        return _input.empty;
    }

}

auto limitRepetitions(size_t maxRep = 1, Range)(Range r)
if (isInputRange!Range)
{
    return LimitRepetitions!(Range, maxRep)(r);
}

@("limitRepetitions empty input") unittest
{
    assert(equal("", "".limitRepetitions));
}

@("repetitions up to max are unaffected") unittest
{
    assert(equal("a", "a".limitRepetitions));
    assert(equal("aabb", "aabb".limitRepetitions!2));
}

@("repetitions above max are skipped") unittest
{
    assert(equal("a", "aa".limitRepetitions));
    assert(equal("aabb", "aaaabbb".limitRepetitions!2));
}

@("limitRepetitions misc input") unittest
{
    enum noRep = "The quick brown fox jumps over the lazy dog.";
    assert(equal(noRep, noRep.limitRepetitions));

    assert(equal("start midle", "ssssssssstart          midddddddddddddle".limitRepetitions));
    assert(equal("middlee endd", "middleeeeeeeeeeeeeeeee endddddddddddddddddddddd".limitRepetitions!2));
    assert(equal("middllleee", "middlllllllllllllllllllllllllllllleee".limitRepetitions!3));
}

size_t mergeLength(alias cmp = "(a > b) - (a < b)", R1, R2)(R1 a, R2 b) pure
if (allSatisfy!(isInputRange, R1, R2))
in (a.isSorted && b.isSorted, "ranges should be sorted")
{
    import std.functional : binaryFun;
    auto aLength = a.length, bLength = b.length;
    size_t count;
    while (aLength && bLength)
    {
        ++count;
        switch (binaryFun!cmp(a.front, b.front))
        {
            case -1:
                a.popFront();
                --aLength;
                break;
            case 1:
                b.popFront();
                --bLength;
                break;
            case 0:
                a.popFront();
                --aLength;
                b.popFront();
                --bLength;
                break;
            default: assert(0);
        }
    }
    return count + (aLength | bLength);
}

@("mergeLength empty input") unittest
{
    assert(0 == mergeLength("", ""));
}

@("mergeLength equal elements merge; single element") unittest
{
    assert(1 == mergeLength([0], [0]));
}

@("mergeLength unequal elements add up; single element") unittest
{
    assert(2 == mergeLength([0], [1]));
    assert(2 == mergeLength([0], [-1]));
}

@("mergeLength one input empty") unittest
{
    assert(1 == mergeLength("a", ""));
    assert(3 == mergeLength("", "foo"));
}

@("mergeLength first element equal") unittest
{
    assert(3 == mergeLength("ab", "ac"));
    assert(2 == mergeLength("a", "ab"));
}

@("mergeLength last element equal") unittest
{
    assert(3 == mergeLength("ac", "bc"));
    assert(2 == mergeLength("ac", "c"));
    assert(2 == mergeLength("c", "bc"));
}

@("mergeLength middle element equal") unittest
{
    assert(3 == mergeLength("abc", "b"));
    assert(3 == mergeLength("b", "abc"));
    assert(4 == mergeLength("ac", "bcd"));
    assert(4 == mergeLength("acd", "bc"));
    assert(5 == mergeLength("ace", "bcd"));
}

@("mergeLength longer input") unittest
{
    auto a = "why didn't we use std.algorithm : merge, uniq and walkLength to do the same?"d.dup;
    auto b = "mergeLength needs to be fast for the optimization to make sense"d.dup;
    a = a.sort.uniq.array;
    b = b.sort.uniq.array;
    size_t expect = merge(a, b).uniq.walkLength;
    assert(expect == mergeLength(a, b));
}

@("mergeLength non strictly ordered input") unittest
{
    assert(11 == mergeLength("abbceee", "aabbbdeeee"));
}

float randomValueProb(uint v) pure nothrow
{
    return 0.5f / (v + 1);
}

@("randomValueProb 0 input") unittest
{
    assert(randomValueProb(0) <= 1.0f);
}

@("randomValueProb larger input") unittest
{
    assert(randomValueProb(1 << 15) > 0.0f);
}

float randomDiffProb(int diff) pure nothrow
{
    // f(w) = 1/w - d/w^2
    // f(w') = -1/w^2 - -2d/w^3
    // 2d/w0^3 - 1/w0^2 = 0
    // w0 = 2d
    // wmax = 1/2d - d/(2d)^2 = 1/2d - 1/4d = 1/4d
    import std.math : abs;
    return diff ? 0.25 / abs(diff) : 1.0f;
}

@("randomDiffProb 0") unittest
{
    assert(randomDiffProb(0) <= 1.0f);
}

@("randomDiffProb small") unittest
{
    assert(randomDiffProb(1) > randomDiffProb(2));
}

@("randomDiffProb signed") unittest
{
    assert(randomDiffProb(1) == randomDiffProb(-1));
}

auto findListFiles(string path, in string[] exclude, size_t minSize = 0, size_t maxSize = size_t.max) @system
{
    import std.file : dirEntries, SpanMode;
    import std.path : baseName;
    import std.regex : regex, matchFirst;
    auto rExclude = regex(exclude);
    string[] res;
    foreach (e; dirEntries(path, SpanMode.breadth))
    {
        if (e.isDir || e.size < minSize || e.size > maxSize)
            continue;

        if (matchFirst(e.name.baseName, rExclude))
            continue;

        res ~= e.name;
    }

    return res;
}

auto pack(R)(R r) pure
if (isIntegral!(ElementType!R))
{
    const auto length = r.walkLength;
    auto invLut = new int[](length);
    r.copy(invLut);
    invLut.sort;
    invLut.length -= invLut.uniq.copy(invLut).length;
    // TODO test if AA is faster
    auto res = new int[](length);
    for (size_t i = 0; i < length; ++i, r.popFront())
        res[i] = cast(int) invLut.assumeSorted.lowerBound(r.front).length;

    return res;
}

auto pack(R)(R _r) @trusted
if (isSomeChar!(ElementType!R))
{
    import std.encoding : codePoints;
    import std.traits : isNarrowString;
    static if (isNarrowString!R)
        auto r =  _r.codePoints.array;
    else
        auto r = _r;

    return r.map!"cast(int) a".pack;
}

@("pack empty input") unittest
{
    assert("".pack.empty);
}

@("pack single value") unittest
{
    assert([0] == "a".pack);
}

@("pack equal values") unittest
{
    assert([0, 0] == "aa".pack);
}

@("pack adjacent values") unittest
{
    assert([0, 1] == "ab".pack);
    assert([1, 0] == "ba".pack);
}

@("pack removes gaps") unittest
{
    assert([0, 1] == "ac".pack);
    assert([2, 1, 0] == "xca".pack);
}

@("pack doesn't remove occupied gaps") unittest
{
    assert([0, 2, 1] == "acb".pack);
    assert([2, 0, 1] == "cab".pack);
}

@("pack sparsely occupied gaps") unittest
{
    assert([0, 2, 1] == "axl".pack);
    assert([2, 0, 1] == "xal".pack);
}

@("pack duplicates don't affect span") unittest
{
    assert([0, 0, 1] == "aab".pack);
    assert([0, 1, 1] == "abb".pack);
    assert([1, 1, 0] == "bba".pack);
    assert([1, 0, 0] == "baa".pack);
}

@("pack works with ranges") unittest
{
    assert(equal(iota(10), iota(10).pack));
}

struct Diff(R)
{
    private R r;
    private typeof(cast() r.front) prev;

    this(R _r)
    {
        r = _r;

        if (r.empty)
            return;

        prev = r.front;
        r.popFront();
    }

    int front() const pure
    {
        return r.front - prev;
    }

    void popFront() pure
    {
        assert(!empty);
        prev = r.front;
        r.popFront();
    }

    bool empty() const pure nothrow
    {
        return !length;
    }

    size_t length() const pure nothrow
    {
        return r.length;
    }
}

auto diff(R)(R r) pure
{
    return Diff!R(r);
}

@("diff empty input") unittest
{
    int[] input;
    assert(input.diff.empty);
}

@("diff single value") unittest
{
    assert("a".diff.empty);
}

@("diff two values") unittest
{
    assert(equal([0], "aa".diff));
    assert(equal([1], "ab".diff));
    assert(equal([-1], "ba".diff));
}

@("diff multiple values") unittest
{
    assert(equal([42, -3, 1], [0, 42, 39, 40].diff));
}
