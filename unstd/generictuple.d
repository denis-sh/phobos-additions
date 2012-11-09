/** Additions to std.typetuple

Copyright: Denis Shelomovskij 2011-2012

License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).

Authors: Denis Shelomovskij
*/
module unstd.generictuple;


public import std.typetuple:
	staticIndexOf,
	Erase, EraseAll, NoDuplicates, Replace, ReplaceAll, Reverse,
	MostDerived, DerivedToFront,
	MapTuple = staticMap,
	allSatisfy, anySatisfy;

import std.ascii: isDigit;
import std.algorithm: min, max, StoppingPolicy;
import unstd.traits;
import unstd.templates;


/**
Creates a generic tuple out of a sequence of zero or more types, expressions, or aliases.

Example:
---
template MyTemplate(T) { alias T[] MyTemplate; }

alias GenericTuple!(int, 5, "a string", MyTemplate) MyTuple;

MyTuple[0] myVar = MyTuple[1]; // same as `int myVar = 5;`
auto str = MyTuple[2]; // same as `auto str = "a string";`

alias MyTuple[3] Template;
static assert(is(Template!int == int[]));
---
*/
template GenericTuple(Args...)
{
	alias Args GenericTuple;
}

/**
Creates a packed generic tuple out of a sequence of zero or more types, expressions, or aliases.

Packed version doesn't alias itself to its content, i.e. it doesn't auto-unpack.

Example:
---
alias PackedGenericTuple!(long, 3) MyPackedTuple;

MyPackedTuple.Tuple[0] myVar = MyPackedTuple.Tuple[1]; // same as `long myVar = 3;`

template MyTemplate(alias packed)
{ alias packed.Tuple[0][] MyTemplate; }

// It is passed as a single template alias parameter:
static assert(is(MyTemplate!MyPackedTuple == long[]));
---
*/
template PackedGenericTuple(Args...)
{
	/// Use this member of to access its content as a generic tuple.
	alias Args Tuple;
}


/**
Creates a typetuple out of a sequence of zero or more types.
Same as $(D GenericTuple), except it contains only types.

Example:
---
alias TypeTuple!(int, double) IntDouble;

int foo(IntDouble args)  // same as `int foo(int, double)`
{
   return args[0] + cast(int) args[1];
}

alias TypeTuple!(int, double, char) IntDoubleChar;
static assert(is(TypeTuple!(IntDouble, char) == IntDoubleChar));
static assert(is(IntDoubleChar[0 .. 2] == IntDouble));


alias TypeTuple!(int, 5) BadTypeTuple; // error: not a type tuple
---
*/
template TypeTuple(Types...) if(isTypeTuple!Types)
{
	alias Types TypeTuple;
}

unittest
{
	static assert(TypeTuple!().length == 0);
	static assert(!__traits(compiles, TypeTuple!(int, 5)));

	static assert(is(TypeTuple!(int, TypeTuple!()) == TypeTuple!int));
	static assert(is(TypeTuple!(int, TypeTuple!char) == TypeTuple!(int, char)));
	static assert(is(TypeTuple!(int, TypeTuple!(char, bool)) == TypeTuple!(int, char, bool)));
}


/**
Creates a packed typetuple out of a sequence of zero or more types.
Same as $(D PackedGenericTuple), except it contains only types.
*/
template PackedTypeTuple(T...) if(isTypeTuple!T)
{
	/// Use this member of to access its content as a typetuple.
	alias T Types;
}


/**
Creates an expression tuple out of a sequence of zero or more expressions.
Same as $(D GenericTuple), except it contains only expressions.

Example:
---
alias expressionTuple!(5, 'c', "str") expressions;

typeof(expressions[0]) myVar = expressions[1]; // same as `int myVar = 5;`
auto str = expressions[2]; // same as `auto str = "a string";`

void foo(out typeof(expressions[0 .. 2]) args)  // same as `int foo(out int, out char)`
{
	args[0] = expressions[0] * 2; // same as `5 * 2`
	args[1] = expressions[1] + 1; // same as `'c' + 1`
}

void main()
{
	int i;
	char c;
	foo(i, c);
	assert(i == 10 && c == 'd');
}

alias expressionTuple!(int, 5) badExpressionTuple; // error: not an expression tuple
---
*/
template expressionTuple(expressions...) if(isExpressionTuple!expressions)
{
	alias expressions expressionTuple;
}

unittest
{
	static assert(expressionTuple!().length == 0);
	static assert(Pack!(expressionTuple!(5, 'c', "str")).equals!(5, 'c', "str"));
	static assert(!__traits(compiles, expressionTuple!(int, 5)));
	static assert(!__traits(compiles, expressionTuple!void));
}


