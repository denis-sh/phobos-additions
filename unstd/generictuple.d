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
	TemplateMap = staticMap,
	allSatisfy, anySatisfy;

import std.traits;
import std.ascii: isDigit;


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
Instantiate a template $(D Template) using arguments $(D A).

Example:
----
import std.traits;

static assert(is(Inst!(PointerTarget, int*) == int));
----
*/
template Inst(alias Template, A...)
{
	alias Template!A Inst;
}

unittest
{
	import std.traits;
	static assert( Inst!(isPointer, int*));
	static assert(!Inst!(isPointer, int ));
	static assert(is(Inst!(PointerTarget, int*) == int));
	static assert(Inst!(Alias, 5)[0] == 5);
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
template UnaryPred(alias Pred)
{
	static if(isSomeString!(typeof(Pred)))
	{
		template UnaryPred(__A...) if(__A.length == 1)
		{
			static if(__traits(compiles, { enum e = __A[0]; }))
				enum a = __A[0];
			else
				alias __A[0] T;

			static if(__traits(compiles, { enum e = mixin(Pred); }))
				enum bool UnaryPred = mixin(Pred);
			else
				mixin(`alias `~Pred~` UnaryPred;`);
		}
	} else
		alias Pred UnaryPred;
}

unittest
{
	import std.traits;

	static assert(is(FilterTuple!(isNumeric, int, size_t, void, immutable short, char) ==
					 TypeTuple!(int, size_t, immutable short)));

	static assert(Inst!(UnaryPred!` __traits(isUnsigned, T)`, uint));
	static assert(Inst!(UnaryPred!`!__traits(isUnsigned, T)`,  int));
	static assert(Inst!(Inst!(UnaryPred!TemplateNot, isPointer), int));
	static assert(Inst!(Inst!(UnaryPred!`TemplateNot!T`, isPointer), int));
	static assert(Inst!(Inst!(UnaryPred!(TemplateNot!TemplateNot), isPointer), int*));
	static assert(Inst!(Inst!(UnaryPred!`Inst!(TemplateNot!TemplateNot, T)`, isPointer), int*));

	static assert(is(Inst!(UnaryPred!`T[]`, int) == int[]));
	static assert(is(TemplateMap!(UnaryPred!`T[]`, int, long) == TypeTuple!(int[], long[])));

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


private struct _Arg { size_t n; }
private struct _ArgsRange { size_t from, to; }
private struct _ArgsToEnd { size_t from; }

/**
Binds template arguments.

Example:
----
import unstd.traits;

static assert(is(TemplateBind!(CommonType, long, allArgs).Res!int == long));
static assert(!TemplateBind!(isImplicitlyConvertible, arg!0,   int).Res!long);
static assert( TemplateBind!(isImplicitlyConvertible, int  , arg!0).Res!long);

alias TemplateBind!(TemplateMap, Unqual, allArgs).Res UnqualAll;
static assert(is(UnqualAll!(const(int), immutable(bool[])) T) &&
              T.length == 2 && is(T[0] == int) && is(T[1] == immutable(bool)[]));
----
*/
struct Args
{
	//struct D;
	//template opDollar(size_t n:1) { enum opDollar = D(); }
	auto opIndex(size_t n)               const { return _Arg(n); }
	auto opSlice(size_t from, size_t to) const { return _ArgsRange(from, to); }
	auto opSlice()                       const { return _ArgsToEnd(0); }
}

enum args = Args(); /// ditto
template arg(size_t n) { enum arg = _Arg(n); } /// ditto
template argsRange(size_t from, size_t to) { enum argsRange = _ArgsRange(from, to); } /// ditto
template argsToEnd(size_t from) { enum argsToEnd = _ArgsToEnd(from); } /// ditto
enum allArgs = argsToEnd!0; /// ditto

/// ditto
template TemplateBind(alias Template, BindArgs...)
{
	template Res(Args...)
	{
		alias Template!(TemplateBindArgs!(BindArgs.length, BindArgs, Args)) Res;
	}
}

private template TemplateBindArgs(size_t bindedCount, T...)
{
	static if(!bindedCount)
	{
		alias GenericTuple!() TemplateBindArgs;
	}
	else
	{
		alias T[bindedCount .. $] Args;
		alias TemplateBindArgs!(bindedCount-1, T[1..$]) Rest;

		static if(is(typeof(T[0]) == _Arg))
		{
			alias GenericTuple!(Args[T[0].n], Rest) TemplateBindArgs;
		}
		else static if(is(typeof(T[0]) == _ArgsRange))
		{
			alias GenericTuple!(Args[T[0].from .. T[0].to], Rest) TemplateBindArgs;
		}
		else static if(is(typeof(T[0]) == _ArgsToEnd))
		{
			alias GenericTuple!(Args[T[0].from .. $], Rest) TemplateBindArgs;
		}
		else
		{
			alias GenericTuple!(T[0], Rest) TemplateBindArgs;
		}
	}
}

version(unittest)
{
	template Alias(Args...)
	{
		alias Args Alias;
	}
}

unittest
{
	static assert(Pack!(Alias!(1, 2, int)).equals!(1, 2, int));
	static assert(Pack!(TemplateBind!(Alias, 1, 2, int).Res!3).equals!(1, 2, int));
	static assert(Pack!(TemplateBind!(Alias, arg!0).Res!3).equals!(3));
	static assert(Pack!(TemplateBind!(Alias, 1, 2, int, arg!0).Res!3).equals!(1, 2, int, 3));
	static assert(Pack!(TemplateBind!(Alias, 1, 2, int, allArgs).Res!3).equals!(1, 2, int, 3));
	static assert(Pack!(TemplateBind!(Alias,
			1, arg!0, 2, int, arg!0
		).Res!
			3
		).equals!(
			1, 3, 2, int, 3));
	static assert(Pack!(TemplateBind!(Alias,
			1, arg!1, 2, arg!0, int, arg!0, allArgs,
		).Res!(
			3, char, 5
		)).equals!(
			1, char, 2, 3, int, 3, 3, char, 5));

	import unstd.traits;

	static assert(is(TemplateBind!(CommonType, long, allArgs).Res!int == long));
	static assert(!TemplateBind!(isImplicitlyConvertible, arg!0,   int).Res!long);
	static assert( TemplateBind!(isImplicitlyConvertible, int  , arg!0).Res!long);

	alias TemplateBind!(TemplateMap, Unqual, allArgs).Res UnqualAll;
	static assert(is(UnqualAll!(const(int), immutable(bool[])) T) &&
                  T.length == 2 && is(T[0] == int) && is(T[1] == immutable(bool)[]));
}

// allArgs -> %*, arg! -> %
private string formatBind(string fmt)
{
	string res, id;

	int state = 0;
	foreach(i, char c; fmt)
	{
		if(state == 0 && c == '!')
		{
			res = fmt[0 .. i];
			res ~= ',';
			state = 1;
		}
		else if(state == 1 && c == '(')
		{
			fmt = fmt[i + 1 .. $];
			state = 2;
			break;
		}
	}
	assert(state == 2, "invalid format string, can't find '!(': '" ~ fmt ~ "'");


	foreach_reverse(i, char c; fmt)
		if(c == ')')
		{
			id = fmt[i + 1 .. $];
			fmt = fmt[0 .. i];
			state = 3;
			break;
		}
	assert(state == 3, "invalid format string, can't find ')id': " ~ fmt ~ "'");


	bool ctrl = false;
	size_t start = 0;
	foreach(i, char c; fmt)
	{
		if(ctrl)
		{
			ctrl = false;
			if(c == '%') // %% -> %
			{ }
			else if(c == '*') // %* -> allArgs
			{
				res ~= "allArgs";
				++start;
			}
			else if(c.isDigit()) // %# -> arg!#
				res ~= "arg!";
		}
		else if(c == '%')
		{
			res ~= fmt[start .. i];
			start = i + 1;
			ctrl = true;
		}
	}
	assert(!ctrl, "'%' at end of format string: '" ~ fmt ~ "'");


	res ~= fmt[start .. $];
	res ~= ").Res ";
	res ~= id;
	return res;
}

unittest
{
	enum end = ").Res x";
	static assert(formatBind("ab!()x") == "ab," ~ end);
	static assert(formatBind("ab !() x") == "ab ,).Res  x");
	static assert(formatBind("ab ! ()x") == "ab ," ~ end);
	static assert(formatBind("t!(ab%%c)x") == "t,ab%c" ~ end);
	static assert(formatBind("t!(ab%%)x") == "t,ab%" ~ end);
	static assert(formatBind("t!(ab%0c)x") == "t,abarg!0c" ~ end);
	static assert(formatBind("t!(ab%10)x") == "t,abarg!10" ~ end);
	static assert(formatBind("t!(ab%0)x") == "t,abarg!0" ~ end);
	static assert(formatBind("t!(ab%0c%1d)x") == "t,abarg!0carg!1d" ~ end);
}

/**
Binds template arguments using format string.

Example:
----
import unstd.traits;

mixin Bind!q{ CommonType!(long, %*) CommonTypeToLong };
static assert(is(CommonTypeToLong!int == long));

mixin Bind!q{ isImplicitlyConvertible!(%0, int) isImplicitlyConvertibleToInt };
static assert(!isImplicitlyConvertibleToInt!long);

mixin Bind!q{ isImplicitlyConvertible!(int, %0) isImplicitlyConvertibleFromInt };
static assert( isImplicitlyConvertibleFromInt!long);

mixin Bind!q{ TemplateMap!(Unqual, %*) UnqualAll };
static assert(is(UnqualAll!(const(int), immutable(bool[])) T) &&
              T.length == 2 && is(T[0] == int) && is(T[1] == immutable(bool)[]));
----
*/
mixin template Bind(string fmt)
{
	mixin("alias TemplateBind!(" ~ fmt.formatBind() ~ ";");
}

unittest
{
	void test(string fmt, size_t n, Args...)()
	{

		mixin Bind!(fmt ~ " Res");
		static assert(Pack!(Res!(Args[0 .. n])).equals!(Args[n .. $]));
	}

	static assert(Pack!(Alias!(1, 2, int)).equals!(1, 2, int));
	test!(
		q{ Alias!(1, 2, int) },
		1, 3,
		1, 2, int
	)();
	test!(
		q{ Alias!(%0) },
		1, 3,
		3
	)();
	test!(
		q{ Alias!(1, 2, int, %0) },
		1, 3,
		1, 2, int, 3
	)();
	test!(
		q{ Alias!(1, 2, int, %*) },
		1, 3,
		1, 2, int, 3
	)();
	test!(
		q{ Alias!(1, %0, 2, int, %0) },
		1, 3,
		1, 3, 2, int, 3
	)();
	test!(
		q{ Alias!(1, %1, 2, %0, int, %0, %*,) },
		3, 3, char, 5,
		1, char, 2, 3, int, 3, 3, char, 5
	)();

	import unstd.traits;

	mixin Bind!q{ CommonType!(long, %*) CommonTypeToLong };
	static assert(is(CommonTypeToLong!int == long));
	mixin Bind!q{ isImplicitlyConvertible!(%0, int) isImplicitlyConvertibleToInt };
	static assert(!isImplicitlyConvertibleToInt!long);
	mixin Bind!q{ isImplicitlyConvertible!(int, %0) isImplicitlyConvertibleFromInt };
	static assert( isImplicitlyConvertibleFromInt!long);

	mixin Bind!q{ TemplateMap!(Unqual, %*) UnqualAll };
	static assert(is(UnqualAll!(const(int), immutable(bool[])) T) &&
                  T.length == 2 && is(T[0] == int) && is(T[1] == immutable(bool)[]));
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
