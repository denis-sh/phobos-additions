/** Additions to std.typetuple

$(BOOKTABLE Generic tuple manipulation functions,
	$(TR $(TH Category) $(TH Functions))
	$(TR $(TD Creation)
		$(TD
			$(BTREF RetroTuple)
			$(BTREF StrideTuple)
			$(BTREF ChainTuple)
			$(BTREF RoundRobinTuple)
			$(BTREF RadialTuple)
			$(BTREF RepeatTuple)
			$(BTREF ZipTuple)
			$(BTREF iotaTuple)
		)
	)
	$(TR $(TD Comparison)
		$(TD
			$(BTREF cmpTuple)
			$(BTREF equalTuple)
		)
	)
	$(TR $(TD Iteration)
		$(TD
			$(BTREF FilterTuple)
			$(BTREF MapTuple)
		)
	)
)

Macros:
BTREF = $(MREF $0)&nbsp;&nbsp;

PHOBOSREF = $(HTTP dlang.org/phobos/std_$1#$2, std.$1.$2)

Copyright: Denis Shelomovskij 2011-2012

License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).

Authors: Denis Shelomovskij
*/
module unstd.generictuple;


public import std.typetuple:
	staticIndexOf,
	Erase, EraseAll, NoDuplicates, Replace, ReplaceAll, Reverse,
	MostDerived, DerivedToFront,
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

	/// Its content length.
	enum length = Tuple.length;

	/// Detect whether it's empty.
	enum empty = !length;
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
template Template(alias Pred, int argumentsCount, EnumType = void)
	if(argumentsCount >= -1)
{
	static if(isSomeString!(typeof(Pred)))
	{
		template Template(__A...) if(argumentsCount == -1 || __A.length == argumentsCount)
		{
			static if(argumentsCount >= 1 && argumentsCount <= 2)
			{
				static if(__traits(compiles, { enum e = __A[0]; }))
					enum a = __A[0];
				else static if(is(__A[0]))
					alias __A[0] T;
				else
					alias __A[0] A;

				static if(argumentsCount == 2)
				{
					static if(__traits(compiles, { enum e = __A[1]; }))
						enum b = __A[1];
					else static if(is(__A[1]))
						alias __A[1] U;
					else
						alias __A[1] B;
				}
			}

			static if(__traits(compiles, { enum e = mixin(Pred); }))
			{
				static if(is(EnumType == void))
					enum Template = mixin(Pred);
				else
					enum EnumType Template = mixin(Pred);
			}
			else
			{
				mixin(`alias `~Pred~` Template;`);
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
}


/**
TODO docs
*/
template UnaryPred(alias Pred)
{
	alias UnaryTemplate!(Pred, bool) UnaryPred;
}

/// ditto
template BinaryPred(alias Pred)
{
	alias BinaryTemplate!(Pred, bool) BinaryPred;
}

unittest
{
	static assert(Inst!(UnaryPred!` __traits(isUnsigned, T)`, uint));
	static assert(Inst!(UnaryPred!`!__traits(isUnsigned, T)`,  int));
	static assert(Inst!(UnaryPred!`a == 5`, 5));
	static assert(Inst!(BinaryPred!`a == U.sizeof`, 4, int));
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
TODO docs

Analog of $(PHOBOSREF range, retro) for generic tuples.
*/
template RetroTuple(A...)
{
	static if (A.length == 0)
		alias GenericTuple!() RetroTuple;
	else
		alias GenericTuple!(.RetroTuple!(A[1 .. $]), A[0]) RetroTuple;
}

unittest
{
	static assert(is(RetroTuple!() == GenericTuple!()));
	static assert(is(RetroTuple!int == TypeTuple!int));
	static assert(is(RetroTuple!(int, bool, long) == TypeTuple!(long, bool, int)));
	static assert(equalTuple!(PackedGenericTuple!(RetroTuple!(1, bool, "x")), PackedGenericTuple!("x", bool, 1)));
}


/**
TODO docs

Analog of $(PHOBOSREF range, stride) for generic tuples
except $(D n) is the first argument.
*/
template StrideTuple(size_t n, A...)
	if(n > 0)
{
	static if(A.length)
		alias GenericTuple!(A[0], StrideTuple!(n, A[min(n, $) .. $])) StrideTuple;
	else
		alias GenericTuple!() StrideTuple;
}

unittest
{
	static assert(is(StrideTuple!1 == GenericTuple!()));
	alias iotaTuple!(1, 11) iota;
	static assert(equalTuple!(PackedGenericTuple!(StrideTuple!(1, iota)), PackedGenericTuple!iota));
	static assert(equalTuple!(PackedGenericTuple!(StrideTuple!(2, iota)), PackedGenericTuple!(1, 3, 5, 7, 9)));
	static assert(equalTuple!(PackedGenericTuple!(StrideTuple!(3, iota)), PackedGenericTuple!(1, 4, 7, 10)));
	static assert(equalTuple!(PackedGenericTuple!(StrideTuple!(4, iota)), PackedGenericTuple!(1, 5, 9)));
}


/**
TODO docs

Analog of $(PHOBOSREF range, chain) for generic tuples.
*/
template ChainTuple(packedTuples...)
	if(packedTuples.length && allSatisfy!(isPackedTuple, packedTuples))
{
	// Can't use UnaryTemplate!`A.Tuple` because of Issue 9017
	template Pred(alias packedTuple) { alias packedTuple.Tuple Pred; }
	alias MapTuple!(Pred, packedTuples) ChainTuple;
}

unittest
{
	alias ChainTuple!(PackedGenericTuple!(1, 2, 3, 4), PackedGenericTuple!(5, 6), PackedGenericTuple!(), PackedGenericTuple!7) chain;
	static assert(equalTuple!(PackedGenericTuple!chain, PackedGenericTuple!(1, 2, 3, 4, 5, 6, 7)));
}


/**
TODO docs

Analog of $(PHOBOSREF range, roundRobin) for generic tuples.
*/
template RoundRobinTuple(packedTuples...)
	if(packedTuples.length && allSatisfy!(isPackedTuple, packedTuples))
{
	struct _Empty;
	template pred(alias A) { enum pred = !is(A == _Empty); }
	alias FilterTuple!(pred, ChainTuple!(ZipTuple!(StoppingPolicy.longest, GenericTuple!_Empty, packedTuples))) RoundRobinTuple;
}

unittest
{
	alias RoundRobinTuple!(PackedGenericTuple!(1, 2, 3), PackedGenericTuple!(10, 20, 30, 40)) roundRobin;
	static assert(equalTuple!(PackedGenericTuple!roundRobin, PackedGenericTuple!(1, 10, 2, 20, 3, 30, 40)));
}


/**
TODO docs

Analog of $(PHOBOSREF range, radial) for generic tuples
except $(D startingIndex) is the first argument and
there is no overload without it.
*/
template RadialTuple(size_t startingIndex, A...)
{
	enum i = (startingIndex == -1 ? (A.length - !!A.length) / 2 : startingIndex) + !!A.length;
	alias RoundRobinTuple!(PackedGenericTuple!(RetroTuple!(A[0 .. i])), PackedGenericTuple!(A[i .. $])) RadialTuple;
}

unittest
{
	static assert(equalTuple!(PackedGenericTuple!(RadialTuple!(-1, 1)), PackedGenericTuple!1));
	static assert(equalTuple!(PackedGenericTuple!(RadialTuple!(-1, 1, 2)), PackedGenericTuple!(1, 2)));
	static assert(equalTuple!(PackedGenericTuple!(RadialTuple!(-1, 1, 2, 3)), PackedGenericTuple!(2, 3, 1)));
	static assert(equalTuple!(PackedGenericTuple!(RadialTuple!(-1, 1, 2, 3, 4)), PackedGenericTuple!(2, 3, 1, 4)));
	static assert(equalTuple!(PackedGenericTuple!(RadialTuple!(-1, 1, 2, 3, 4, 5)), PackedGenericTuple!(3, 4, 2, 5, 1)));
	static assert(equalTuple!(PackedGenericTuple!(RadialTuple!(-1, 1, 2, 3, 4, 5, 6)), PackedGenericTuple!(3, 4, 2, 5, 1, 6)));
	static assert(equalTuple!(PackedGenericTuple!(RadialTuple!(1, 1, 2, 3, 4, 5)), PackedGenericTuple!(2, 3, 1, 4, 5)));
}


/**
TODO docs

Analog of $(PHOBOSREF array, replicate) and $(PHOBOSREF range, repeat) for generic tuples
except $(D n) is the first argument and there is no overload
without it as tuples can't be infinite.
Also it repeats a generic tuple, not only one value.
*/
template RepeatTuple(size_t n, A...)
{
	static if(n)
		alias GenericTuple!(A, RepeatTuple!(n - 1, A)) RepeatTuple;
	else
		alias GenericTuple!() RepeatTuple;
}

unittest
{
	static assert(equalTuple!(PackedGenericTuple!(RepeatTuple!(4, 5)), PackedGenericTuple!(5, 5, 5, 5)));
}


/**
TODO docs

Analog of $(PHOBOSREF range, zip) for generic tuples
except $(D empty) value must be explicitly specified
for $(D StoppingPolicy.longest).
*/
template ZipTuple(StoppingPolicy stoppingPolicy : StoppingPolicy.longest, alias empty, packedTuples...)
{
	alias ZipTupleImpl!(stoppingPolicy, PackedGenericTuple!empty, packedTuples) ZipTuple;
}

/// ditto
template ZipTuple(StoppingPolicy stoppingPolicy : StoppingPolicy.longest, empty, packedTuples...)
{
	alias ZipTupleImpl!(stoppingPolicy, PackedGenericTuple!empty, packedTuples) ZipTuple;
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
	if(packedTuples.length && allSatisfy!(isPackedTuple, default_, packedTuples) && default_.length == 1)
{
	alias MapTuple!(`A.length`, packedTuples) lengths;

	static if(stoppingPolicy == StoppingPolicy.requireSameLength)
		static assert(FilterTuple!(TemplateBind!(isSame, lengths[0], arg!0).Res, lengths).length == packedTuples.length,
			"Inequal-length packed tuples passed to ZipTuple(StoppingPolicy.requireSameLength, ...)");

	template Impl(size_t n, packedTuples...)
	{
		static if(n)
		{
			template tupleFrontOrDefault(alias packedTuple)
			{
				static if(!packedTuple.empty)
					alias packedTuple.Tuple[0 .. 1] tupleFrontOrDefault;
				else
					alias default_.Tuple tupleFrontOrDefault;
			}
			alias GenericTuple!(PackedGenericTuple!(MapTuple!(tupleFrontOrDefault, packedTuples)),
				Impl!(n - 1, MapTuple!(`PackedGenericTuple!(A.Tuple[!A.empty .. $])`, packedTuples))) Impl;
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

	test!(5, 3, 0, ZipTuple!(StoppingPolicy.longest, -3, packedIota5, packedIota14))();
	test!(7, 5, 1, ZipTuple!(StoppingPolicy.longest, -2, packedIota5, packedIota18))();
}


/**
Returns expression tuple with elements going through the numbers $(D begin), $(D begin +
step), $(D begin + 2 * step), $(D ...), up to and excluding $(D end).
The two-arguments version has $(D step = 1).
The one-argument version also has $(D begin = 0).
If $(D begin < end && step < 0) or $(D begin > end && step > 0) or $(D begin == end),
then an empty tuple is returned.

Example:
---
int res;
foreach(i; iotaTuple!5) // same as res += foo!1(); res += foo!3();
	static if(i & 1)
		res += foo!i();
---

Analog of $(PHOBOSREF range, iota) for generic tuples.
*/
template iotaTuple(alias begin, alias end, alias step)
{
	alias iotaTupleImpl!(CommonType!(typeof(begin), typeof(end), typeof(step)), begin, end, step) iotaTuple;
}

/// ditto
template iotaTuple(alias begin, alias end)
{
	alias iotaTupleImpl!(CommonType!(typeof(begin), typeof(end)), begin, end, 1) iotaTuple;
}

/// ditto
template iotaTuple(alias end)
{
	alias iotaTupleImpl!(typeof(end), 0, end, 1) iotaTuple;
}

private template iotaTupleImpl(T, T begin, T end, T step)
	if(isIntegral!T || isFloatingPoint!T && step)
{
	static if(begin < end && step < 0 || begin > end && step > 0 || begin == end)
		alias expressionTuple!() iotaTupleImpl;
	else static if(step)
		alias expressionTuple!(begin, iotaTupleImpl!(T, begin + step, end, step)) iotaTupleImpl;
	else
		static assert(0, "iotaTuple: `step` can't be zero for nonequal `begin` and `end`");
}

unittest
{
	static assert(iotaTuple!0.length == 0);
	static assert(iotaTuple!(10, 1).length == 0);
	static assert(iotaTuple!(1, 10, -1).length == 0);
	static assert(iotaTuple!(2, 2, 0).length == 0);
	static assert(!__traits(compiles, iotaTuple!(1, 2, 0)));

	static assert(equalTuple!(PackedGenericTuple!(iotaTuple!1), PackedGenericTuple!0));
	static assert(equalTuple!(PackedGenericTuple!(iotaTuple!3), PackedGenericTuple!(0, 1, 2)));
	static assert(equalTuple!(PackedGenericTuple!(iotaTuple!(1.0, 3)), PackedGenericTuple!(1.0, 2.0)));
	static assert(equalTuple!(PackedGenericTuple!(iotaTuple!(1, 3.1f)), PackedGenericTuple!(1.0, 2.0, 3.0)));
	static assert(equalTuple!(PackedGenericTuple!(iotaTuple!(3, 0, -1)), PackedGenericTuple!(3, 2, 1)));
	static assert(equalTuple!(PackedGenericTuple!(iotaTuple!(3, 2, -.5)), PackedGenericTuple!(3.0, 2.5)));
}


/**
TODO docs

Analog of $(PHOBOSREF algorithm, cmp) for generic tuples.
*/
template cmpTuple(alias pred, alias packedTuple1, alias packedTuple2)
	if(isPackedTuple!packedTuple1 && isPackedTuple!packedTuple2)
{
	alias BinaryPred!pred predTemplate;

	static if (packedTuple1.empty)
		enum cmpTuple = -cast(int) !packedTuple2.empty;
	else static if (packedTuple2.empty)
		enum cmpTuple = cast(int) !packedTuple1.empty;
	else static if (predTemplate!(packedTuple1.Tuple[0], packedTuple2.Tuple[0]))
		enum cmpTuple = -1;
	else static if (predTemplate!(packedTuple2.Tuple[0], packedTuple1.Tuple[0]))
		enum cmpTuple = 1;
	else
		enum cmpTuple = cmpTuple!(predTemplate, PackedGenericTuple!(packedTuple1.Tuple[1 .. $]), PackedGenericTuple!(packedTuple2.Tuple[1 .. $]));
}

/// ditto
template cmpTuple(alias packedTuple1, alias packedTuple2)
{
	enum cmpTuple = cmpTuple!(`__A[0] < __A[1]`, packedTuple1, packedTuple2);
}

unittest
{
	static assert(cmpTuple!(PackedGenericTuple!(), PackedGenericTuple!()) == 0);
	static assert(cmpTuple!(PackedGenericTuple!0, PackedGenericTuple!0) == 0);
	static assert(cmpTuple!(PackedGenericTuple!0, PackedGenericTuple!1) < 0);
	static assert(cmpTuple!(PackedGenericTuple!0, PackedGenericTuple!(0, 0)) < 0);
	static assert(cmpTuple!(PackedGenericTuple!(0, 0), PackedGenericTuple!0) > 0);
	static assert(cmpTuple!(PackedGenericTuple!1, PackedGenericTuple!(0, 0)) > 0);

	static assert(cmpTuple!(PackedGenericTuple!"a", PackedGenericTuple!"a") == 0);
	static assert(cmpTuple!(PackedGenericTuple!"a", PackedGenericTuple!"ab") < 0);
	static assert(cmpTuple!(PackedGenericTuple!"b", PackedGenericTuple!"ab") > 0);

	static assert(cmpTuple!(`__A[0].sizeof < __A[1].sizeof`, PackedGenericTuple!int, PackedGenericTuple!long) < 0);
}


/**
Detect whether $(D packedTuple1) and $(D packedTuple2) elements are equal according to $(D pred).
$(D isSame) is used if not predicacte specified.

Analog of $(PHOBOSREF algorithm, equal) for generic tuples.
*/
template equalTuple(alias pred, alias packedTuple1, alias packedTuple2)
	if(isPackedTuple!packedTuple1 && isPackedTuple!packedTuple2)
{
	alias BinaryPred!pred predTemplate;

	template instForPackedTuple(alias packedTuple)
		if(isPackedTuple!packedTuple && packedTuple.length == 2)
	{
		enum instForPackedTuple = predTemplate!(packedTuple.Tuple);
	}

	static if(packedTuple1.length == packedTuple2.length)
		enum equalTuple = allSatisfy!(instForPackedTuple, ZipTuple!(packedTuple1, packedTuple2));
	else
		enum equalTuple = false;
}

/// ditto
template equalTuple(alias packedTuple1, alias packedTuple2)
{
	enum equalTuple = equalTuple!(isSame, packedTuple1, packedTuple2);
}

unittest
{
	static assert( equalTuple!(PackedGenericTuple!(), PackedGenericTuple!()));
	static assert( equalTuple!(PackedGenericTuple!0, PackedGenericTuple!0));
	static assert(!equalTuple!(PackedGenericTuple!0, PackedGenericTuple!int));
	static assert(!equalTuple!(PackedGenericTuple!0, PackedGenericTuple!(0, 1)));
	static assert( equalTuple!(PackedGenericTuple!(0, 1), PackedGenericTuple!(iotaTuple!2)));
	static assert( equalTuple!(PackedGenericTuple!(int, "a"), PackedGenericTuple!(int, "a")));

	static assert(!equalTuple!(`true`, PackedGenericTuple!1, PackedGenericTuple!()));
	static assert( equalTuple!(`true`, PackedGenericTuple!1, PackedGenericTuple!int));
}


/**
Filters a generic tuple $(D A) using a predicate $(D Pred).

Example:
----
import std.traits;

static assert(is(FilterTuple!(isNumeric, int, void, immutable short, char) ==
              TypeTuple!(int, immutable short)));
----

Analog of $(PHOBOSREF algorithm, filter) for generic tuples.
*/
template FilterTuple(alias Pred, A...)
{
	alias UnaryTemplate!Pred PredTemplate;

	template func(A...) if(A.length == 1)
	{ alias A[0 .. PredTemplate!(A[0])] func; }

	alias MapTuple!(func, A) FilterTuple;
}

unittest
{
	import std.traits;

	static assert(is(FilterTuple!(isNumeric, int, size_t, void, immutable short, char) ==
		TypeTuple!(int, size_t, immutable short)));

	static assert(is(FilterTuple!(`__traits(isUnsigned, T)`, int, size_t, void, immutable ushort, char) ==
		TypeTuple!(size_t, immutable ushort, char)));
}


/**
TODO docs

Example:
---
alias MapTuple!(`a * a`, iotaTuple!4) squares; // Creates expression tuple (0, 1, 4, 9)
static assert(is(MapTuple!(`T[]`, int, long) == TypeTuple!(int[], long[])));
---

Analog of $(PHOBOSREF algorithm, map) for generic tuples
except $(D Func) can return any count of elements.
*/
template MapTuple(alias Func, A...)
{
	alias UnaryTemplate!Func FuncTemplate;

	static if (A.length)
		alias GenericTuple!(FuncTemplate!(A[0]), MapTuple!(FuncTemplate, A[1 .. $])) MapTuple;
	else
		alias GenericTuple!() MapTuple;
}

unittest
{
	static assert(MapTuple!`1`.length == 0);
	static assert(equalTuple!(PackedGenericTuple!(MapTuple!(`1`, const int)),  PackedGenericTuple!1));
	static assert(is(MapTuple!(Unqual, int, immutable int) == TypeTuple!(int, int)));
	static assert(is(MapTuple!(`T[]`, int, long) == TypeTuple!(int[], long[])));
	alias MapTuple!(`a * a`, iotaTuple!4) squares;
	static assert(equalTuple!(PackedGenericTuple!squares, PackedGenericTuple!(0, 1, 4, 9)));
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
