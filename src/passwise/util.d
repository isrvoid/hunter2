module passwise.util;

import std.range;
import std.algorithm : isSorted, equal;
import std.meta : allSatisfy;

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
    import std.algorithm : sort, uniq, merge;
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

enum size_t frequencyIndexLength = 0x800;

ushort[] frequencyIndex(in size_t[] count) pure
in (count.length <= frequencyIndexLength)
{
    import std.algorithm : makeIndex;
    auto res = new ushort[](frequencyIndexLength);
    foreach (i, ref v; res)
        v = cast(ushort) i;

    auto idx = new size_t[](count.length);
    makeIndex!"a > b"(count, idx);
    foreach (i, v; idx)
        if (count[v])
            res[v] = cast(ushort) i;

    return res;
}

@("frequencyIndex returns fixed length LUT") unittest
{
    assert(frequencyIndexLength == frequencyIndex(null).length);
}

@("frequencyIndex init") unittest
{
    const lut = frequencyIndex(null);
    assert(0 == lut[0]);
    assert('a' == lut['a']);
    assert(frequencyIndexLength - 1 == lut[frequencyIndexLength - 1]);
}

@("frequencyIndex count sets LUT value") unittest
{
    auto count = new size_t[]('a' + 1);
    count['a'] = 1;
    const lut = frequencyIndex(count);
    assert(0 == lut['a']);
}

@("frequencyIndex count only affects corresponding indices") unittest
{
    auto count = new size_t[]('a' + 1);
    count['a'] = 42;
    auto expect = frequencyIndex(null);
    expect['a'] = 0;
    assert(expect == frequencyIndex(count));
}

@("frequencyIndex multiple counts") unittest
{
    auto count = new size_t[]('a' + 16);
    count['a'] = 42;
    count['e'] = 40;
    count['b'] = 10;
    auto expect = frequencyIndex(null);
    expect['a'] = 0;
    expect['e'] = 1;
    expect['b'] = 2;
    assert(expect == frequencyIndex(count));
}
