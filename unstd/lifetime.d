/** Functions for user-defined _lifetime implementation.

Copyright: Denis Shelomovskij 2012-2013

License: $(HTTP boost.org/LICENSE_1_0.txt, Boost License 1.0).

Authors: Denis Shelomovskij
*/
module unstd.lifetime;

import unstd.array;
import unstd.traits;
import unstd.generictuple;
import std.exception;


/**
Moves $(D source) into $(D target).

Specifically:
$(UL
	$(LI Does nothing if $(D &source is &target) (for the first overload only).
		)
	$(LI Destroys $(D target) if needed (for the first overload only, see
		$(STDREF traits, hasElaborateDestructor))
		)
	$(LI Bitwise copies $(D source) into $(D target).
		)
	$(LI If $(D hasElaborateCopyConstructor!T || hasElaborateDestructor!T)
		is $(D true) (see $(STDREF traits, hasElaborateCopyConstructor)),
		then sets $(D source) to $(D T.init).
		)
)
See also $(STDREF exception, pointsTo).

Preconditions:
$(D &source == &target || !pointsTo(source, source))
*/
void move(T)(ref T source, ref T target)
in { assert(&source == &target || !pointsTo(source, source)); }
body
{
	// Performance optimization:
	// Do not compare addresses if we don't have side effects,
	// T is assignable, and T fits in register.
	static if(hasElaborateCopyConstructor!T || hasElaborateAssign!T ||
		hasElaborateDestructor!T || !isAssignable!T ||
		T.sizeof > size_t.sizeof)
		if (&source == &target) return;

	static if(hasElaborateDestructor!T)
		destruct(target, false);

	static if(hasElaborateAssign!T || !isAssignable!T)
		rawCopy(*cast(Unqual!T*) &source, *cast(Unqual!T*) &target);
	else
		target = source;

	static if(hasElaborateCopyConstructor!T || hasElaborateDestructor!T)
		setToInitialState(source);
}

unittest
{
	Object obj1 = new Object;
	Object obj2 = obj1;
	Object obj3;
	move(obj2, obj3);
	assert(obj3 is obj1);

	static struct S1 { int a = 1, b = 2; }
	S1 s11 = { 10, 11 };
	S1 s12;
	move(s11, s12);
	assert(s11.a == 10 && s11.b == 11 && s12.a == 10 && s12.b == 11);

	shared S1 sharedS11, sharedS12;
	move(sharedS11, sharedS12);

	const int constI11, constI12;
	void constTest(in int ci1) { const ci2 = move(ci1); }

	static struct S2 { int a = 1; int * b; }
	S2 s21 = { 10, null };
	s21.b = new int;
	S2 s22;
	move(s21, s22);
	assert(s21 == s22);

	// Issue 5661 test(1)
	static struct S3
	{
		static struct X { int n = 0; ~this(){n = 0;} }
		X x;
	}
	static assert(hasElaborateDestructor!S3);
	S3 s31, s32;
	s31.x.n = 1;
	move(s31, s32);
	assert(s31.x.n == 0);
	assert(s32.x.n == 1);

	// Issue 5661 test(2)
	static struct S4
	{
		static struct X { int n = 0; this(this){n = 0;} }
		X x;
	}
	static assert(hasElaborateCopyConstructor!S4);
	S4 s41, s42;
	s41.x.n = 1;
	move(s41, s42);
	assert(s41.x.n == 0);
	assert(s42.x.n == 1);
}

/// Ditto
T move(T)(ref T source)
{
	// Can avoid to check aliasing here.

	static if(hasElaborateCopyConstructor!T || hasElaborateDestructor!T)
	{
		T result = void;
		rawCopy(source, result);
		setToInitialState(source);
		return result;
	}
	else
	{
		return source;
	}
}

unittest
{
	Object obj1 = new Object;
	Object obj2 = obj1;
	Object obj3 = move(obj2);
	assert(obj3 is obj1);

	static struct S1 { int a = 1, b = 2; }
	S1 s11 = { 10, 11 };
	S1 s12 = move(s11);
	assert(s11.a == 10 && s11.b == 11 && s12.a == 10 && s12.b == 11);

	shared S1 sharedS11, sharedS12 = move(sharedS11);
	void constTest(in int ci1, in int ci2) { move(ci1, ci2); }

	static struct S2 { int a = 1; int * b; }
	S2 s21 = { 10, null };
	s21.b = new int;
	S2 s22 = move(s21);
	assert(s21 == s22);

	// Issue 5661 test(1)
	static struct S3
	{
		static struct X { int n = 0; ~this(){n = 0;} }
		X x;
	}
	static assert(hasElaborateDestructor!S3);
	S3 s31;
	s31.x.n = 1;
	S3 s32 = move(s31);
	assert(s31.x.n == 0);
	assert(s32.x.n == 1);

	// Issue 5661 test(2)
	static struct S4
	{
		static struct X { int n = 0; this(this){n = 0;} }
		X x;
	}
	static assert(hasElaborateCopyConstructor!S4);
	S4 s41;
	s41.x.n = 1;
	S4 s42 = move(s41);
	assert(s41.x.n == 0);
	assert(s42.x.n == 1);
}

