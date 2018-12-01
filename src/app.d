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

void indexListFile(string name, ref Node root, size_t shovelSize = 25_000)
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
            .take(32)
            .array
            .indexSlide(shovel);

        if (++lineCount % shovelSize == 0)
        {
            merge(root, shovel.to!Node);
            shovel = ShovelNode();
        }
    }
    merge(root, shovel.to!Node);
}

struct Node
{
    dchar c;
    float f = 0.0f;
    Node[] child;

    int opCmp(ref const Node other) const pure nothrow @safe
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

void merge(ref Node a, Node b) pure nothrow @safe
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
    Node a;
    a.merge(Node());
    assert(a == Node());
}

@("merge adds f") unittest
{
    auto a = Node('a', 0.5);
    a.merge(Node('a', 0));
    assert(Node('a', 0.5) == a);
    a.merge(Node('a', 0.5));
    assert(Node('a', 1) == a);
}

@("merge leaf f(0) node has no effect") unittest
{
    auto expect = Node('a', 42, [Node('a'), Node('b')]);
    auto node = expect;
    node.merge(Node('a'));
    assert(expect == node);
}

@("merge into leaf f(0) node effectively overwrites it") unittest
{
    auto expect = Node('a', 42, [Node('a'), Node('b')]);
    auto node = Node('a');
    node.merge(expect);
    assert(expect == node);
}

@("merge unequal children") unittest
{
    auto expect = Node('x', 0, [Node('a', 1), Node('b', 2)]);
    auto node = Node('x', 0, [Node('a', 1)]);
    node.merge(Node('x', 0, [Node('b', 2)]));
    assert(expect == node);
}

@("merge children preserves order") unittest
{
    auto expect = Node('x', 0, [Node('a', 1), Node('b', 2)]);
    auto node = Node('x', 0, [Node('b', 2)]);
    node.merge(Node('x', 0, [Node('a', 1)]));
    assert(expect == node);
}

@("merge adds child's f") unittest
{
    auto expect = Node('x', 0, [Node('a', 2)]);
    auto node = Node('x', 0, [Node('a', 1)]);
    node.merge(node);
    assert(expect == node);
}

@("merge depth > 2") unittest
{
    auto a = Node('x', 1, [
            Node('a', 2, [Node('A', 5)]),
            Node('b', 3, [Node('B', 6, [Node('1', 8)])]),
            Node('d', 4, [Node('C', 7)])]);
    auto b = Node('x', 10, [
            Node('a', 20, [Node('A', 50)]),
            Node('b', 30, [Node('B', 60, [Node('0', 90), Node('1', 80)])]),
            Node('c', 35),
            Node('d', 40, [Node('C', 70)])]);
    auto expect = Node('x', 11, [
            Node('a', 22, [Node('A', 55)]),
            Node('b', 33, [Node('B', 66, [Node('0', 90), Node('1', 88)])]),
            Node('c', 35),
            Node('d', 44, [Node('C', 77)])]);

    a.merge(b);
    assert(expect == a);
}

Node to(T : Node)(in ShovelNode sn) pure nothrow @safe
{
    void toHelper(in ShovelNode[dchar] sn, ref Node[] node) pure nothrow @safe
    {
        import std.algorithm.sorting : sort;
        node.reserve(sn.length);
        foreach (ref kv; sn.byKeyValue)
        {
            auto v = kv.value;
            Node n = Node(kv.key, v.count);
            if (v.node)
                toHelper(v.node, n.child);
            node ~= n;
        }
        node.sort;
    }

    auto root = Node();
    root.f = sn.count;
    toHelper(sn.node, root.child);
    return root;
}

@("convert empty node") unittest
{
    assert(Node() == ShovelNode().to!Node);
}

@("convert single char node") unittest
{
    Node expect;
    expect.child = [Node('a', 1)];
    ShovelNode sn;
    "a".index(sn);
    assert(expect == sn.to!Node);
}

@("convert sequence") unittest
{
    Node expect;
    expect.child = [Node('a', 1, [Node('b', 1, [Node('c', 1)])])];
    ShovelNode sn;
    "abc".index(sn);
    assert(expect == sn.to!Node);
}

@("convert simple input") unittest
{
    Node expect;
    expect.child = [
        Node('a', 1, [Node('b', 1,)]),
        Node('d', 3, [Node('e', 2, [Node('f', 1)])]),
        Node('g', 1, [Node('h', 1)])
    ];
    ShovelNode sn;
    "ab".index(sn);
    "def".index(sn);
    "de".index(sn);
    "d".index(sn);
    "gh".index(sn);
    assert(expect == sn.to!Node);
}

@("convert sorts") unittest
{
    Node expect;
    expect.child = [Node('a', 5, [Node('a', 1), Node('b', 1), Node('c', 1), Node('d', 1), Node('e', 1)])];
    ShovelNode sn;
    "ad".index(sn);
    "aa".index(sn);
    "ac".index(sn);
    "ae".index(sn);
    "ab".index(sn);
    assert(expect == sn.to!Node);
}
