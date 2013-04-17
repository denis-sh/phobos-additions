/** Weak reference implementation.

Copyright: Denis Shelomovskij 2013

License: $(HTTP boost.org/LICENSE_1_0.txt, Boost License 1.0).

Authors: Denis Shelomovskij
*/
module unstd.memory.weakref;


import core.stdc.stdlib;
import core.stdc.string;
import core.exception;
import core.memory;
import core.atomic;


/**
Implementats weak reference.

Tip: This behaves like C#'s short weak reference or Java's weak reference.
*/
final @trusted class WeakReference(T)
if(is(T == class) || is(T == interface) || is(T == delegate))
{
	/* Create weak reference for $(D target).

	Preconditions:
	$(D target !is null)
	*/
	this(T target)
	in { assert(target); }
	body
	{
		// FIXME: Assume `malloc` returns properly aligned memory.
		_data = cast(shared) malloc(T.sizeof);
		if(!_data)
			onOutOfMemoryError();
		*cast(T*) _data = target;
        rt_attachDisposeEvent(_targetToObj(target), &onTargetDisposed);
	}

	/// Determines whether referenced object is finalized.
	@property bool alive() const @safe
	{ return !!_data; }

	/**
	Returns referenced object if it isn't finalized
	thus creating a strong reference to it.
	Returns null otherwise.
	*/
	@property inout(T) target() inout
	{
		const data = cast(const T*) _data;
		if(!data)
			return null;
		auto object = cast(void*) _targetToObj(*data);
		GC.addRoot(object);
		scope(exit) GC.removeRoot(object);
		auto dataRes = cast(inout(T)*) _data;
		return dataRes ? *dataRes : null;
	}

	~this()
	{
		if(T t = target())
		{
			rt_detachDisposeEvent(_targetToObj(t), &onTargetDisposed);
			free(cast(void*) _data);
		}
	}

private:
	shared void* _data;

	void onTargetDisposed(Object)
	{
		auto data = cast(void*) _data;
		atomicStore(_data, cast(shared void*) null);
		free(data);
	}
}

/// Convenience function that returns a $(D WeakReference!T) object for $(D target).
@safe WeakReference!T weakReference(T)(T target)
if(is(T == class) || is(T == interface) || is(T == delegate))
{
	return new WeakReference!T(target);
}

///
unittest
{
	auto weak = weakReference(new Object());
	// ...
	if(auto obj = weak.target)
	{
		// Still alive! Let's kill it by hands.
		destroy(obj);
		assert(!weak.alive && !weak.target);
	}
}

///
unittest
{
	auto weak = weakReference(&(new Object()).toString);
	// ...
	if(auto del = weak.target)
	{
		// The  alive! Let's kill it by hands.
		assert(del() == "object.Object");
		destroy(cast(Object) del.ptr);
		assert(!weak.alive && !weak.target);
	}
}

unittest
{
	{
		auto o = new Object();
		auto w = weakReference(o);
		assert(w.alive && w.target is o);
		destroy(o);
		assert(!w.alive && !w.target);
	}

	interface I { }
	class C: I { void f() {} }
	{
		I i = new C();
		auto w = weakReference(i);
		assert(w.alive && w.target is i);
		destroy(i);
		assert(!w.alive && !w.target);
	}
	{
		auto c = new C();
		auto w = weakReference(&c.f);
		assert(w.alive && w.target is &c.f);
		destroy(c);
		assert(!w.alive && !w.target);
	}
}


private:

alias void delegate(Object) DisposeEvt;

extern(C)
{
	Object _d_toObject(void* p);
	void rt_attachDisposeEvent(Object obj, DisposeEvt evt);
	void rt_detachDisposeEvent(Object obj, DisposeEvt evt);
}

Object _targetToObj(T)(T t) if(is(T == delegate))
{ return _d_toObject(t.ptr); }

inout(Object) _targetToObj(T)(inout T t) if(is(T == class) || is(T == interface))
{ return cast(inout Object) t; }
