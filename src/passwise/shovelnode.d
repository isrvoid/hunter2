module passwise.shovelnode;

import std.range;
import passwise.dnode : DNode;

struct ShovelNode
{
    ShovelNode[uint] node;
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

@("index branches do not merge") unittest
{
    ShovelNode root;
    "ac".index(root);
    "bc".index(root);
    assert(1 == root['a']['c'].count);
    assert(1 == root['b']['c'].count);
}

@("index branches do not merge after separation") unittest
{
    ShovelNode root;
    "abd".index(root);
    "acd".index(root);
    assert(1 == root['a']['b']['d'].count);
    assert(1 == root['a']['c']['d'].count);
}

void indexDiff(R)(R r, ref ShovelNode node) pure
{
    void indexDiff(R)(auto ref R r, ref ShovelNode node, uint prev)
    {
        r.popFront();
        if (r.empty)
            return;

        auto iNode = &node.require(r.front - prev);
        ++iNode.count;
        indexDiff(r, *iNode, r.front);
    }

    if (r.empty)
        return;

    indexDiff(r, node, r.front);
}

@("indexDiff empty input") unittest
{
    ShovelNode root;
    "".indexDiff(root);
    assert(root.empty);
}

@("indexDiff single char") unittest
{
    ShovelNode root;
    "a".indexDiff(root);
    assert(root.empty);
}

@("indexDiff string") unittest
{
    ShovelNode root;
    "ab".indexDiff(root);
    assert(1 == root[1].count);
    assert(root[1].empty);
}

@("indexDiff negative diff") unittest
{
    ShovelNode root;
    "ba".indexDiff(root);
    assert(1 == root[-1].count);
    assert(root[-1].empty);
}

@("indexDiff unequal diffs") unittest
{
    ShovelNode root;
    "aa".indexDiff(root);
    "ab".indexDiff(root);
    assert(1 == root[0].count);
    assert(root[0].empty);
    assert(1 == root[1].count);
    assert(root[1].empty);
}

@("indexDiff equal diffs merge") unittest
{
    ShovelNode root;
    "ab".indexDiff(root);
    "ab".indexDiff(root);
    "cd".indexDiff(root);
    assert(3 == root[1].count);
    assert(root[1].empty);
}

@("indexDiff equal diffs from separate branches do not merge") unittest
{
    ShovelNode root;
    "acd".indexDiff(root);
    "bcd".indexDiff(root);
    assert(1 == root[2][1].count);
    assert(1 == root[1][1].count);
}

void slide(alias pred, size_t windowSize, size_t minWindowSize = windowSize, R)(R r, ref ShovelNode root) pure
{
    static assert(minWindowSize && windowSize >= minWindowSize);
    if (r.length <= minWindowSize)
        return pred(r, root);

    const size_t sliceCount = r.length - minWindowSize + 1;
    for (size_t i = 0; i < sliceCount; ++i)
    {
        pred(r.take(windowSize), root);
        r.popFront();
    }
}

@("slide empty input") unittest
{
    ShovelNode root;
    "".slide!(index, 1)(root);
    assert(root.empty);
}

@("slide single char") unittest
{
    ShovelNode root;
    "a".slide!(index, 1)(root);
    assert(1 == root['a'].count);
    assert(root['a'].empty);
}

@("slide string") unittest
{
    ShovelNode expect, root;
    "bro".index(expect);
    "row".index(expect);
    "own".index(expect);
    "wn ".index(expect);
    "n f".index(expect);
    " fo".index(expect);
    "fox".index(expect);

    "brown fox".slide!(index, 3)(root);
    assert(expect == root);
}

@("slide window == input.length") unittest
{
    ShovelNode expect, root;
    "foo".index(expect);

    "foo".slide!(index, 3)(root);
    assert(expect == root);
}

@("slide window > input.length") unittest
{
    ShovelNode expect, root;
    "foo".index(expect);

    "foo".slide!(index, 4)(root);
    assert(expect == root);
}

@("slide min window") unittest
{
    ShovelNode expect, root;
    "brown fox".index(expect);
    "rown fox".index(expect);
    "own fox".index(expect);

    "brown fox".slide!(index, size_t.max, 7)(root);
    assert(expect == root);
}

@("slide window with min") unittest
{
    ShovelNode expect, root;
    "the quick brown ".index(expect);
    "he quick brown f".index(expect);
    "e quick brown fo".index(expect);
    " quick brown fox".index(expect);
    "quick brown fox".index(expect);
    "uick brown fox".index(expect);
    "ick brown fox".index(expect);
    "ck brown fox".index(expect);

    "the quick brown fox".slide!(index, 16, 12)(root);
    assert(expect == root);
}

@("slide window with min; window == input.length") unittest
{
    ShovelNode expect, root;
    "brown fox".index(expect);
    "rown fox".index(expect);
    "own fox".index(expect);

    "brown fox".slide!(index, 9, 7)(root);
    assert(expect == root);
}

@("slide window with min; min == input.length") unittest
{
    ShovelNode expect, root;
    "brown fox".index(expect);

    "brown fox".slide!(index, size_t.max, 9)(root);
    assert(expect == root);
}

@("slide window with min; min > input.length") unittest
{
    ShovelNode expect, root;
    "brown fox".index(expect);

    "brown fox".slide!(index, size_t.max, 10)(root);
    assert(expect == root);
}

DNode to(T : DNode)(in ShovelNode sn) pure nothrow @safe
{
    import std.algorithm : sort;
    static void recurse(in ShovelNode[uint] sn, ref DNode[] node)
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
