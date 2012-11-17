/** Vriouse stuff for working with _templates.

Copyright: Denis Shelomovskij 2011-2012

License: $(HTTP boost.org/LICENSE_1_0.txt, Boost License 1.0).

Authors: Denis Shelomovskij
*/
module unstd.templates;


import unstd.generictuple;
import unstd.traits;


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

Example:
----
static assert(Inst!(UnaryTemplate!`__traits(isUnsigned, T)`, uint));
static assert(is(Inst!(UnaryTemplate!`T[]`, int) == int[]));
static assert(Inst!(UnaryTemplate!`a == 5`, 5));
static assert(Inst!(BinaryTemplate!`a == 1 && b == 2`, 1, 2));
----
*/
template Template(alias Pred, int argumentsCount, EnumType = void)
	if(argumentsCount >= -1)
{
	static if(isSomeString!(typeof(Pred)))
	{
		template Template(Args...) if(argumentsCount == -1 || Args.length == argumentsCount)
		{
			static if(argumentsCount >= 1 && argumentsCount <= 2)
			{
				static if(__traits(compiles, { enum e = Args[0]; }))
					enum a = Args[0];
				else static if(is(Args[0]))
					alias Args[0] T;
				else
					alias Args[0] A;

				static if(argumentsCount == 2)
				{
					static if(__traits(compiles, { enum e = Args[1]; }))
						enum b = Args[1];
					else static if(is(Args[1]))
						alias Args[1] U;
					else
						alias Args[1] B;
				}
			}

			static if(is(EnumType == void))
			{
				static if(__traits(compiles, { enum e = mixin(Pred); }))
					enum Template = mixin(Pred);
				else
					mixin(`alias `~Pred~` Template;`);
			}
			else
			{
				enum EnumType Template = mixin(Pred);
			}
		}
	} else
		alias Pred Template;
}

/// ditto
template UnaryTemplate(alias Pred, EnumType = void)
{
	alias Template!(Pred, 1, EnumType) UnaryTemplate;
}

/// ditto
template BinaryTemplate(alias Pred, EnumType = void)
{
	alias Template!(Pred, 2, EnumType) BinaryTemplate;
}

unittest
{
	static assert(Inst!(UnaryTemplate!` __traits(isUnsigned, T)`, uint));
	static assert(Inst!(UnaryTemplate!`!__traits(isUnsigned, T)`,  int));
	static assert(Inst!(Inst!(UnaryTemplate!TemplateNot, isPointer), int));
	static assert(Inst!(Inst!(UnaryTemplate!`TemplateNot!A`, isPointer), int));
	static assert(Inst!(Inst!(UnaryTemplate!(TemplateNot!TemplateNot), isPointer), int*));
	static assert(Inst!(Inst!(UnaryTemplate!`Inst!(TemplateNot!TemplateNot, A)`, isPointer), int*));

	static assert(is(Inst!(UnaryTemplate!`T[]`, int) == int[]));

	static assert(Inst!(UnaryTemplate!`a == 5`, 5));
	static assert(Inst!(UnaryTemplate!`a == 7`w, 7));

	static assert(Inst!(BinaryTemplate!`a == 1 && b == 2`, 1, 2));

	static assert(!__traits(compiles, Inst!(Template!(`T`, bool), int)));

	static assert(PackedGenericTuple!(Inst!(Template!(`Args`, -1), 1, int, "x")).equals!(1, int, "x"));
}


/**
TODO docs

Example:
----
static assert(Inst!(unaryPred!`__traits(isUnsigned, T)`, uint));
static assert(Inst!(binaryPred!`a == U.sizeof`, 4, int));
----
*/
template unaryPred(alias Pred)
{
	alias UnaryTemplate!(Pred, bool) unaryPred;
}

/// ditto
template binaryPred(alias Pred)
{
	alias BinaryTemplate!(Pred, bool) binaryPred;
}

