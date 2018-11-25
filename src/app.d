import std.range;
import std.algorithm.comparison : equal;

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

struct Node
{
    Node[dchar] node;
    size_t count;
    alias node this;
}

void index(ref Node node, string s) pure @system
{
    if (s.empty)
        return;

    auto next = &node.require(s[0]);
    ++next.count;
    index(*next, s[1 .. $]);
}

@("index empty input") unittest
{
    Node root;
    root.index("");
    assert(root.empty);
}

@("index single char") unittest
{
    Node root;
    root.index("a");
    assert(1 == root['a'].count);
    assert(root['a'].empty);
}

@("index string") unittest
{
    Node root;
    root.index("ab");
    assert(1 == root['a'].count);
    assert(1 == root['a']['b'].count);
    assert(root['a']['b'].empty);
}

@("index different strings") unittest
{
    Node root;
    root.index("ab");
    root.index("cd");
    assert(1 == root['a'].count);
    assert(1 == root['a']['b'].count);
    assert(root['a']['b'].empty);
    assert(1 == root['c'].count);
    assert(1 == root['c']['d'].count);
    assert(root['c']['d'].empty);
}

@("index overlapping strings") unittest
{
    Node root;
    root.index("ab");
    root.index("ab");
    assert(2 == root['a'].count);
    assert(2 == root['a']['b'].count);
    assert(root['a']['b'].empty);

    root.index("abc");
    assert(3 == root['a'].count);
    assert(3 == root['a']['b'].count);
    assert(1 == root['a']['b']['c'].count);
    assert(root['a']['b']['c'].empty);
}

@("branches do not merge") unittest
{
    Node root;
    root.index("ac");
    root.index("bc");
    assert(1 == root['a']['c'].count);
    assert(1 == root['b']['c'].count);
}

@("branches do not merge after separation") unittest
{
    Node root;
    root.index("abd");
    root.index("acd");
    assert(1 == root['a']['b']['d'].count);
    assert(1 == root['a']['c']['d'].count);
}
