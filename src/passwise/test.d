module passwise.test;

import std.random;
import std.algorithm : each, sort;

import passwise.store : Index;
import passwise.entropy;

@safe:

dstring randomHex(ref Random rnd) pure
{
    enum lut = "0123456789ABCDEF"d;
    // 256 / log2(16) = 64
    auto a = new uint[](64);
    a.each!((ref e) => e = lut[uniform(0, 16, rnd)]);
    return cast(dstring) a.idup;
}

dstring random64(ref Random rnd) pure
{
    // 256 / log2(64) ~ 43
    auto a = new uint[](43);
    a.each!((ref e) => e = ' ' + uniform(0, 64, rnd));
    return cast(dstring) a.idup;
}

size_t[] sampleBits(alias pred)(size_t n, ref in Index index)
{
    auto rnd = Random(unpredictableSeed);
    auto a = new size_t[](n);
    a.each!((ref e) => e = pred(rnd).prob(index).bits);
    a.sort;
    return a;
}
