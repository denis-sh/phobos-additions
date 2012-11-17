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
Create template from a string $(D Pred).
If $(D Pred) isn't a string, alises itself to $(D Pred).

If $(D argumentsCount) is $(D -1) created template will accept any number
of arguments, otherwise it will expect $(D argumentsCount) arguments.

If $(D EnumType) is $(D void) created template may be an $(D alias) or
an $(D enum), otherwise it will be an $(D enum) of type $(D EnumType).

Created template can access its aruments as a generic tuple with $(D Args).

If $(D argumentsCount) is $(D 1) or $(D 2) created template can access
its first argument with $(D a) if it is an value, with $(D T) if it is a type
and with $(D A) otherwise.

If $(D argumentsCount) is $(D 2) created template can access
its second argument with $(D b) if it is an value, with $(D U) if it is a type
and with $(D B) otherwise.

$(D UnaryTemplate) is a convinient way to create a template with one argument ($(D argumentsCount) is $(D 1)).

$(D BinaryTemplate) is a convinient way to create a template with two arguments ($(D argumentsCount) is $(D 2)).

Example:
----
static assert(Inst!(UnaryTemplate!`__traits(isUnsigned, T)`, uint));
static assert(is(Inst!(UnaryTemplate!`T[]`, int) == int[]));
static assert(Inst!(UnaryTemplate!`a == 5`, 5));
static assert(Inst!(BinaryTemplate!`a == 1 && b == 2`, 1, 2));
static assert(Inst!(BinaryTemplate!`a + U.sizeof`, 1, int) == 5);
static assert(PackedGenericTuple!(Inst!(Template!(`Args`, -1), "x", int)).equals!("x", int));
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

	static assert(Inst!(BinaryTemplate!`a + U.sizeof`, 1, int) == 5);
	static assert(PackedGenericTuple!(Inst!(Template!(`Args`, -1), 1, int, "x")).equals!(1, int, "x"));
}


/**
Using $(D unaryPred) or $(D binaryPred) is a convinient way to create a template
with one or two arguments respectively which is an $(D enum) of type $(D bool).

It is equal to instantiating $(MREF Template) with corresponding
$(D argumentsCount) and $(D bool) as $(D EnumType).

Example:
----
static assert(Inst!(unaryPred!`__traits(isUnsigned, T)`, uint));
static assert(Inst!(binaryPred!`a == U.sizeof`, 4, int));
----
*/
template unaryPred(alias pred)
{
	alias UnaryTemplate!(pred, bool) unaryPred;
}

/// ditto
template binaryPred(alias pred)
{
	alias BinaryTemplate!(pred, bool) binaryPred;
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


/**
Binds template arguments.

$(UL
	$(LI use $(D args[i]) or $(D arg!i) to refer $(D i)-th argument;)
	$(LI use $(D args[$ - i]) to refer arguments from the end
		(also $(D args[$ + i]) can be used for negative $(D i));)
	$(LI use $(D args[a .. b]) or $(D argsRange!(a, b)) to refer arguments from
		$(D a)-th up to and excluding $(D b)-th;)
	$(LI use $(D argsToEnd!n) to refer arguments from $(D n)-th argument up to
		the end;)
	$(LI use $(D allArgs) to refer all arguments.)
)

Example:
----
import unstd.traits;

static assert(is(Inst!(BindTemplate!(CommonType, long, allArgs), int) == long));
static assert(!Inst!(BindTemplate!(isImplicitlyConvertible, args[0], int), long));
static assert( Inst!(BindTemplate!(isImplicitlyConvertible, int  , arg!0), long));

alias BindTemplate!(MapTuple, Unqual, allArgs) UnqualAll;
static assert(is(UnqualAll!(const(int), immutable(bool[])) == TypeTuple!(int, immutable(bool)[])));
----

Bugs:
Currently there is no support for $(D args[a .. $]) because of compiler limitations.
*/
template BindTemplate(alias Template, BindArgs...)
{
	template BindTemplate(Args...)
	{
		alias Template!(TemplateBindArgs!(BindArgs.length, BindArgs, Args)) BindTemplate;
	}
}

private struct __BindArgs
{
	struct Arg { size_t n; }
	struct ArgsRange { size_t from, to; }
	struct ArgsToEnd { size_t from; }
	struct ArgDollar
	{
		int sub = 0;
		auto opBinary(string op)(int n) const
			if(op == "+" || op == "-")
		{ return ArgDollar(op == "+" ? -n : n); }
	}

	auto opDollar() const { return ArgDollar(); }
	auto opIndex(size_t n)               const { return Arg(n); }
	auto opIndex(ArgDollar d)            const { return d; }
	auto opSlice(size_t from, size_t to) const { return ArgsRange(from, to); }
	auto opSlice()                       const { return ArgsToEnd(0); }
}

enum args = __BindArgs();
template arg(size_t n) { enum arg = __BindArgs.Arg(n); }
template argsRange(size_t from, size_t to) { enum argsRange = __BindArgs.ArgsRange(from, to); }
template argsToEnd(size_t from) { enum argsToEnd = __BindArgs.ArgsToEnd(from); }
enum allArgs = argsToEnd!0;

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

		static if(is(typeof(T[0]) == __BindArgs.Arg))
		{
			alias GenericTuple!(Args[T[0].n], Rest) TemplateBindArgs;
		}
		else static if(is(typeof(T[0]) == __BindArgs.ArgDollar))
		{
			alias GenericTuple!(Args[Args.length - T[0].sub], Rest) TemplateBindArgs;
		}
		else static if(is(typeof(T[0]) == __BindArgs.ArgsRange))
		{
			alias GenericTuple!(Args[T[0].from .. T[0].to], Rest) TemplateBindArgs;
		}
		else static if(is(typeof(T[0]) == __BindArgs.ArgsToEnd))
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
	static assert(Pack!(Inst!(BindTemplate!(Alias, 1, 2, int), 3)).equals!(1, 2, int));
	static assert(Pack!(Inst!(BindTemplate!(Alias, arg!0), 3)).equals!(3));
	static assert(Pack!(Inst!(BindTemplate!(Alias, 1, 2, int, args[0]), 3)).equals!(1, 2, int, 3));
	static assert(Pack!(Inst!(BindTemplate!(Alias, 1, 2, int, allArgs), 3)).equals!(1, 2, int, 3));
	static assert(Pack!(Inst!(BindTemplate!(Alias,
			1, args[0 .. 1], 2, int, args[$ - 1]
		),
			3
		)).equals!(
			1, 3, 2, int, 3));
	static assert(Pack!(Inst!(BindTemplate!(Alias,
			1, arg!1, 2, arg!0, int, args[$ + -3], allArgs,
		),
			3, char, 5
		)).equals!(
			1, char, 2, 3, int, 3, 3, char, 5));

	import unstd.traits;

	static assert(is(Inst!(BindTemplate!(CommonType, long, allArgs), int) == long));
	static assert(!Inst!(BindTemplate!(isImplicitlyConvertible, args[0], int), long));
	static assert( Inst!(BindTemplate!(isImplicitlyConvertible, int  , arg!0), long));

	alias BindTemplate!(MapTuple, Unqual, allArgs) UnqualAll;
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

$(UL
	$(LI use $(D %i) to refer $(D i)-th argument;)
	$(LI use $(D %*) to refer all arguments;)
	$(LI use $(D %%) for a $(D %) symbol.)
)

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
	mixin("alias BindTemplate!(" ~ fmt.formatBind() ~ ";");
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