unittest//Issue 6217
{
	import std.algorithm;
	auto x = map!"a"([1,2,3]);
	x = move(x);
}

unittest// Issue 8055
{
	static struct S
	{
		int x;
		~this() { assert(x == 0); }
	}
	S foo(S s) { return move(s); }
	S a;
	a.x = 0;
	auto b = foo(a);
	assert(b.x == 0);
}

unittest// Issue 8057
{
	int n = 10;
	struct S
	{
		int x;
		~this()
		{
			// Struct always can equal to its `init`
			if(this == S.init) return;
			// Access to enclosing scope
			assert(n == 10);
		}
	}
	S foo(S s)
	{
		// Move nested struct
		return move(s);
	}
	S a;
	a.x = 1;
	auto b = foo(a);
	assert(b.x == 1);

	// Regression 8171
	static struct Array(T)
	{
		// nested struct has no member
		struct Payload
		{
			~this() {}
		}
	}
	Array!int.Payload x = void;
	static assert(__traits(compiles, move(x)    ));
	static assert(__traits(compiles, move(x, x) ));
}


/**
Forwards function arguments with saving ref-ness.

Example:
---
int foo(int n) { return 1; }
int foo(ref int n) { return 2; }
int bar()(auto ref int x) { return foo(forward!x); }

assert(bar(1) == 1);
int i;
assert(bar(i) == 2);
---

---
void foo(int n, ref string s) { s = null; foreach (i; 0..n) s ~= "Hello"; }

// forwards all arguments which are bound to parameter tuple
void bar(Args...)(auto ref Args args) { return foo(forward!args); }

// forwards all arguments with swapping order
void baz(Args...)(auto ref Args args) { return foo(forward!args[$/2..$], forward!args[0..$/2]); }

string s;
bar(1, s);
assert(s == "Hello");
baz(s, 2);
assert(s == "HelloHello");
---

Note:
This is just a copy of $(STDREF algorithm, _forward)
implementation except it uses fixed $(D move).
*/
template forward(args...)
{
	static if (args.length)
	{
		alias args[0] arg;
		static if (__traits(isRef, arg))
			alias arg fwd;
		else
			@property fwd()() { return move(arg); }
		alias expressionTuple!(fwd, forward!(args[1 .. $])) forward;
	}
	else
		alias expressionTuple!() forward;
}

// Note: unittest can't be used as an example here as there is no way to place it before `Note` section.

unittest
{
	class C
	{
		static int foo(int n) { return 1; }
		static int foo(ref int n) { return 2; }
	}
	int bar()(auto ref int x) { return C.foo(forward!x); }

	assert(bar(1) == 1);
	int i;
	assert(bar(i) == 2);
}

unittest
{
	void foo(int n, ref string s) { s = null; foreach (i; 0..n) s ~= "Hello"; }

	void bar(Args...)(auto ref Args args) { return foo(forward!args); }

	void baz(Args...)(auto ref Args args) { return foo(forward!args[$/2..$], forward!args[0..$/2]); }

	string s;
	bar(1, s);
	assert(s == "Hello");
	baz(s, 2);
	assert(s == "HelloHello");
}

unittest
{
	auto foo(TL...)(auto ref TL args)
	{
		string result = "";
		foreach (i, _; args)
		{
			//pragma(msg, "[",i,"] ", __traits(isRef, args[i]) ? "L" : "R");
			result ~= __traits(isRef, args[i]) ? "L" : "R";
		}
		return result;
	}

	string bar(TL...)(auto ref TL args)
	{
		return foo(forward!args);
	}
	string baz(TL...)(auto ref TL args)
	{
		int x;
		return foo(forward!args[3], forward!args[2], 1, forward!args[1], forward!args[0], x);
	}

	struct S {}
	S makeS(){ return S(); }
	int n;
	string s;
	assert(bar(S(), makeS(), n, s) == "RRLL");
	assert(baz(S(), makeS(), n, s) == "LLRRRL");
}

unittest
{
	ref int foo(ref int a) { return a; }
	ref int bar(Args)(auto ref Args args)
	{
		return foo(forward!args);
	}
	static assert(!__traits(compiles, { auto x1 = bar(3); })); // case of NG
	int value = 3;
	auto x2 = bar(value); // case of OK
}


// Used in `_initializeFromImplicitlyConvertible` and `constructFrom` overload for static arrays.
private template _implicitlyConvertibleDim(From, To)
{
	template impl(To, From, size_t dim)
	{
		static if(isImplicitlyConvertible!(From, To))
			enum impl = dim;
		else static if(isStaticArray!To)
			enum impl = impl!(ArrayElementType!To, From, dim + 1);
		else
			enum impl = -1;
	}

	enum _implicitlyConvertibleDim = impl!(To, From, 0);
}

