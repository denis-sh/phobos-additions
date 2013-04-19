/** Weak reference implementation.

Copyright: Denis Shelomovskij 2013

License: $(HTTP boost.org/LICENSE_1_0.txt, Boost License 1.0).

Authors: Denis Shelomovskij
*/
module unstd.memory.weakref;


import core.exception;
import core.memory;
import core.atomic;

import unstd.array;
import unstd.memory.allocation;


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
		_data = cast(shared void*) cHeap.allocate!T(1, false).ptr;
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
			cHeap.rawFree(cast(void*) _data);
		}
	}

private:
	shared void* _data;

	void onTargetDisposed(Object)
	{
		auto data = cast(void*) _data;
		atomicStore(_data, cast(shared void*) null);
		cHeap.rawFree(data);
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

/**
Implementats weak reference array.

It gives better performance when working with
multiple weak references at once.
*/
final @trusted class WeakReferenceArray(T)
if(is(T == class) || is(T == interface) || is(T == delegate))
{
	/**
	Create weak reference array with initial capacity $(D initialCapacity).

	Preconditions:
	$(D initialCapacity != 0)
	*/
	this(size_t initialCapacity)
	in { assert(initialCapacity); }
	body
	{
		_data = cast(shared(void*)*) cHeap.allocate!T(initialCapacity, false).ptr;
		_capacity = initialCapacity;
	}

	/// Total count of (possibly dead) weak references.
	@property size_t count() const @safe
	{ return _count; }

	/// Total count of alive weak references.
	@property size_t aliveCount() const @safe
	{ return _aliveCount; }

	/// Returns the capacity of the array.
	@property size_t capacity() const @safe
	{ return _capacity; }

	/**
	Determines whether array behaves as a hard reference.
	$(D false) by default.
	*/
	@property bool hard() const
	{ return _hard; }

	/**
	Return array internal buffer which can be safely used while
	the array behaves as a hard reference.
	
	Note:
	Retrieved buffer may become invalid after addition of an object
	into the array if $(D capacity == 0) or after $(D reserve) or
	$(D removeDead) call.

	Preconditions:
	$(D hard)
	*/
	@property inout(T)[] buff() inout
	in { assert(hard); }
	body
	{ return (cast(inout T*) _data)[0 .. _count]; }

	/**
	Appends new weak reference to $(D target) to the array.

	Preconditions:
	There is no
	*/
	void opOpAssign(string op : "~")(T target)
	{
		if(_count == _capacity)
		{
			if(_capacity * 2 < _capacity)
				onOutOfMemoryError();
			reserve(_capacity * 2);
		}
		(cast(T*) _data)[_count++] = target;
		atomicOp!`+=`(_aliveCount, 1);
		rt_attachDisposeEvent(_targetToObj(target), &onTargetDisposed);
	}

	/**
	Returns $(D i)-th referenced object if it isn't finalized
	thus creating a strong reference to it.
	Returns null otherwise.
	*/
	inout(T) opIndex(size_t i) inout
	{
		version(D_NoBoundsChecks) { }
		else if(i >= _count)
			onRangeError();

		if(_hard)
			return (cast(inout(T)*) _data)[i];

		const data = cast(const T*) _data + i;
		if(!data)
			return null;
		auto object = cast(void*) _targetToObj(*data);
		GC.addRoot(object);
		scope(exit) GC.removeRoot(object);
		auto dataRes = cast(inout(T)*) _data + i;
		return dataRes ? *dataRes : null;
	}

	/// Changes $(D i)-th referenced object.
	void opIndexAssign(T target, size_t i)
	{
		version(D_NoBoundsChecks) { }
		else if(i >= _count)
			onRangeError();

		const wasHard = hard;
		if(!wasHard) makeHard();

		auto ptr = cast(T*) _data;
		auto prevObject = ptr[i] ? _targetToObj(ptr[i]) : null;
		auto object = target ? _targetToObj(target) : null;
		ptr[i] = target;
		if(prevObject is object)
			return;

		if(!prevObject || !object)
			_aliveCount += object ? 1 : -1;

		bool foundPrev = !prevObject;
		foreach(j, t; buff) if(j != i)
		{
			foundPrev |= _targetToObj(t) is prevObject;
			if(foundPrev)
				break;
		}
		if(!foundPrev)
			rt_detachDisposeEvent(prevObject, &onTargetDisposed);
		if(object)
			rt_attachDisposeEvent(object, &onTargetDisposed);

		if(!wasHard) makeWeak();
	}

	/// Reserve at least $(D newCapacity) elements for appending.
	void reserve(size_t newCapacity)
	{
		const wasHard = hard;
		if(!wasHard) makeHard();

		_capacity = newCapacity;
		T[] arr = buff;
		cHeap.reallocate(arr, _capacity, false);
		_data = cast(shared(void*)*) arr.ptr;

		if(!wasHard) makeWeak();
	}

	/// Remove dead weak references from the array. This may decrease $(D count).
	void removeDead()
	{
		const wasHard = hard;
		if(!wasHard) makeHard();

		auto x = buff;
		auto ptr = cast(T*) _data;
		for(size_t i = 0; i < count; )
		{
			if(!ptr[i])
				rawCopy!T(ptr + i + 1, ptr + i, --_count - i);
			else
				++i;
		}

		if(!wasHard) makeWeak();
	}

	/// Force the array to behave as a weak reference.
	void makeWeak()
	{
		if(!_hard)
			return;
		_hard = false;
		GC.removeRange(cast(void*) _data);
	}

	/// Force the array to behave as a hard reference.
	void makeHard()
	{
		if(_hard)
			return;
		_hard = true;
		GC.addRange(cast(void*) _data, T.sizeof * _count);
	}

	~this()
	{
		makeHard();

		foreach(t; buff) if(t)
			rt_detachDisposeEvent(_targetToObj(t), &onTargetDisposed);

		cHeap.rawFree(cast(void*) _data);
	}

private:
	size_t _capacity, _count = 0;
	bool _hard = false;
	shared size_t _aliveCount = 0;
	shared(void*)* _data;

	void onTargetDisposed(Object obj)
	{
		auto buff = (cast(T*) _data)[0 .. _count];
		version(assert) size_t count = 0;
		foreach(ref t; buff) if(_targetToObj(t) is obj)
		{
			atomicOp!`-=`(_aliveCount, 1);
			t = null;
			version(assert) ++count;
		}
		assert(count);
	}
}


/**
Convenience function that returns a $(D WeakReferenceArray!T)
with initial capacity $(D initialCapacity).
*/
@safe WeakReferenceArray!T weakReferenceArray(T)(size_t initialCapacity = 64)
if(is(T == class) || is(T == interface) || is(T == delegate))
{
	return new WeakReferenceArray!T(initialCapacity);
}

unittest
{
	{
		auto o = new Object();
		auto w = weakReferenceArray!Object(1);
		w ~= o;
		assert(w.aliveCount == 1 && w[0] is o);
		destroy(o);
		assert(!w.aliveCount && !w[0]);

		auto o1 = new Object(), o2 = new Object(), o3 = new Object();
		w ~= o1;
		w ~= o2;
		w ~= o3;
		assert(!w.hard && w.aliveCount == 3 && w[1] is o1 && w[2] is o2 && w[3] is o3);
		w.makeHard();
		assert(w.hard && w.aliveCount == 3 && w.buff == [null, o1, o2, o3]);
		destroy(o2);
		assert(w.aliveCount == 2 && w.buff == [null, o1, null, o3]);
		w.removeDead();
		assert(w.aliveCount == 2 && w.buff == [o1, o3]);
		w.makeWeak();
		assert(!w.hard);
		destroy(o1);
		destroy(o3);
		assert(!w.aliveCount);
		assert(w.count == 2);
		w.removeDead();
		assert(!w.count);
	}

	{
		auto o = new Object(), o1 = new Object(), o2 = new Object();
		auto w = weakReferenceArray!Object(1);
		w ~= o;
		w ~= o1;
		w[0] = o2;
		assert(w.aliveCount == 2 && w[0] is o2 && w[1] is o1);
		destroy(o);
		assert(w.aliveCount == 2 && w[0] is o2 && w[1] is o1);
		destroy(o2);
		assert(w.aliveCount == 1 && !w[0] && w[1] is o1);
		w[0] = o1;
		assert(w.aliveCount == 2 && w[0] is o1 && w[1] is o1);
		destroy(o1);
		assert(w.aliveCount == 0 && !w[0] && !w[1]);
	}

	interface I { }
	class C: I { void f() {} void f1() {} }
	{
		I i = new C(), i1 = new C();
		auto w = weakReferenceArray!I(1);
		w ~= i;
		w ~= i;
		w ~= i;
		w ~= i1;
		assert(w.aliveCount == 4 && w[0] is i && w[1] is i && w[2] is i && w[3] is i1);
		destroy(i);
		assert(w.aliveCount == 1 && !w[0] && !w[1] && !w[2] && w[3] is i1);
		destroy(i1);
		assert(!w.aliveCount && !w[0] && !w[1] && !w[2] && !w[3]);
	}
	{
		auto c = new C(), c1 = new C();
		auto w = weakReferenceArray!(void delegate())(1);
		w ~= &c.f;
		w ~= &c1.f;
		w ~= &c.f1;
		assert(w.aliveCount == 3 && w[0] is &c.f && w[1] is &c1.f && w[2] is &c.f1);
		destroy(c1);
		assert(w.aliveCount == 2 && w[0] is &c.f && !w[1] && w[2] is &c.f1);
		destroy(c);
		assert(!w.aliveCount && !w[0] && !w[1] && !w[2]);
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