/**
Creates a packed expression tuple out of a sequence of zero or more expressions.
Same as $(D PackedGenericTuple), except it contains only expressions.
*/
template packedExpressionTuple(expr...) if(isExpressionTuple!expr)
{
	/// Use this member of to access its content as a typetuple.
	alias expr expressions;
}


/**
TODO docs
*/
template TemplateNot(alias Template) {
	template TemplateNot(T...) {
		static if(__traits(compiles, { enum e = Template!T; }))
			enum bool TemplateNot = !Template!T;
		else
			template TemplateNot(U...) {
				enum bool TemplateNot = !Inst!(Template!T, U);
			}
	}
}

unittest {
	import std.traits;
	alias TemplateNot!isPointer notPointer;
	static assert( notPointer! int );
	static assert(!notPointer!(int*));
	static assert( Inst!(TemplateNot!isPointer, int ));
	static assert(!Inst!(TemplateNot!isPointer, int*));

	alias TemplateNot!TemplateNot staticYes;
	alias staticYes!isPointer _isPointer;
	static assert(!_isPointer! int );
	static assert( _isPointer!(int*));
}


/**
TODO docs
*/
template UnaryTemplate(alias Pred, EnumType = void)
{
	static if(isSomeString!(typeof(Pred)))
	{
		template UnaryTemplate(__A...) if(__A.length == 1)
		{
			static if(__traits(compiles, { enum e = __A[0]; }))
				enum a = __A[0];
			else static if(is(__A[0]))
				alias __A[0] T;
			else
				alias __A[0] A;

			static if(__traits(compiles, { enum e = mixin(Pred); }))
			{
				static if(is(EnumType == void))
					enum UnaryTemplate = mixin(Pred);
				else
					enum EnumType UnaryTemplate = mixin(Pred);
			}
			else
			{
				mixin(`alias `~Pred~` UnaryTemplate;`);
			}
		}
	} else
		alias Pred UnaryTemplate;
}


/**
TODO docs
*/
template UnaryPred(alias Pred)
{
	alias UnaryTemplate!(Pred, bool) UnaryPred;
}

unittest
{
	import std.traits;

	static assert(is(FilterTuple!(isNumeric, int, size_t, void, immutable short, char) ==
					 TypeTuple!(int, size_t, immutable short)));

	static assert(Inst!(UnaryPred!` __traits(isUnsigned, T)`, uint));
	static assert(Inst!(UnaryPred!`!__traits(isUnsigned, T)`,  int));
	static assert(Inst!(Inst!(UnaryPred!TemplateNot, isPointer), int));
	static assert(Inst!(Inst!(UnaryPred!`TemplateNot!A`, isPointer), int));
	static assert(Inst!(Inst!(UnaryPred!(TemplateNot!TemplateNot), isPointer), int*));
	static assert(Inst!(Inst!(UnaryPred!`Inst!(TemplateNot!TemplateNot, A)`, isPointer), int*));

	static assert(is(Inst!(UnaryPred!`T[]`, int) == int[]));
	static assert(is(MapTuple!(UnaryPred!`T[]`, int, long) == TypeTuple!(int[], long[])));

	static assert(Inst!(UnaryPred!`a == 5`, 5));
	static assert(Inst!(UnaryPred!`a == 7`w, 7));
}


/**
TODO docs
*/
template TemplateAnd(Templates...)
{
	template TemplateAnd(T...)
	{
		static if(Templates.length == 0)
			enum TemplateAnd = true;
		else static if(Inst!(Templates[0], T))
			enum TemplateAnd = Inst!(.TemplateAnd!(Templates[1 .. $]), T);
		else
			enum TemplateAnd = false;
	}
}

unittest {
	alias TemplateAnd!() _true;
	static assert(_true!() && _true!int && _true!(int, int*));

	import std.traits;

	alias TemplateAnd!isPointer _isPointer;
	static assert(_isPointer!(int*) && !_isPointer!int);

	alias TemplateAnd!(isIntegral, isSigned) isSignedIntegral;
	static assert( allSatisfy!(isSignedIntegral,  int,  short, long));
	static assert(!anySatisfy!(isSignedIntegral, uint, ushort, ulong));

	alias TemplateAnd!(isSignedIntegral, UnaryPred!`is(T == short)`) isShort;
	static assert( isShort!short);
	static assert(!anySatisfy!(isShort, int, long, uint, ushort, ulong));
}


/**
TODO docs
*/
template TemplateOr(Templates...)
{
	template TemplateOr(T...)
	{
		static if(Templates.length == 0)
			enum TemplateOr = false;
		else static if(!Inst!(Templates[0], T))
			enum TemplateOr = Inst!(.TemplateOr!(Templates[1 .. $]), T);
		else
			enum TemplateOr = true;
	}
}