unittest
{
	alias _implicitlyConvertibleDim dim;

	static assert(dim!(int, int) == 0);
	static assert(dim!(int, int[1][1]) == 2);
	static assert(dim!(int[1], int[1][1]) == 1);
	static assert(dim!(int[1], int) == -1);
	static assert(dim!(int, long) == 0);
	static assert(dim!(int, long[1][1]) == 2);
	static assert(dim!(long, int) == -1);
}


// Used in `constructFrom` and `constructFromLiteral`.
private void _initializeFromImplicitlyConvertible(D, S)(ref D dest, ref S src)
	if(__traits(compiles, { D d = S.init; }))
{
	enum dim = _implicitlyConvertibleDim!(S, Unqual!D);
	static assert(dim != -1); // should never fail
	foreach(ref element; asFlatStaticArray!dim(dest))
	{
		alias Unqual!(typeof(element)) U;

		static if(is(S == struct))
		{
			// Argument is implicitly convertible to `D` or to it's element type.
			// As we are dealing with structs here, this means both types are
			// the same type with, possibly, different qualifiers.
			static assert(is(U == Unqual!S)); // should never fail

			rawCopy!U(*cast(U*) &src, *cast(U*) &element);
			callPostblits(element);
		}
		else static if(isAssignable!D)
		{
			element = src;
		}
		else
		{
			(*cast(U*) &element) = src;
		}
	}
}

unittest
{
	alias _initializeFromImplicitlyConvertible init;

	static assert( __traits(compiles, init!(int, int)));
	static assert( __traits(compiles, init!(long, int)));
	static assert(!__traits(compiles, init!(int, long)));
	static assert( __traits(compiles, init!(const int*, int*)));
	static assert( __traits(compiles, init!(const int*, immutable int*)));
	static assert(!__traits(compiles, init!(immutable int*, const int*)));
	static assert( __traits(compiles, init!(shared int*, shared int*)));
	static assert( __traits(compiles, init!(const shared int*, shared int*)));

	{
		int src = 1, dest;
		init(dest, src);
		assert(dest == 1);
	}
	{
		int src = 1;
		long dest;
		init(dest, src);
		assert(dest == 1);
	}
	{
		int src = 1;
		long[2][1] dest;
		init(dest, src);
		assert(dest == [[1, 1]]);
	}
	{
		int* src = cast(int*) 1;
		const(int*)[2][1] dest;
		init(dest, src);
		assert(dest == [[cast(int*) 1, cast(int*) 1]]);
	}
	{
		static struct S
		{ int* p; }

		S src = S(cast(int*) 1);
		const S dest;
		init(dest, src);
		assert(cast(int) dest.p == 1);
	}
}


/**
Constructs an object of type $(D T) at given address to uninitialized memory
just like $(D T t = arg;).
*/
void constructFrom(T, Arg)(T* chunk, auto ref Arg arg)
{
	static if(is(T == struct))
	{
		static if(is(Unqual!T == Unqual!Arg))
		{
			// Initializing struct with the same type

			static if(isImplicitlyConvertible!(Arg, T))
			{
				_initializeFromImplicitlyConvertible(*chunk, arg);
			}
			else
			{
				static assert(0, "Can't implicitly convert expression of type "
					~ Arg.stringof ~ " to " ~ T.stringof);
			}
		}
		else
		{
			constructFromLiteral(chunk, forward!arg);
		}
	}
	else static if(__traits(compiles, { T t = arg; }))
	{
		_initializeFromImplicitlyConvertible(*chunk, arg);
	}
	else
	{
		static assert(0, "`" ~ T.stringof ~ " t = " ~ Args.stringof
			~ ";` doesn't compile.");
	}
}

// Test copying from same struct branch

unittest
{
	static struct S
	{
		int i = 1;
		this(int _i) inout { i = _i; }
		this(const S);
	}

	// Initializing struct with the same type doesn't call constructor.
	S s = void;
	constructFrom(&s, S(2));
	assert(s.i == 2);
	constructFrom(&s, immutable S(3));
	assert(s.i == 3);
}

unittest
{
	static struct S
	{
		int* p;
		this(const S);
	}

	// Initializing struct with the same type requires implicit cast.
	S s = void;
	static assert(!__traits(compiles, constructFrom(&s, immutable S())));
}

// Test redirection to `constructFromLiteral` branch

unittest // constructors
{
	static struct S
	{
		this(int n) { assert(n == 2); }
		this(ref int n) { assert(n == 3); }
	}

	S s;
	short sh = 2;
	int i = 3;

	constructFrom(&s, 2);   // calls this(int n)
	constructFrom(&s, sh);  // calls this(int n)
	constructFrom(&s, i);   // calls this(ref int n)
}

// Test non-struct branches

