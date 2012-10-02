/** Additions to std.typetuple

Copyright: Denis Shelomovskij 2012

License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).

Authors: Denis Shelomovskij
*/
module unstd.typecons;


public import std.typecons;

import std.string: strip, xformat;
import std.array: appender;
import std.traits: isIntegral, IntegralTypeOf;
import unstd.generictuple: TemplateMap;


private struct EnumMember(Base)
{
	string str, name, valStr;
	Base val;
}

private template enumMembers(Base, members...)
{
	template enumMember(string str)
	{
		enum pos = ()
		{
			// Because std.string.indexOf isn't CTFE-able
			foreach(size_t i, c; str) if(c == '=')
				return i;
			return cast(size_t) -1;
		}();
		static if(pos == -1)
			enum enumMember = EnumMember!Base(str, str.strip(), null);
		else
		{
			enum valStr = str[pos + 1 .. $];
			enum enumMember = EnumMember!Base(str, str[0 .. pos].strip(), valStr, mixin(valStr));
		}
	}

	alias TemplateMap!(enumMember, members) enumMembers;
}

struct FlagEnumImpl(string name, Args...)
{
	private static if(is(Args[0]))
	{
		alias IntegralTypeOf!(Args[0]) Base;
		alias Args[1 .. $] members;
	}
	else
	{
		alias int Base;
		alias Args members;
	}

	private Base val;

	invariant()
	{
		assert(!(val & m_unused));
	}

	@property Base value() const { return val; }

	T opCast(T : bool)() const
	{ return !!val; }

	T opCast(T)() const
		if(isIntegral!T && T.sizeof >= Base.sizeof)
	{ return val; }

	FlagEnumImpl opOpAssign(string op)(in FlagEnumImpl y) if (op == "&" || op == "|")
	{
		mixin(xformat("val %s= y.val;", op));
		return this;
	}

	FlagEnumImpl opBinary(string op)(in FlagEnumImpl y) const if (op == "&" || op == "|")
	{
		FlagEnumImpl t = this;
		return mixin(xformat("t %s= y", op));
	}

	string toString() const
	{
		auto app = appender!string();
		app.put(name);

		immutable bool isOneSet = val && !((val - 1) & val);
		app.put(isOneSet ? "." : ".{");

		bool first = true;
		foreach(i, m; enumMembers)
		{
			if(val & mixin(m.name).value)
			{
				if(!first)
					app.put("|");
				app.put(m.name);
				first = false;
			}
		}
		if(!isOneSet)
			app.put("}");
		return app.data;
	}

	private static string genMembers(EnumMember!Base[] members)
	{
		string s;
		Base defVal = 1, used = 0;
		foreach(i, m; members)
		{
			immutable Base val = m.valStr ? m.val : defVal;
			if(m.valStr)
			{
				assert(val, "Flag value can't be zero: " ~ m.str);
				assert(!((val - 1) & val), "Flag value must contain only one bit set: " ~ m.str);
				assert(!(used & val), "Flag value already used: " ~ m.str);
			}
			else
			{
				assert(!(used & val), "Next bit value already used: " ~ xformat("%s = %s", m.name, val));
				assert(val, "Can't set next bit, integer overflow: " ~ m.name);
			}

			used |= val;

			defVal = cast(Base) (val << 1);

			s ~= xformat("enum FlagEnumImpl %s = FlagEnumImpl(%s);", m.name, val);
		}
		s ~= xformat("private enum Base m_unused = %s;", ~used);
		return s;
	};

	private alias .enumMembers!(Base, members) enumMembers;
	mixin(genMembers([enumMembers]));
}

/**
Creates a set of flags.

Example:
----

mixin flagEnum!("Access", byte, "read = 2", "write", "execute"); // write == 4, execute == 8

assert(cast(uint) Access.init == 0);
assert(cast(uint) Access.write == 4);
assert(cast(uint) Access.execute == 8);

auto folderAccess = Access.read | Access.execute;
auto fileAccess   = Access.read | Access.write | Access.execute;

fileAccess &= folderAccess;
assert(fileAccess == (Access.read | Access.execute));

if(fileAccess)
{
	// have some access
}
else
	assert(0);

import std.stdio;
writeln(fileAccess & Access.read);   // Writes "Access.read"
writeln(fileAccess);                 // Writes "Access.{read|execute}"
writeln(fileAccess & Access.write);  // Writes "Access.{}"
----
*/
mixin template flagEnum(string name, Args...)
{
	mixin("alias FlagEnumImpl!(name, Args) " ~ name ~ ";");
}

