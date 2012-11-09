/** Vriouse stuff for working with _templates.

Copyright: Denis Shelomovskij 2011-2012

License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).

Authors: Denis Shelomovskij
*/
module unstd.templates;


import unstd.generictuple;


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