unittest
{
	{
		uint i = void;

		constructFrom(&i, 3);
		assert(cast(int) i == 3);

		constructFrom(&i, 4U);
		assert(cast(int) i == 4);

		static assert(!__traits(compiles, constructFrom(&i, 0L)));
		static assert(!__traits(compiles, constructFrom(&i, 0UL)));
	}

	{
		void* p = void;

		constructFrom(&p, cast(void*) 3);
		assert(cast(int) p == 3);

		static assert(!__traits(compiles, constructFrom(&p, 0)));
		static assert(!__traits(compiles, constructFrom(&p, 0, 0)));
		static assert(!__traits(compiles, constructFrom(&p, (const void*).init)));
		static assert(!__traits(compiles, constructFrom(&p, (shared void*).init)));
	}

	// shared
	{
		shared void* p;
		constructFrom(&p, cast(shared void*) 3);
		assert(cast(int) p == 3);

		static assert(!__traits(compiles, constructFrom(&p, (const void*).init)));
		static assert(!__traits(compiles, constructFrom(&p, (void*).init)));
	}

	// const
	{
		foreach(T; TypeTuple!(immutable void, const void, void))
		{
			void* p = void;
			constructFrom(cast(const void**) &p, cast(T*) 1);
			assert(cast(int) p == 1);
		}

		void* p = void;
		static assert(!__traits(compiles, constructFrom(cast(const void**) &p, (shared void*).init)));
	}
}


/**
Constructs an object of $(D struct) type $(D S) at given address to uninitialized memory
just like $(D auto s = S(args);).
*/
void constructFromLiteral(S, Args...)(S* chunk, auto ref Args args)
	if(is(S == struct))
{
	static if(hasMember!(S, "__ctor"))
	{
		// `S` defines a constructor.

		static assert(!isNested!S, "Can't initialize nested struct "
			~ S.stringof ~ " with context pointer using constructor.");

		// Let's initialize `chunk` and call the constructor!
		setToInitialState(*chunk);

		chunk.__ctor(forward!args);
	}
	else static if(hasMember!(S, "opCall"))
	{
		static assert(0, "Can't initialize struct " ~ S.stringof ~ " using `opCall`." ~
			" Use `constructFrom(chunk, " ~ S.stringof ~ "(...))` instead.");
	}
	else static if(__traits(compiles, { auto t = S(args); }))
	{
		// Struct without constructor that has one matching field for
		// each argument (i.e. each field is initializable from the
		// corresponding argument).

		static assert(!anySatisfy!(hasNested, FieldTypeTuple!S[Args.length .. $]),
			"To initialize struct "  ~ S.stringof ~ " using static initialization" ~
			" you must explicitly pass arguments for all fields with context pointers.");

		// If struct fields doesn't have copy constructors
		// and every field has corresponding argument,
		// we still need to initialize the struct
		// because of possible padding holes.
		setToInitialState(*chunk);

		foreach(i, ref field; chunk.tupleof[0 .. Args.length])
			_initializeFromImplicitlyConvertible(field, args[i]);
	}
	else
	{
		static assert(0, "`auto t = "~ S.stringof
			~ "(" ~ Args.stringof ~ ");` doesn't compile.");
	}
}

// Test constructor branch

unittest // copying from same struct
{
	static struct S
	{
		int i = 1;
		this(int _i) inout { i = _i; }
		this(const S s) { i = 10 + s.i; }
	}

	// Call constructor even if copying from same struct.
	S s = void;
	constructFromLiteral(&s, S(2));
	assert(s.i == 12);
	constructFromLiteral(&s, immutable S(3));
	assert(s.i == 13);
}

unittest // copying from same struct if implicit cast isn't allowed
{
	static struct S
	{
		int i = 1;
		void* p = cast(void*) 7;
		this(const S) { i = 2; }
	}

	S s = void;
	constructFromLiteral(&s, immutable S());
	assert(s.i == 2);
}

unittest // context pointer
{
	int i;
	struct S { this(int) { ++i; } }
	S s = void;
	static assert(!__traits(compiles, constructFromLiteral(&s, 0)));

	static int si = 0;
	static struct S3 { S s; this(int) { s = S.init; ++si; } }
	S3 s3 = void;
	constructFromLiteral(&s3, 0);
	assert(si == 1);
}

unittest // constructors
{

	static void* p;
	static int i = 2, j = 2;
	static struct S
	{
		int[2] arr = 1;
		this(int n1, int n2, ref int _i, out int _j)
		{
			assert(&this == p && arr == [1, 1]);
			assert(n1 == 1 && n2 == 2);
			assert(&_i == &i && &_j == &j);
			assert(_i++ == 2 && _j++ == 0);
		}

		this(int n)
		{ assert(n == 2); }

		this(ref int n)
		{ assert(n == 3); }
	}
	S s; p = &s;
	short sh = 2;
	constructFromLiteral(&s, 1, sh, i, j);
	assert(i == 3 && j == 1);

	static assert(!__traits(compiles, constructFromLiteral(&s, 1, 1, 0, j)));
	static assert(!__traits(compiles, constructFromLiteral(&s, 1, 1, i, 0)));
	static assert(!__traits(compiles, constructFromLiteral(&s, 1, 1, sh, j)));
	static assert(!__traits(compiles, constructFromLiteral(&s, 1, 1, i, sh)));

	constructFromLiteral(&s, 2);   // calls this(int n)
	constructFromLiteral(&s, sh);  // calls this(int n)
	constructFromLiteral(&s, i);   // calls this(ref int n)
}

