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

struct Pair
{
    align (2):
    ushort c;
    float f;
}

Pair[] frequency(in size_t[] count) pure nothrow
in (count.length <= ushort.max + 1)
{
    import std.algorithm : filter, map, sum;
    import std.array : array;
    const total = count.sum;
    return count
        .enumerate
        .filter!"a.value"
        .map!(a => Pair(cast(ushort) a.index, float(a.value) / total))
        .array;
}

@("frequency init") unittest
{
    assert(frequency(null).empty);
}

@("frequency single count") unittest
{
    const a = frequency([1]);
    assert(1 == a.length);
    assert(0 == a[0].c);
    assert(1.0f == a[0].f);
}

@("frequency 0 counts are skipped") unittest
{
    assert(frequency([0]).empty);
    const freq = frequency([0, 42, 0]);
    assert(1 == freq.length);
    assert(1 == freq[0].c);
    assert(1.0f == freq[0].f);
}

@("frequency multiple counts") unittest
{
    auto count = new size_t[]('d' + 1);
    count['a'] = 2;
    count['b'] = 1;
    count['d'] = 1;
    const freq = count.frequency;
    assert('a' == freq[0].c);
    assert(0.5f == freq[0].f);
    assert('b' == freq[1].c);
    assert(0.25f == freq[1].f);
    assert('d' == freq[2].c);
    assert(0.25f == freq[2].f);
}

float frequency(ushort c, in Pair[] freq) pure nothrow
{
    const min = frequencyMin(c);
    auto lower = freq.assumeSorted!"a.c < b.c".lowerBound!(SearchPolicy.gallop)(Pair(c));
    if (lower.length < freq.length && freq[lower.length].c == c)
        if (freq[lower.length].f > min)
            return freq[lower.length].f;

    return min;
}

@("frequency returns min if char is not found") unittest
{
    assert(frequencyMin('a') == frequency('a', null));
}

@("frequency single pair") unittest
{
    assert(0.5 == frequency('a', [Pair('a', 0.5)]));
}

@("frequency is capped at min") unittest
{
    const min = frequencyMin('a');
    assert(min == frequency('a', [Pair('a', min * 0.99f)]));
}

@("frequency multiple pairs") unittest
{
    const freq = [Pair('b', 0.25), Pair('d', 0.5), Pair('e', 0.125)];
    assert(frequencyMin('a') == frequency('a', freq));
    assert(0.25 == frequency('b', freq));
    assert(frequencyMin('c') == frequency('c', freq));
    assert(0.5 == frequency('d', freq));
    assert(0.125 == frequency('e', freq));
    assert(frequencyMin('f') == frequency('f', freq));
}

enum frequencyMinCap = 1.0f / 1024;

float frequencyMin(ushort c) pure nothrow
{
    import std.algorithm : min;
    c += !c;
    const res = 0.5f / c;
    return min(res, frequencyMinCap);
}

@("frequencyMin small input is capped") unittest
{
    assert(frequencyMinCap == frequencyMin('A'));
}

@("frequencyMin 0 input") unittest
{
    assert(frequencyMinCap == frequencyMin(0));
}

@("frequencyMin larger input") unittest
{
    assert(frequencyMin(1 << 15) < frequencyMinCap);
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
