import std.range;
import std.algorithm : equal, isSorted;
import std.meta : allSatisfy;

void main()
{
}

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
        return _input.empty();
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

struct ShovelNode
{
    ShovelNode[dchar] node;
    size_t count;
    alias node this;
}

void index(R)(auto ref R r, ref ShovelNode node) pure
{
    if (r.empty)
        return;

    auto iNode = &node.require(r.front);
    r.popFront();
    ++iNode.count;
    index(r, *iNode);
}

@("index empty input") unittest
{
    ShovelNode root;
    "".index(root);
    assert(root.empty);
}

@("index single char") unittest
{
    ShovelNode root;
    "a".index(root);
    assert(1 == root['a'].count);
    assert(root['a'].empty);
}

@("index string") unittest
{
    ShovelNode root;
    "ab".index(root);
    assert(1 == root['a'].count);
    assert(1 == root['a']['b'].count);
    assert(root['a']['b'].empty);
}

@("index different strings") unittest
{
    ShovelNode root;
    "ab".index(root);
    "cd".index(root);
    assert(1 == root['a'].count);
    assert(1 == root['a']['b'].count);
    assert(root['a']['b'].empty);
    assert(1 == root['c'].count);
    assert(1 == root['c']['d'].count);
    assert(root['c']['d'].empty);
}

@("index overlapping strings") unittest
{
    ShovelNode root;
    "ab".index(root);
    "ab".index(root);
    assert(2 == root['a'].count);
    assert(2 == root['a']['b'].count);
    assert(root['a']['b'].empty);

    "abc".index(root);
    assert(3 == root['a'].count);
    assert(3 == root['a']['b'].count);
    assert(1 == root['a']['b']['c'].count);
    assert(root['a']['b']['c'].empty);
}

@("branches do not merge") unittest
{
    ShovelNode root;
    "ac".index(root);
    "bc".index(root);
    assert(1 == root['a']['c'].count);
    assert(1 == root['b']['c'].count);
}

@("branches do not merge after separation") unittest
{
    ShovelNode root;
    "abd".index(root);
    "acd".index(root);
    assert(1 == root['a']['b']['d'].count);
    assert(1 == root['a']['c']['d'].count);
}

void indexSlide(R)(R r, ref ShovelNode root) pure
{
    while (!r.empty)
    {
        r.save.index(root);
        r.popFront();
    }
}

@("indexSlide empty input") unittest
{
    ShovelNode root;
    "".indexSlide(root);
    assert(root.empty);
}

@("indexSlide single char") unittest
{
    ShovelNode root;
    "a".indexSlide(root);
    assert(1 == root['a'].count);
    assert(root['a'].empty);
}

@("indexSlide string") unittest
{
    ShovelNode expect, root;
    "aabc".index(expect);
    "abc".index(expect);
    "bc".index(expect);
    "c".index(expect);

    "aabc".indexSlide(root);
    assert(expect == root);
}

void indexListFile(string name, ref ShovelNode root)
{
    import std.stdio : File;
    import std.encoding : sanitize;
    import std.string : strip;
    import std.uni : asLowerCase;

    foreach (line; File(name).byLineCopy!dchar)
    {
        line.sanitize
            .strip
            .asLowerCase
            .limitRepetitions!3
            .take(32)
            .array
            .indexSlide(root);
    }
}

struct Node
{
    dchar id;
    float f;
    Node[] child;
}

size_t mergeLength(alias cmp = "a < b ? -1 : a > b ? 1 : 0", R1, R2)(R1 a, R2 b) pure @safe
if (allSatisfy!(isInputRange, R1, R2))
in (a.isSorted && b.isSorted, "ranges have to be sorted")
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
    import std.algorithm : sort, merge, uniq;
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