unittest // templated constructors
{
	static void* p;
	static int i = 0;
	static struct S
	{
		int[2] arr = 1;
		this(T)(auto ref T t)
		{
			assert(&this == p && arr == [1, 1]);
			assert(i++ == __traits(isRef, t));
		}
	}
	S s; p = &s;
	constructFromLiteral(&s, 1);  // calls this(int t)
	assert(i == 1);
	short sh = 1;
	constructFromLiteral(&s, sh); // calls this(ref int t)
	assert(i == 2);
}

// Test opCall branch

unittest // opCall
{
	int i;
	struct S
	{
		int i;
		static S opCall(int);
	}
	S s = void;
	static assert(!__traits(compiles, constructFromLiteral(&s, 0)));
}

// Test matching fields branch

unittest
{
	struct S { int a, b; this(int) {} }
	S s;
	static assert(!__traits(compiles, constructFromLiteral(&s, 0, 0)));
}

unittest // context pointer
{
	int i;
	struct S { this(int) { ++i; } }
	S s = void;

	static struct S2 { int i; S s; }
	S2 s2 = void;
	static assert(!__traits(compiles, constructFromLiteral(&s2, 0)));
	constructFromLiteral(&s2, 0, S(0));
	assert(i == 1);
}

unittest // qualifiers
{
	static struct S
	{ uint a = 1; void* b = null; }

	{
		S s;

		constructFromLiteral(&s, 2U);
		assert(s.a == 2 && !s.b);

		constructFromLiteral(&s, 3);
		assert(s.a == 3 && !s.b);

		immutable int immutableI = 4;
		constructFromLiteral(&s, immutableI);
		assert(s.a == 4 && !s.b);

		constructFromLiteral(&s, 0, cast(void*) 3);
		assert(!s.a && cast(int) s.b == 3);

		// Note: S(0L) compiles because compiler knows constan value.
		static assert(!__traits(compiles, constructFromLiteral(&s, 0L)));
		static assert(!__traits(compiles, constructFromLiteral(&s, 0, 0)));
		static assert(!__traits(compiles, constructFromLiteral(&s, 0, 0, 0)));
		static assert(!__traits(compiles, constructFromLiteral(&s, 0, (const void*).init)));
		static assert(!__traits(compiles, constructFromLiteral(&s, 0, (shared void*).init)));
	}

	// shared
	{
		shared S s;
		constructFromLiteral(&s, 0, cast(shared void*) 3);
		assert(!s.a && cast(int) s.b == 3);

		static assert(!__traits(compiles, constructFromLiteral(&s, 0, (const void*).init)));
		static assert(!__traits(compiles, constructFromLiteral(&s, 0, (void*).init)));
	}

	// const
	{
		foreach(T; TypeTuple!(immutable void, const void, void))
		{
			S s = void;
			constructFromLiteral(cast(const S*) &s, 0, cast(T*) 1);
			assert(!s.a && cast(int) s.b == 1);
		}

		S s = void;
		static assert(!__traits(compiles, constructFromLiteral(cast(const S*) &s, 0, (shared void*).init)));
	}
}

unittest // static array
{
	static struct S
	{ int[2][1] sarr; }

	{
		S s = void;
		constructFromLiteral(&s, 2);
		assert(s.sarr[0] == [2, 2]);
	}
	{
		S s = void;
		static assert(!__traits(compiles, constructFromLiteral(&s, (int[1]).init)));
		// Note: S([3, 4]) compiles without cast because compiler knows array literal value.
		constructFromLiteral(&s, cast(int[2]) [3, 4]);
		assert(s.sarr[0] == [3, 4]);
	}
}


/**
Constructs an object of $(D class) type $(D C) at given reference to uninitialized memory
just like $(D auto c = new C(args);) except given memory is used instead of allocating.
*/
void initializeClassInstance(C, Args...)(C chunk, auto ref Args args)
	if(is(C == class))
{
	version(none) // FIXME: isNested isn't implemented for classes yet
	static assert(!isNested!C, "Can't initialize nested class " ~ C.stringof);

	(cast(byte*) chunk)[0 .. __traits(classInstanceSize, C)] = typeid(Unqual!C).init[];

	static if(hasMember!(C, "__ctor"))
	{
		chunk.__ctor(forward!args);
	}
	else static if(Args.length)
	{
		static assert(0, "No constructor for class " ~ C.stringof);
	}
	else
	{
		static assert(!anySatisfy!(hasNested, FieldTypeTuple!C),
			"Can't initialize class " ~ C.stringof
			~ " without constructor but with nested fields.");
	}
}

