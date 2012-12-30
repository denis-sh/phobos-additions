/** Functions for user-defined _lifetime implementation.

Copyright: Denis Shelomovskij 2012

License: $(HTTP boost.org/LICENSE_1_0.txt, Boost License 1.0).

Authors: Denis Shelomovskij
*/
module unstd.lifetime;


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
