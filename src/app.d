import std.range;

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
	return LimitRepetitions!(Range, maxRep)(r).array;
}

@("limitRepetitions empty input") unittest
{
	assert("" == "".limitRepetitions());
}

@("repetitions up to max are unaffected") unittest
{
	assert("a" == "a".limitRepetitions);
	assert("aabb" == "aabb".limitRepetitions!2);
}

@("repetitions above max are skipped") unittest
{
	assert("a" == "aa".limitRepetitions);
	assert("aabb" == "aaaabbb".limitRepetitions!2);
}

@("limitRepetitions misc input") unittest
{
    enum noRep = "The quick brown fox jumps over the lazy dog.";
    assert(noRep == noRep.limitRepetitions);

    assert("start midle" == "ssssssssstart          midddddddddddddle".limitRepetitions);
    assert("middlee endd" == "middleeeeeeeeeeeeeeeee endddddddddddddddddddddd".limitRepetitions!2);
    assert("middllleee" == "middlllllllllllllllllllllllllllllleee".limitRepetitions!3);
}