// Test context pointer check

unittest
{
	int i;
	{
		class C { void f() { ++i; } }
		C c;
		version(none) // FIXME: disabled as isNested isn't implemented for classes yet
		static assert(!__traits(compiles, initializeClassInstance(c)));
	}

	{
		struct S { void f() { ++i; } }
		static int si = 0;
		static class C2 { S s; this(int) { s = S.init; ++si; } }

		void[__traits(classInstanceSize, C2)] buff = void;
		auto c2 = cast(C2) buff.ptr;
		initializeClassInstance(c2, 0);
		assert(si == 1);
	}
}

// Test constructor branch

unittest
{
	static void* p;
	static int i = 2, j = 2;
	static class C
	{
		int[2] arr = 1;
		this(int n1, int n2, ref int _i, out int _j)
		{
			assert(cast(void*) this == p && arr == [1, 1]);
			assert(n1 == 1 && n2 == 2);
			assert(&_i == &i && &_j == &j);
			assert(_i++ == 2 && _j++ == 0);
		}

		this(int n)
		{ assert(n == 2); }

		this(ref int n)
		{ assert(n == 3); }
	}

	void[__traits(classInstanceSize, C)] buff = void;
	auto c = cast(C) (p = buff.ptr);
	short sh = 2;
	initializeClassInstance(c, 1, sh, i, j);
	assert(i == 3 && j == 1);

	static assert(!__traits(compiles, initializeClassInstance(c, 1, 1, 0, j)));
	static assert(!__traits(compiles, initializeClassInstance(c, 1, 1, i, 0)));
	static assert(!__traits(compiles, initializeClassInstance(c, 1, 1, sh, j)));
	static assert(!__traits(compiles, initializeClassInstance(c, 1, 1, i, sh)));

	initializeClassInstance(c, 2);   // calls this(int n)
	initializeClassInstance(c, sh);  // calls this(int n)
	initializeClassInstance(c, i);   // calls this(ref int n)
}

// Test no-constructor branches

unittest
{
	static class C { int i = -1; }

	void[__traits(classInstanceSize, C)] buff = void;
	auto c = cast(C) buff.ptr;
	initializeClassInstance(c);
	assert(c.i == -1);

	static assert(!__traits(compiles, initializeClassInstance(c, 0)));
}

unittest
{
	int i;
	struct S
	{ int i = -1; void f() { ++i; } }

	static class C1 { S s; }
	C1 c1;
	static assert(!__traits(compiles, initializeClassInstance(c1)));

	static class C2
	{ S s; this() { s = S.init; } }
	void[__traits(classInstanceSize, C2)] buff2 = void;
	auto c2 = cast(C2) buff2.ptr;
	initializeClassInstance(c2);
	assert(c2.s.i == -1);
}


private extern (C) void rt_finalize2(void* p, bool det, bool resetMemory);

/**
Destroys the given class instance and puts it in an invalid state. It's used
to destroy an object so that any cleanup which its destructor or finalizer
does is done.
It does $(I not) initiate a GC cycle or free any GC memory.
It $(I always) zero class instance $(D __vptr).
If $(D resetMemory) is $(D true) it will also set class instance memory to
its initial state so that it no longer references any other objects.
*/
void finalizeClassInstance(T)(T t, bool resetMemory = true)
{
	static if(is(T == class))
		alias t obj;
	else static if(is(T == interface))
		auto obj = cast(Object) t;
	else
		static assert(0, "Can only finalize class or interface, not " ~ T.stringof);

	rt_finalize2(cast(void*) obj, true, resetMemory);
}

unittest
{
	interface I { }
	static bool destroyed = false;
	static class A: I
	{
		int n = -1;
		this() {}
		~this() { destroyed = true; }
	}

	auto a = new A, b = new A;
	a.n = b.n = 2;
	finalizeClassInstance(a);
	assert(destroyed);
	assert(a.n == -1);

	destroyed = false;
	I i = b;
	finalizeClassInstance(i);
	assert(destroyed);
	assert(b.n == -1);
}

/**
Determines whether class instance $(D t) is finalized.

Also returns $(D true) if $(D t)'s memory is zero-filled.

$(D T) must be either $(D class) or $(D interface).
*/
bool isFinalized(T)(in T t)
{
	static if(is(T == class))
	{
		alias t obj;
	}
	else static if(is(T == interface))
	{
		const ppi = *cast(const Interface***) t;
		if(!ppi)
			return true;
		auto obj = cast(Object) (cast(void*) t - (*ppi).offset);
	}
	else
		static assert(0, "Can only check class or interface to be finalized, not " ~ T.stringof);

	return !obj.__vptr;
}

/// ditto
@property bool finalized(T)(in T t)
{ return isFinalized(t); }

