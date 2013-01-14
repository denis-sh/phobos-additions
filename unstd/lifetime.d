/** Functions for user-defined _lifetime implementation.

Copyright: Denis Shelomovskij 2012

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
