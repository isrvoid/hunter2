import std.range;
import std.algorithm;
import std.meta : allSatisfy;

void main()
{
    /*
    DNode root;
    foreach (name; pwLists)
        indexListFile(name, root);
     */
}

void writeToFile(string name, DNode root)
{
    import std.stdio : File;
    auto file = File(name, "wb");
    StoreHeader header;
    file.seek(header.dataOffset);
    // FIXME
}

enum seclistsDir = "/home/user/devel/SecLists"; // path to github.com/danielmiessler/SecLists

enum pwDir = seclistsDir ~ "/Passwords/";
enum pwLists = [pwDir ~ "bt4-password.txt",
             pwDir ~ "darkc0de.txt",
             pwDir ~ "openwall.net-all.txt",
             pwDir ~ "Leaked-Databases/alleged-gmail-passwords.txt",
             pwDir ~ "Leaked-Databases/md5decryptor.uk.txt",
             //pwDir ~ "Leaked-Databases/rockyou.txt", // needs extracted rockyou.txt.tar.gz
];

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

void indexSlide(size_t windowSize = 0, R)(R r, ref ShovelNode root) pure
{
    while (!r.empty)
    {
        static if (windowSize > 0)
            r.take(windowSize).index(root);
        else
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

@("indexSlide window") unittest
{
    ShovelNode expect, root;
    "the".index(expect);
    "he ".index(expect);
    "e q".index(expect);
    " qu".index(expect);
    "qui".index(expect);
    "uic".index(expect);
    "ick".index(expect);
    "ck ".index(expect);
    "k b".index(expect);
    " br".index(expect);
    "bro".index(expect);
    "row".index(expect);
    "own".index(expect);
    "wn ".index(expect);
    "n f".index(expect);
    " fo".index(expect);
    "fox".index(expect);
    "ox".index(expect);
    "x".index(expect);

    "the quick brown fox".indexSlide!3(root);
    assert(expect == root);
}

void indexListFile(string name, ref DNode root, size_t shovelSize = 25_000)
{
    import std.stdio : File;
    import std.encoding : sanitize;
    import std.string : strip;
    import std.uni : asLowerCase;

    ShovelNode shovel;
    size_t lineCount;
    foreach (line; File(name).byLineCopy!dchar)
    {
        line.sanitize
            .strip
            .asLowerCase
            .limitRepetitions!3
            .take(28)
            .array
            .indexSlide!12(shovel);

        if (++lineCount % shovelSize == 0)
        {
            merge(root, shovel.to!DNode);
            shovel = ShovelNode();
        }
    }
    merge(root, shovel.to!DNode);
}

struct DNode
{
    dchar c;
    float f = 0.0f;
    DNode[] child;

    int opCmp(ref const DNode other) const pure nothrow @safe
    {
        return (c > other.c) - (c < other.c);
    }
}

size_t mergeLength(alias cmp = "(a > b) - (a < b)", R1, R2)(R1 a, R2 b) pure @safe
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
    size_t expect = std.algorithm.merge(a, b).uniq.walkLength;
    assert(expect == mergeLength(a, b));
}

@("mergeLength non strictly ordered input") unittest
{
    assert(11 == mergeLength("abbceee", "aabbbdeeee"));
}

void merge(ref DNode a, DNode b) pure nothrow @safe
in (a.c == b.c, "Merging nodes should have equal chars")
{
    a.f += b.f;
    // common case is merging smaller node into bigger one
    if (!b.child)
        return;

    ptrdiff_t ai = a.child.length - 1;
    ptrdiff_t bi = b.child.length - 1;
    immutable mergeLength = mergeLength!"a.opCmp(b)"(a.child, b.child);
    a.child.length = mergeLength;
    for (ptrdiff_t wi = mergeLength - 1; wi >= 0; --wi)
    {
        immutable unindexable = (bi < 0) - (ai < 0);
        switch (unindexable ? unindexable : a.child[ai].opCmp(b.child[bi]))
        {
            case -1:
                a.child[wi] = b.child[bi--];
                break;
            case 1:
                a.child[wi] = a.child[ai--];
                break;
            case 0:
                a.child[wi] = a.child[ai--];
                a.child[wi].merge(b.child[bi--]);
                break;
            default: assert(0);
        }
    }
}

@("merge init nodes") unittest
{
    DNode a;
    a.merge(DNode());
    assert(a == DNode());
}

@("merge adds f") unittest
{
    auto a = DNode('a', 0.5);
    a.merge(DNode('a', 0));
    assert(DNode('a', 0.5) == a);
    a.merge(DNode('a', 0.5));
    assert(DNode('a', 1) == a);
}

@("merge leaf f(0) node has no effect") unittest
{
    auto expect = DNode('a', 42, [DNode('a'), DNode('b')]);
    auto node = expect;
    node.merge(DNode('a'));
    assert(expect == node);
}

@("merge into leaf f(0) node effectively overwrites it") unittest
{
    auto expect = DNode('a', 42, [DNode('a'), DNode('b')]);
    auto node = DNode('a');
    node.merge(expect);
    assert(expect == node);
}

@("merge unequal children") unittest
{
    auto expect = DNode('x', 0, [DNode('a', 1), DNode('b', 2)]);
    auto node = DNode('x', 0, [DNode('a', 1)]);
    node.merge(DNode('x', 0, [DNode('b', 2)]));
    assert(expect == node);
}

@("merge children preserves order") unittest
{
    auto expect = DNode('x', 0, [DNode('a', 1), DNode('b', 2)]);
    auto node = DNode('x', 0, [DNode('b', 2)]);
    node.merge(DNode('x', 0, [DNode('a', 1)]));
    assert(expect == node);
}

@("merge adds child's f") unittest
{
    auto expect = DNode('x', 0, [DNode('a', 2)]);
    auto node = DNode('x', 0, [DNode('a', 1)]);
    node.merge(node);
    assert(expect == node);
}

@("merge depth > 2") unittest
{
    auto a = DNode('x', 1, [
            DNode('a', 2, [DNode('A', 5)]),
            DNode('b', 3, [DNode('B', 6, [DNode('1', 8)])]),
            DNode('d', 4, [DNode('C', 7)])]);
    auto b = DNode('x', 10, [
            DNode('a', 20, [DNode('A', 50)]),
            DNode('b', 30, [DNode('B', 60, [DNode('0', 90), DNode('1', 80)])]),
            DNode('c', 35),
            DNode('d', 40, [DNode('C', 70)])]);
    auto expect = DNode('x', 11, [
            DNode('a', 22, [DNode('A', 55)]),
            DNode('b', 33, [DNode('B', 66, [DNode('0', 90), DNode('1', 88)])]),
            DNode('c', 35),
            DNode('d', 44, [DNode('C', 77)])]);

    a.merge(b);
    assert(expect == a);
}

DNode to(T : DNode)(in ShovelNode sn) pure nothrow @safe
{
    static void recurse(in ShovelNode[dchar] sn, ref DNode[] node)
    {
        node.reserve(sn.length);
        foreach (kv; sn.byKeyValue)
        {
            auto v = kv.value;
            DNode n = DNode(kv.key, v.count);
            if (v.node)
                recurse(v.node, n.child);
            node ~= n;
        }
        node.sort;
    }

    auto root = DNode();
    root.f = sn.count;
    recurse(sn.node, root.child);
    return root;
}

@("convert empty node") unittest
{
    assert(DNode() == ShovelNode().to!DNode);
}

@("convert single char node") unittest
{
    DNode expect;
    expect.child = [DNode('a', 1)];
    ShovelNode sn;
    "a".index(sn);
    assert(expect == sn.to!DNode);
}

@("convert sequence") unittest
{
    DNode expect;
    expect.child = [DNode('a', 1, [DNode('b', 1, [DNode('c', 1)])])];
    ShovelNode sn;
    "abc".index(sn);
    assert(expect == sn.to!DNode);
}

@("convert simple input") unittest
{
    DNode expect;
    expect.child = [
        DNode('a', 1, [DNode('b', 1,)]),
        DNode('d', 3, [DNode('e', 2, [DNode('f', 1)])]),
        DNode('g', 1, [DNode('h', 1)])
    ];
    ShovelNode sn;
    "ab".index(sn);
    "def".index(sn);
    "de".index(sn);
    "d".index(sn);
    "gh".index(sn);
    assert(expect == sn.to!DNode);
}

@("convert sorts") unittest
{
    DNode expect;
    expect.child = [DNode('a', 5, [DNode('a', 1), DNode('b', 1), DNode('c', 1), DNode('d', 1), DNode('e', 1)])];
    ShovelNode sn;
    "ad".index(sn);
    "aa".index(sn);
    "ac".index(sn);
    "ae".index(sn);
    "ab".index(sn);
    assert(expect == sn.to!DNode);
}

void normalize(ref DNode root) pure nothrow @safe
{
    auto fun = function(ref DNode node)
    {
        immutable fNorm = 1.0f / node.child.map!"a.f".fold!max(0.0f);
        node.child.each!((ref a) { a.f *= fNorm; });
    };
    recurse!fun(root);
}

@("normalize init DNode") unittest
{
    DNode node;
    node.normalize;
}

@("normalize single child") unittest
{
    auto expect = [DNode('a', 1)];
    auto root = DNode();
    root.child ~= DNode('a', 42);
    root.normalize;
    assert(expect == root.child);
}

@("normalize equal f") unittest
{
    auto expect = [DNode('a', 1), DNode('b', 1), DNode('c', 1)];
    auto root = DNode();
    root.child = [DNode('a', 42), DNode('b', 42), DNode('c', 42)];
    root.normalize;
    assert(expect == root.child);
}

@("normalize sets f to realative ratio") unittest
{
    auto expect = [DNode('a', 1), DNode('b', 0.5), DNode('c', 0.5)];
    auto root = DNode();
    root.child = [DNode('a', 2), DNode('b', 1), DNode('c', 1)];
    root.normalize;
    assert(expect == root.child);
}

@("normalize is recursive") unittest
{
    auto expect = [
        DNode('a', 0.75, [DNode('b', 1, [DNode('c', 0.5), DNode('d', 1)])]),
        DNode('e', 1, [DNode('f', 1), DNode('g', 0.25)])
    ];
    auto root = DNode();
    root.child = [
        DNode('a', 6, [DNode('b', 3, [DNode('c', 1), DNode('d', 2)])]),
        DNode('e', 8, [DNode('f', 4), DNode('g', 1)])
    ];
    root.normalize;
    assert(expect == root.child);
}

struct Ratio
{
    import std.math : exp, log;

    this(double val)
    in (val >= 0.0 && val <= 1.0)
    {
        if (val <= zeroStep)
            ratio = ushort.max;
        else
            ratio = cast(ushort)(log(val) / f + 0.5);
    }

    @property double toDouble()
    out (r; r >= 0.0 && r <= 1.0)
    {
        return ratio == ushort.max ? 0.0 : exp(ratio * f);
    }
    alias toDouble this;

    void opAssign(double rhs)
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

static assert(Node.sizeof == 8);
struct Node
{
    ushort c;
    Ratio f;
    uint child;
}

struct StoreHeader
{
    union
    {
        struct
        {
            ubyte number = 1;
            ubyte nodeSize = Node.sizeof;
            ubyte dataOffset = 6; // log2
        }
        ulong ver;
    }
    uint[3] groupCount;
    ubyte[4] crc;
}

void recurse(alias pred)(ref DNode node) pure
    if (__traits(compiles, pred(node)))
{
    import std.functional : unaryFun;
    unaryFun!pred(node);
    foreach (ref e; node.child)
        recurse!pred(e);
}
