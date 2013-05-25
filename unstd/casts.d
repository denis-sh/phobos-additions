/**
Functions for casts.

Copyright: Denis Shelomovskij 2013

License: $(HTTP boost.org/LICENSE_1_0.txt, Boost License 1.0).

Authors: Denis Shelomovskij
*/
module unstd.casts;


@safe pure nothrow:

// TODO: document functions better.

/// Stuff for $(D class)/$(D interface) dynamic casting.
template typesDynamicCastable(To, From)
{
	enum typesDynamicCastable = (is(From == class) || is(From == interface)) && (is(To == class) || is(To == interface));
}

/// ditto
@property inout(To) tryDynamicCast(To, From)(inout(From) o) @trusted
if(typesDynamicCastable!(To, From))
{
	return cast(inout(To)) o;
}

/// ditto
@property bool dynamicCastable(To, From)(inout(From) o) @trusted
if(typesDynamicCastable!(To, From))
{
	return !o || cast(inout(To)) o;
}

/// ditto
@property inout(To) dynamicCast(To, From)(inout(From) o)
if(typesDynamicCastable!(To, From))
in { assert(o.dynamicCastable!To); }
body
{
	return o.tryDynamicCast!To;
}


/// ditto
template typesUpCastable(To, From)
{
	enum typesUpCastable = (is(From == class) || is(From == interface)) && is(To : From) || is(From == Object);
}

/// ditto
@property inout(To) tryUpCast(To, From)(inout(From) o) @trusted
if(typesUpCastable!(To, From))
{
	return cast(inout(To)) o;
}

/// ditto
@property bool upCastable(To, From)(inout(From) o) @trusted
if(typesUpCastable!(To, From))
{
	return !o || cast(inout(To)) o;
}

/// ditto
@property inout(To) upCast(To, From)(inout(From) o)
if(typesUpCastable!(To, From))
in { assert(o.upCastable!To); }
body
{
	return o.tryUpCast!To;
}


/// ditto
template typesDownCastable(To, From)
{
	enum typesDownCastable = (is(To == class) || is(To == interface)) && is(From : To) || is(To == Object);
}

/// ditto
@property inout(To) downCast(To, From)(inout(From) o) @trusted
if(typesDownCastable!(To, From))
{
	return cast(inout(To)) o;
}


///
unittest
{
	class A { }
	class B: A { }

	B b = new B;
	A a = b;
	assert(a.upCast!B is b);
	assert(b.downCast!A is a);
	static assert(!__traits(compiles, b.upCast!A));
	static assert(!__traits(compiles, a.downCast!B));
	const ca = a;
	static assert(is(typeof(ca.upCast!B) == const B));
	const cb = b;
	static assert(is(typeof(cb.downCast!A) == const A));


	class X { }
	X x;
	static assert(!__traits(compiles, x.upCast!A));
}

///
unittest
{
	interface I { }
	class C: I { }
	C c = new C;
	I i = c;
	assert(c.downCast!I is i);
	Object o = c;
	assert(o.upCast!I is c);
	assert(i.downCast!Object is c);

	assert(i.dynamicCast!C is c);
	assert(o.dynamicCast!C is c);
	assert(o.dynamicCast!I is i);
}