unittest {
	alias TemplateOr!() _false;
	static assert(!_false!() && !_false!int && !_false!(int, int*));

	import std.traits;

	alias TemplateOr!isPointer _isPointer;
	static assert(_isPointer!(int*) && !_isPointer!int);

	alias TemplateOr!(isIntegral, isFloatingPoint) isIntegralOrFloating;
	static assert( allSatisfy!(isIntegralOrFloating, int,  short, long, float, double));
	static assert(!anySatisfy!(isIntegralOrFloating, bool, char));

	alias TemplateOr!(isIntegralOrFloating, UnaryPred!`is(T == char)`) isIntegralOrFloatingOrChar;
	static assert( allSatisfy!(isIntegralOrFloatingOrChar, int,  short, long, float, double, char));
	static assert(!isIntegralOrFloatingOrChar!bool);
}


/**
Filters a generic tuple $(D A) using a predicate $(D Pred).

Example:
----
import std.traits;

static assert(is(FilterTuple!(isNumeric, int, void, immutable short, char) ==
              TypeTuple!(int, immutable short)));
----
*/
template FilterTuple(alias Pred, A...)
{
	static if (A.length == 0)
		alias GenericTuple!() FilterTuple;
	else
	{
		alias FilterTuple!(Pred, A[1 .. $]) Tail;

		static if(Pred!(A[0]))
			alias GenericTuple!(A[0], Tail) FilterTuple;
		else
			alias Tail FilterTuple;
	}
}

unittest
{
	import std.traits;

	static assert(is(FilterTuple!(isNumeric, int, size_t, void, immutable short, char) ==
		TypeTuple!(int, size_t, immutable short)));

	static assert(is(FilterTuple!(UnaryPred!`__traits(isUnsigned, T)`, int, size_t, void, immutable ushort, char) ==
		TypeTuple!(size_t, immutable ushort, char)));
}


/**
TODO docs
*/
template ZipTuple(StoppingPolicy stoppingPolicy : StoppingPolicy.longest, alias empty, packedTuples...)
{
	alias ZipTupleImpl!(stoppingPolicy, empty, packedTuples) ZipTuple;
}

/// ditto
template ZipTuple(StoppingPolicy stoppingPolicy, packedTuples...)
{
	alias ZipTupleImpl!(stoppingPolicy, PackedGenericTuple!void, packedTuples) ZipTuple;
}

/// ditto
template ZipTuple(packedTuples...)
{
	alias ZipTuple!(StoppingPolicy.shortest, packedTuples) ZipTuple;
}

private template ZipTupleImpl(StoppingPolicy stoppingPolicy, alias default_, packedTuples...)
	if(packedTuples.length && allSatisfy!(isPackedTuple, default_, packedTuples) && default_.Tuple.length == 1)
{
	alias MapTuple!(UnaryTemplate!`A.Tuple.length`, packedTuples) lengths;

	static if(stoppingPolicy == StoppingPolicy.requireSameLength)
		static assert(FilterTuple!(TemplateBind!(isSame, lengths[0], arg!0).Res, lengths).length == packedTuples.length,
			"Inequal-length packed tuples passed to ZipTuple(StoppingPolicy.requireSameLength, ...)");

	template Impl(size_t n, packedTuples...)
	{
		static if(n)
		{
			template tupleFrontOrDefault(alias packedTuple)
			{
				static if(packedTuple.Tuple.length)
					alias packedTuple.Tuple[0 .. 1] tupleFrontOrDefault;
				else
					alias default_.Tuple tupleFrontOrDefault;
			}
			alias GenericTuple!(PackedGenericTuple!(MapTuple!(tupleFrontOrDefault, packedTuples)),
				Impl!(n - 1, MapTuple!(UnaryTemplate!`PackedGenericTuple!(A.Tuple[!!A.Tuple.length .. $])`, packedTuples))) Impl;
		}
		else
			alias GenericTuple!() Impl;
	}
	static if(packedTuples.length == 1 || stoppingPolicy == StoppingPolicy.requireSameLength)
		enum length = lengths[0];
	else static if(stoppingPolicy == StoppingPolicy.longest)
		enum length = max(lengths);
	else
		enum length = min(lengths);

	alias Impl!(length, packedTuples) ZipTupleImpl;
}

