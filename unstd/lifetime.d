/** Functions for user-defined _lifetime implementation.

Copyright: Denis Shelomovskij 2012

License: $(HTTP boost.org/LICENSE_1_0.txt, Boost License 1.0).

Authors: Denis Shelomovskij
*/
module unstd.lifetime;

import unstd.array;
import unstd.traits;


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