unittest
{
	interface I { }
	static class A: I
	{
		int n = -1;
		this() { n = 2; }
	}

	{
		// Object reference

		auto a1 = new A, a2 = new A;
		const ca1 = a1;
		assert(!a1.finalized && !isFinalized(a2));
		assert(!ca1.finalized);
		finalizeClassInstance(a1);
		finalizeClassInstance(a2, false);
		assert(a1.finalized && isFinalized(a2));
		assert(ca1.finalized);
	}

	{
		// Interface reference

		I ia1 = new A, ia2 = new A;
		const cia1 = ia1, cia2 = ia2;
		assert(!ia1.finalized && !isFinalized(ia2));
		assert(!cia1.finalized);
		finalizeClassInstance(ia1);
		finalizeClassInstance(ia2, !false);
		assert(ia1.finalized && isFinalized(ia2));
		assert(cia1.finalized);
	}

	{
		// Zero-filled memory

		const size_t buff = 0;
		assert((cast(const A) &buff).finalized);
		assert((cast(const I) &buff).finalized);
	}

	{
		int i;
		assert(!__traits(compiles, i.finalized));
		assert(!__traits(compiles, isFinalized(i)));
		struct S { }
		assert(!__traits(compiles, S().finalized));
	}
}


/**
Destructs $(D t) exactly the same way a compiler does in a case it goes out of scope.
Also puts destructed object in its $(D init) state if $(D resetInitialState)
is $(D true), otherwise object state will be undefined (i.e. possibly invalid).
*/
void destruct(T)(ref T t, bool resetInitialState = true)
{
	callDestructors(t);
	if(resetInitialState)
		setToInitialState(t);
}

unittest
{
	int i = -1;
	destruct(i, false);
	assert(i == -1);
	destruct(i);
	assert(i == 0);

	static assert(!__traits(compiles, destruct(5))); // doesn't accept rvalue
}

unittest
{
	static int n = 0;
	static struct S
	{
		int i = -1;
		~this() { ++n; }
	}

	auto s = S(1);
	destruct(s, false);
	assert(s.i == 1 && n == 1);
	destruct(s);
	assert(s.i == -1 && n == 2);
}


/**
Sets the passed object to its `init` state.

Use this function instead of dealing with tricky $(D typeid(T).init()).
*/
void setToInitialState(T)(ref T t)
{
	alias Unqual!T U;

	static if(hasElaborateAssign!T || (!isAssignable!T && !isAssignable!U))
	{
		import core.stdc.string;

		// `typeid(T)` will also work but will cost a virtual call per each array
		// dimension. We will not be here for [static arrays of] classes so
		// there is no problems with `TypeInfo_Class.init` field name clash.
		if(auto p = typeid(MultidimensionalStaticArrayElementType!U).init().ptr)
			foreach(ref el; asFlatStaticArray((*cast(U*) &t)))
				memcpy(&el, p, typeof(el).sizeof);
		else
			memset(cast(void*) &t, 0, T.sizeof);
	}
	else static if(!isAssignable!T)
	{
		(*cast(U*) &t) = U.init;
	}
	else
	{
		t = T.init;
	}
}

unittest
{
	int i = -1;
	setToInitialState(i);
	assert(i == 0);

	static assert(!__traits(compiles, setToInitialState(5))); // doesn't accept rvalue

	static bool exited = false;

	static struct S(int def)
	{
		int i = def;
		@disable this();
		this(this)  { assert(0); }
		~this()     { assert(exited); }
	}

	S!0 s0 = void; s0.i = -1;
	setToInitialState(s0);
	assert(s0.i == 0);

	S!1 s1 = void; s1.i = -1;
	setToInitialState(s1);
	assert(s1.i == 1);

	S!1[2][1] sArr = void;
	foreach(ref el; sArr[0])
		el.i = -1;
	setToInitialState(sArr);
	assert(sArr == (S!1[2][1]).init);

	exited = true;
}

unittest // const
{
	static struct Int1
	{ int i = 1; }

	static struct S
	{ const Int1 i; }

	int i = 0;
	static assert(S.sizeof == i.sizeof);
	setToInitialState(*cast(S*) &i);
	assert(i == 1); i = 0;

	setToInitialState(*cast(const S*) &i);
	assert(i == 1); i = 0;
}


/**
Sets all elements of the passed dynamic array to its `init` state.

Use this function for better performance instead of calling
$(MREF setToInitialState) on each element.
*/
void setElementsToInitialState(T)(T[] arr)
{
	alias Unqual!T U;

	// This is just a copy of `setToInitialState` implementation.

	static if(hasElaborateAssign!T || (!isAssignable!T && !isAssignable!U))
	{
		import core.stdc.string;

		if(auto p = typeid(MultidimensionalStaticArrayElementType!U).init().ptr)
			foreach(ref t; arr)
				foreach(ref el; asFlatStaticArray((*cast(U*) &t)))
					memcpy(&el, p, typeof(el).sizeof);
		else
			memset(cast(void*) arr.ptr, 0, T.sizeof * arr.length);
	}
	else static if(!isAssignable!T)
	{
		(cast(U[]) arr)[] = U.init;
	}
	else
	{
		arr[] = T.init;
	}
}