unittest
{
	static assert(Inst!(unaryPred!` __traits(isUnsigned, T)`, uint));
	static assert(Inst!(unaryPred!`!__traits(isUnsigned, T)`,  int));
	static assert(Inst!(unaryPred!`a == 5`, 5));
	static assert(Inst!(binaryPred!`a == U.sizeof`, 4, int));
	static assert(!__traits(compiles, Inst!(unaryPred!`T`, int)));
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

	alias TemplateAnd!(isSignedIntegral, unaryPred!`is(T == short)`) isShort;
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

	alias TemplateOr!(isIntegralOrFloating, unaryPred!`is(T == char)`) isIntegralOrFloatingOrChar;
	static assert( allSatisfy!(isIntegralOrFloatingOrChar, int,  short, long, float, double, char));
	static assert(!isIntegralOrFloatingOrChar!bool);
}


private struct _Arg { size_t n; }
private struct _ArgsRange { size_t from, to; }
private struct _ArgsToEnd { size_t from; }

/**
Binds template arguments.

Example:
----
import unstd.traits;

static assert(is(Inst!(TemplateBind!(CommonType, long, allArgs), int) == long));
static assert(!Inst!(TemplateBind!(isImplicitlyConvertible, arg!0,   int), long));
static assert( Inst!(TemplateBind!(isImplicitlyConvertible, int  , arg!0), long));

alias TemplateBind!(MapTuple, Unqual, allArgs) UnqualAll;
static assert(is(UnqualAll!(const(int), immutable(bool[])) == TypeTuple!(int, immutable(bool)[])));
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
	template TemplateBind(Args...)
	{
		alias Template!(TemplateBindArgs!(BindArgs.length, BindArgs, Args)) TemplateBind;
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
	alias PackedGenericTuple Pack;
	static assert(Pack!(Alias!(1, 2, int)).equals!(1, 2, int));
	static assert(Pack!(Inst!(TemplateBind!(Alias, 1, 2, int), 3)).equals!(1, 2, int));
	static assert(Pack!(Inst!(TemplateBind!(Alias, arg!0), 3)).equals!(3));
	static assert(Pack!(Inst!(TemplateBind!(Alias, 1, 2, int, arg!0), 3)).equals!(1, 2, int, 3));
	static assert(Pack!(Inst!(TemplateBind!(Alias, 1, 2, int, allArgs), 3)).equals!(1, 2, int, 3));
	static assert(Pack!(Inst!(TemplateBind!(Alias,
			1, arg!0, 2, int, arg!0
		),
			3
		)).equals!(
			1, 3, 2, int, 3));
	static assert(Pack!(Inst!(TemplateBind!(Alias,
			1, arg!1, 2, arg!0, int, arg!0, allArgs,
		),
			3, char, 5
		)).equals!(
			1, char, 2, 3, int, 3, 3, char, 5));

	import unstd.traits;

	static assert(is(Inst!(TemplateBind!(CommonType, long, allArgs), int) == long));
	static assert(!Inst!(TemplateBind!(isImplicitlyConvertible, arg!0,   int), long));
	static assert( Inst!(TemplateBind!(isImplicitlyConvertible, int  , arg!0), long));

	alias TemplateBind!(MapTuple, Unqual, allArgs) UnqualAll;
	static assert(is(UnqualAll!(const(int), immutable(bool[])) == TypeTuple!(int, immutable(bool)[])));
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
	res ~= ") ";
	res ~= id;
	return res;
}

unittest
{
	enum end = ") x";
	static assert(formatBind("ab!()x") == "ab," ~ end);
	static assert(formatBind("ab !() x") == "ab ,)  x");
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

mixin Bind!q{ MapTuple!(Unqual, %*) UnqualAll };
static assert(is(UnqualAll!(const(int), immutable(bool[])) == TypeTuple!(int, immutable(bool)[])));
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

	alias PackedGenericTuple Pack;
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

	mixin Bind!q{ MapTuple!(Unqual, %*) UnqualAll };
	static assert(is(UnqualAll!(const(int), immutable(bool[])) == TypeTuple!(int, immutable(bool)[])));
}