unittest
{
	mixin flagEnum!("AB", "a", "b", "cc");
	
	// Types and identifiers
	static assert(is(typeof(AB.a) == AB));
	static assert(is(typeof(AB.a.value) == int));
	static assert(__traits(identifier, AB.a) == "a");
	
	// Values
	static assert(AB.init.value == 0);
	static assert(AB.a.value == 1);
	static assert(AB.cc.value == 4);

	// Conversions to integral types
	static assert(!__traits(compiles, cast(short) AB.b));
	static assert(cast(int) AB.b == 2);
	static assert(cast(uint) AB.b == 2);
	static assert(cast(long) AB.b == 2);

	// Conversions to bool
	static assert(!AB.init);
	static assert(!!AB.a);
	if(AB.init) assert(0); else { }
	if(AB.a) { } else assert(0);

	// Bitwise operations
	static assert(cast(int) (AB.a | AB.b) == (1 | 2));
	static assert((AB.a & AB.b).value == 0);
	static assert((AB.a | AB.b | AB.cc).value == (1 | 2 | 4));
	static assert((AB.a | AB.b & AB.cc) == AB.a);
	static assert(cast(AB) (1 | 2) == (AB.a | AB.b));
	
	// Immutability
	/+ Tests disabled because of implementation @@@BUG@@@
	static assert(!__traits(compiles, AB.init |= AB.a));
	static assert(!__traits(compiles, AB.a |= AB.a));
	static assert(!__traits(compiles, AB.a &= AB.a));
	+/
	
	// Mutability
	auto var = AB.a;
	var |= AB.b;
	assert(var == (AB.a | AB.b));
	var &= AB.b;
	assert(var == AB.b);
	immutable ivar = var;
	static assert(!__traits(compiles, ivar |= AB.b));
	var |= ivar;

	// Restricted operations
	static assert(!__traits(compiles, AB.a == 1));
	static assert(!__traits(compiles, AB.a | 1));
	static assert(!__traits(compiles, AB.a + AB.b));

	mixin flagEnum!("EF", "e", "f");

	static assert(!__traits(compiles, AB.a == EF.e));
	static assert(!__traits(compiles, AB.a | EF.e));
	static assert(!__traits(compiles, AB.a & EF.e));
}

unittest
{
	mixin flagEnum!("ubAB", ubyte, "a", "b", "cc");
	static assert(ubAB.a.value == 1);
	static assert(!__traits(compiles, cast(char) ubAB.b));
	static assert(cast(ubyte) ubAB.b == 2);
	static assert(cast(byte) ubAB.b == 2);
	static assert(ubAB.cc.value == 4);
	static assert(cast(ubyte) (ubAB.a | ubAB.b) == (1 | 2));
	static assert((ubAB.a | ubAB.b & ubAB.cc) == ubAB.a);
	static assert(cast(ubAB) (1 | 2) == (ubAB.a | ubAB.b));
}

unittest
{
	// Explicit values
	mixin flagEnum!("AB", "a", "b = 4", "c", "d", "e = 63 + 1", "f = 0b10", "g = 0x8 << 4", "h");

	static assert(AB.a.value == 1);
	static assert(AB.b.value == 4);
	static assert(AB.c.value == 8);
	static assert(AB.d.value == 16);
	static assert(AB.e.value == 64);
	static assert(AB.f.value == 2);
	static assert(AB.g.value == 0x80);

	// Invalid explicit/implicit values
	static assert(!__traits(compiles, FlagEnumImpl!("A", "a = 0"))); // zero
	static assert(!__traits(compiles, FlagEnumImpl!("A", "a", "b = 1"))); // explicit value used
	static assert(!__traits(compiles, FlagEnumImpl!("A", "a", "b = 4", "c", "d = 8"))); // ditto
	static assert(!__traits(compiles, FlagEnumImpl!("A", "a", "b = 4", "c", "d = 2", "e"))); // implicit value used
}

unittest
{
	// Almost overflow
	mixin flagEnum!("ubAB", ubyte, "a = 0x40", "b");
	static assert(ubAB.a.value == 0x40);
	static assert(ubAB.b.value == 0x80);

	// Overflow
	static assert(!__traits(compiles, FlagEnumImpl!("ubAB2", ubyte, "a = 0x40", "b", "c")));
}

unittest
{
	// Conversion to string
	mixin flagEnum!("AB", "a", "b ", "\n \rcc \v");
	static assert(AB.init.toString() == "AB.{}");
	static assert(AB.a.toString() == "AB.a");
	static assert(AB.cc.toString() == "AB.cc");
	static assert((AB.a | AB.b).toString() == "AB.{a|b}");
	static assert((AB.a & AB.b).toString() == "AB.{}");
}