unittest
{
	int[] i = new int[3];
	i[] = -1;
	setElementsToInitialState(i);
	assert(i == [0, 0, 0]);

	static bool exited = false;

	static struct S(int def)
	{
		int i = def;
		@disable this();
		this(this)  { assert(0); }
		~this()     { assert(exited); }
	}

	auto s0 = new S!0[2]; s0[0].i = s0[1].i = -1;
	setElementsToInitialState(s0);
	assert(s0[0].i == 0 && s0[1].i == 0);

	auto s1 = new S!1[2]; s1[0].i = s1[1].i = -1;
	setElementsToInitialState(s1);
	assert(s1[0].i == 1 && s1[1].i == 1);

	auto sArr = new S!1[2][1][1];
	foreach(ref el; sArr[0][0])
		el.i = -1;
	setElementsToInitialState(sArr);
	assert(sArr[0] == (S!1[2][1]).init);

	exited = true;
}

unittest // const
{
	static struct Int1
	{ int i = 1; }

	static struct S
	{ const Int1 i; }

	int i = 0;
	static assert(S.sizeof == i.sizeof);
	setElementsToInitialState((cast(S*) &i)[0 .. 1]);
	assert(i == 1); i = 0;

	setElementsToInitialState((cast(const S*) &i)[0 .. 1]);
	assert(i == 1); i = 0;
}


/** Calls the postblit of the given object, if any.

Faster and convenient replacement for $(D typeid(T).postblit(&t)).
*/
void callPostblits(T)(ref T t)
{
	static if(hasElaborateCopyConstructor!T)
	{
		foreach(ref el; asFlatStaticArray(t))
		{
			foreach(ref field; el.tupleof)
				static if(hasElaborateCopyConstructor!(typeof(field)))
					callPostblits(field);

			static if(hasMember!(typeof(el), "__postblit"))
				el.__postblit();
		}
	}
}

unittest
{
	int i = -1;
	callPostblits(i); // no-op for non-elaborate types

	static assert(!__traits(compiles, callPostblits(5))); // doesn't accept rvalue

	static int[] log;
	static void checkLog(int[] arr...)
	{ assert(log == arr); log = null; }

	static bool exited = false;

	static struct S
	{
		int i;
		@disable this();
		this(this)  { log ~= i; }
		~this()     { assert(exited); }
	}

	S s = void; s.i = -1;
	callPostblits(s);
	checkLog(-1);

	S[3][2][1] sArr = void;
	foreach(j, ref el; *cast(S[6]*) sArr.ptr)
		el.i = j;
	callPostblits(sArr);
	checkLog(0, 1, 2, 3, 4, 5);

	static struct S2
	{
		S s;
		S[2] sArr;

		@disable this();
		this(this)  { log ~= -1; }
		~this()     { assert(exited); }
	}

	S2 s2 = void;
	foreach(j, ref el; *cast(S[3]*) &s2)
		el.i = j;
	callPostblits(s2);
	checkLog(0, 1, 2, -1);

	exited = true;
}


/** Calls the destructor of the given object, if any.

Faster and convenient replacement for $(D typeid(T).destroy(&t)).
*/
void callDestructors(T)(ref T t)
{
	static if(hasElaborateDestructor!T)
	{
		foreach_reverse(ref el; asFlatStaticArray(t))
		{
			static if(hasMember!(typeof(el), "__dtor"))
				el.__dtor();

			foreach_reverse(ref field; el.tupleof)
				static if(hasElaborateDestructor!(typeof(field)))
					callDestructors(field);
		}
	}
}

unittest
{
	int i = -1;
	callDestructors(i); // no-op for non-elaborate types

	static assert(!__traits(compiles, callDestructors(5))); // doesn't accept rvalue

	static int[] log;
	static void checkLog(int[] arr...)
	{ assert(log == arr); log = null; }

	static bool exited = false;

	static struct S
	{
		int i;
		@disable this();
		this(this)  { assert(exited); }
		~this()     { log ~= i; }
	}

	S s = void; s.i = -1;
	callDestructors(s);
	checkLog(-1);

	S[3][2][1] sArr = void;
	foreach(j, ref el; *cast(S[6]*) sArr.ptr)
		el.i = j;
	callDestructors(sArr);
	checkLog(5, 4, 3, 2, 1, 0);

	static struct S2
	{
		S s;
		S[2] sArr;

		@disable this();
		this(this)  { assert(exited); }
		~this()     { log ~= -1; }
	}

	S2 s2 = void;
	foreach(j, ref el; *cast(S[3]*) &s2)
		el.i = j;
	callDestructors(s2);
	checkLog(-1, 2, 1, 0);

	exited = true;
}
