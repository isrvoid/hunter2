module passwise.dnode;

import std.traits : ReturnType;
import passwise.node;
import passwise.shovelnode;

struct DNode
{
    uint v;
    float f = 0.0f;
    DNode[] child;

    int opCmp(ref const DNode other) const pure nothrow @safe
    {
        return (v > other.v) - (v < other.v);
    }
}

void merge(ref DNode a, DNode b) pure nothrow @safe
in (a.v == b.v, "Merging nodes should have equal values")
{
    import passwise.util : mergeLength;
    a.f += b.f;
    // common case is merging smaller node into bigger one
    if (!b.child)
        return;

    ptrdiff_t ai = a.child.length - 1;
    ptrdiff_t bi = b.child.length - 1;
    immutable newLength = mergeLength!"a.opCmp(b)"(a.child, b.child);
    a.child.length = newLength;
    for (ptrdiff_t wi = newLength - 1; wi >= 0; --wi)
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
            default:
                assert(0);
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

void normalize(ref DNode root) pure nothrow @safe
{
    auto fun = function(ref DNode node)
    {
        import std.algorithm : map, sum, each;
        const fNorm = 1.0f / node.child.map!"a.f".sum;
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
    auto expect = [DNode('a', 0.5), DNode('b', 0.5)];
    auto root = DNode();
    root.child = [DNode('a', 42), DNode('b', 42)];
    root.normalize;
    assert(expect == root.child);
}

@("normalize converts f to ratio") unittest
{
    auto expect = [DNode('a', 0.5), DNode('b', 0.25), DNode('c', 0.25)];
    auto root = DNode();
    root.child = [DNode('a', 2), DNode('b', 1), DNode('c', 1)];
    root.normalize;
    assert(expect == root.child);
}

@("normalize is recursive") unittest
{
    auto expect = [
        DNode('a', 0.375, [DNode('b', 1, [DNode('c', 0.125), DNode('d', 0.875)])]),
        DNode('e', 0.625, [DNode('f', 0.75), DNode('g', 0.25)])
    ];
    auto root = DNode();
    root.child = [
        DNode('a', 3, [DNode('b', 3, [DNode('c', 1), DNode('d', 7)])]),
        DNode('e', 5, [DNode('f', 3), DNode('g', 1)])
    ];
    root.normalize;
    assert(expect == root.child);
}

auto getStats(const DNode root)
{
    import std.algorithm : max;
    import std.typecons : tuple;
    size_t count1 = 1, count2, countMult, multNodeCount;
    dchar maxChar = 0;

    root.recurse!((ref const DNode n)
    {
        immutable length = n.child.length;
        if (length == 1)
            ++count1;
        else if (length == 2)
            ++count2;
        else if (length >= 3)
        {
            ++countMult;
            multNodeCount += length;
        }
        maxChar = max(maxChar, n.v);
    });

    return tuple!("count1", "count2", "countMult", "multNodeCount", "maxChar")
        (count1, count2, countMult, multNodeCount, maxChar);
}

auto checkCompactFit(ReturnType!getStats stats)
{
    enum Result
    {
        ok,
        index1,
        index2,
        indexMult,
        charCast,
        multNodeCount
    }

    if (stats.count1 > NodeIndexLimit.end1 - NodeIndexLimit.start1)
        return Result.index1;

    if (stats.count2 > NodeIndexLimit.end2 - NodeIndexLimit.start2)
        return Result.index2;

    if (stats.countMult > NodeIndexLimit.endMult - NodeIndexLimit.startMult)
        return Result.indexMult;

    if (stats.maxChar > ushort.max)
        return Result.charCast;

    if (stats.multNodeCount > uint.max) // count+1 index marks end of last group
        return Result.multNodeCount;

    return Result.ok;
}

void recurse(alias pred, T : const DNode)(auto ref T node) pure
    if (__traits(compiles, pred(node)))
{
    import std.functional : unaryFun;
    unaryFun!pred(node);
    foreach (ref e; node.child)
        recurse!pred(e);
}

NodeStore compact(const DNode root)
{
    import std.conv : to;
    immutable stats = getStats(root);
    immutable check = checkCompactFit(stats);
    if (check)
        throw new Exception("Can't compact: " ~ check.to!string);

    NodeStore ns;
    ns[0].length = stats.count1;
    ns[1].length = stats.count2 * 2;
    ns[2].length = stats.countMult + 1;
    ns[3].length = stats.multNodeCount;

    uint[3] index;
    uint multIndex;
    void recurse(ref const DNode dn, ref Node n)
    {
        switch (dn.child.length)
        {
            case 0:
                n = Node(cast(ushort) dn.v, Ratio(dn.f), 0);
                break;
            case 1:
                n = Node(cast(ushort) dn.v, Ratio(dn.f), index[0] + NodeIndexLimit.start1);
                uint i = index[0];
                ++index[0];
                recurse(dn.child[0], ns[0][i]);
                break;
            case 2:
                n = Node(cast(ushort) dn.v, Ratio(dn.f), index[1] + NodeIndexLimit.start2);
                uint i = index[1] * 2;
                ++index[1];
                recurse(dn.child[0], ns[1][i]);
                recurse(dn.child[1], ns[1][i + 1]);
                break;
            default:
                n = Node(cast(ushort) dn.v, Ratio(dn.f), index[2] + NodeIndexLimit.startMult);
                uint i = multIndex;
                ns[2][index[2]] = multIndex;
                ++index[2];
                multIndex += dn.child.length;
                foreach (ref e; dn.child)
                    recurse(e, ns[3][i++]);
                break;
        }
    }
    ++index[0];
    recurse(root, ns[0][0]);
    ns[2][$ - 1] = multIndex;
    return ns;
}

version (unittest)
{
    private bool treesEqual(const DNode root, const NodeStore ns)
    {
        import std.math : approxEqual;
        bool res = true;
        void recurse(ref const DNode dn, Node n)
        {
            auto nsChild = child(ns, n);
            res &= dn.v == n.v && approxEqual(dn.f, n.f, ratioRelPrecision, 1e-7) && dn.child.length == nsChild.length;
            foreach (i, ref e; dn.child)
                recurse(e, nsChild[i]);
        }
        recurse(root, ns[0][0]);
        return res;
    }
}

@("compact empty root") unittest
{
    const dn = DNode('x', 0.123);
    assert(treesEqual(dn, compact(dn)));
}

@("compact single char") unittest
{
    DNode dn;
    dn.child = [DNode('a', 0.42)];
    assert(treesEqual(dn, compact(dn)));
}

@("compact string") unittest
{
    ShovelNode sn;
    "foobar".slide!(index, size_t.max, 1)(sn);
    auto dn = sn.to!DNode;
    normalize(dn);
    assert(treesEqual(dn, compact(dn)));
}

@("compact lines") unittest
{
    auto lines = ["the", "quick", "brown", "fox", "jumps", "over", "lazy", "dog",
         "the quick", "brown fox", "jumps over", "lazy dog",
         "the quick brown", "fox jumps over", "the lazy dog",
         "the quick brown fox", "jumps over the lazy dog",
         "the quick brown fox jumps over the lazy dog"];
    ShovelNode sn;
    foreach (line; lines)
        line.slide!(index, size_t.max, 1)(sn);
    auto dn = sn.to!DNode;
    normalize(dn);
    assert(treesEqual(dn, compact(dn)));
}

version (unittestLong)
{
    string readTestList()
    {
        import std.stdio : File;
        import std.path : buildPath;
        import std.zlib : UnCompress;
        auto f = File(buildPath("test", "myspace.txt.gz"));
        auto buf = new ubyte[](f.size);
        f.rawRead(buf);
        auto gz = new UnCompress();
        return cast(string) gz.uncompress(buf);
    }

    @("full NodeStore stack") unittest
    {
        import std.array : array;
        import std.range : take;
        import std.path : buildPath;
        import std.file : tempDir;
        import std.string : lineSplitter;
        import passwise.util : limitRepetitions;
        auto list = readTestList();

        ShovelNode shovel;
        foreach (line; list.lineSplitter)
        {
            line.limitRepetitions!3
                .take(32)
                .array
                .slide!(index, 16)(shovel);
        }
        auto root = shovel.to!DNode;
        normalize(root);

        const name = tempDir.buildPath("test_nodes");
        writeFile(compact(root), name);

        const ns = readFile(name);
        assert(treesEqual(root, ns));
    }
}