unittest
{
	alias PackedGenericTuple!(iotaTuple!5) packedIota5;
	alias PackedGenericTuple!(iotaTuple!(1, 6)) packedIota16;
	alias PackedGenericTuple!(iotaTuple!(1, 4)) packedIota14;
	alias PackedGenericTuple!(iotaTuple!(1, 8)) packedIota18;

	void test(size_t length, size_t filledLength, size_t longerIdx, zip...)()
	{
		static assert(zip.length == length);
		foreach (i, e; zip)
			static assert(e.Tuple[0] == (i < filledLength || longerIdx == 0 ? i : -2) &&
				e.Tuple[1] == (i < filledLength || longerIdx == 1 ? i + 1 : -3));
	}

	with(StoppingPolicy) foreach(stoppingPolicy; expressionTuple!(shortest, longest, requireSameLength))
	{
		static if(stoppingPolicy == longest)
			alias PackedGenericTuple!void def;
		else
			alias expressionTuple!() def;

		alias ZipTuple!(stoppingPolicy, def, packedIota5, packedIota16) zip;
		test!(5, 5, -1, zip)();
	}

	static assert(!__traits(compiles, ZipTuple!(StoppingPolicy.requireSameLength, packedIota5, packedIota14)));
	static assert(!__traits(compiles, ZipTuple!(StoppingPolicy.requireSameLength, packedIota5, packedIota18)));

	test!(3, 3, -1, ZipTuple!(packedIota5, packedIota14))();
	test!(5, 5, -1, ZipTuple!(packedIota5, packedIota18))();

	test!(5, 3, 0, ZipTuple!(StoppingPolicy.longest, PackedGenericTuple!(-3), packedIota5, packedIota14))();
	test!(7, 5, 1, ZipTuple!(StoppingPolicy.longest, PackedGenericTuple!(-2), packedIota5, packedIota18))();
}


/**
Expression tuple usable for CT $(D foreach) iteration 0 .. $(D n) or $(D m) .. $(D n).
If $(D m) >= $(D n) the range is empty.

Example:
---
int res;
foreach(i; iotaTuple!5) // same as res += foo!1(); res += foo!3();
	static if(i & 1)
		res += foo!i();
---
*/
template iotaTuple(size_t n)
{
	static if(n)
		alias expressionTuple!(iotaTuple!(n-1), n-1) iotaTuple;
	else
		alias expressionTuple!() iotaTuple;
}

unittest
{
	static assert(iotaTuple!0 .length == 0);

	foreach(i, j; iotaTuple!5)
		static assert(i == j);

	foreach_reverse(i, j; iotaTuple!5)
		static assert(i == j);

	int foo(int i)() if(i == 1 || i == 3) { return i * i; }
	int res;
	foreach(i; iotaTuple!5)
		static if(i & 1)
			res += foo!i();
	assert(res == 1 + 3^^2);
}

/// ditto
template iotaTuple(int m, int n)
{
	static if(n > m)
		alias expressionTuple!(iotaTuple!(m, n-1), n-1) iotaTuple;
	else
		alias expressionTuple!() iotaTuple;
}

unittest
{
	static assert(iotaTuple!(5, 3) .length == 0);
	static assert(iotaTuple!(3, 3) .length == 0);

	foreach(i, j; iotaTuple!(1, 5))
		static assert(i + 1 == j);

	foreach_reverse(i, j; iotaTuple!(1, 5))
		static assert(i + 1 == j);

	int foo(int i)() if(i == 1 || i == 3) { return i * i; }
	int res;
	foreach(i; iotaTuple!(1, 5))
		static if(i & 1)
			res += foo!i();
	assert(res == 1 + 3^^2);
}

//  internal templates from std.typetuple:

private template isSame(ab...)
    if (ab.length == 2)
{
    static if (__traits(compiles, expectType!(ab[0]),
                                  expectType!(ab[1])))
    {
        enum isSame = is(ab[0] == ab[1]);
    }
    else static if (!__traits(compiles, expectType!(ab[0])) &&
                    !__traits(compiles, expectType!(ab[1])) &&
                     __traits(compiles, expectBool!(ab[0] == ab[1])))
    {
        static if (!__traits(compiles, &ab[0]) ||
                   !__traits(compiles, &ab[1]))
            enum isSame = (ab[0] == ab[1]);
        else
            enum isSame = __traits(isSame, ab[0], ab[1]);
    }
    else
    {
        enum isSame = __traits(isSame, ab[0], ab[1]);
    }
}
private template expectType(T) {}
private template expectBool(bool b) {}

package template Pack(T...)
{
    alias T tuple;

    // For convenience
    template equals(U...)
    {
        static if (T.length == U.length)
        {
            static if (T.length == 0)
                enum equals = true;
            else
                enum equals = isSame!(T[0], U[0]) &&
                    Pack!(T[1 .. $]).equals!(U[1 .. $]);
        }
        else
        {
            enum equals = false;
        }
    }
}
