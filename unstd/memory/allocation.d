/** Manual memory management routines.

Warning:
$(RED Never use functions like $(D malloc) directly) unless you know
what you are doing as unaligned memory which it returns may lead
to random crashed, incorrect behaviour and/or performance reduction.

Also $(RED manual) $(I count) * $(I element size) $(RED multiplication often
leads to buffer overflow vulnerability) as one forgets the check.

Copyright: Denis Shelomovskij 2013

License: $(HTTP boost.org/LICENSE_1_0.txt, Boost License 1.0).

Authors: Denis Shelomovskij

Macros:
COREREF = $(HTTP dlang.org/phobos/core_$1.html#$2, $(D core.$1.$2))
*/
module unstd.memory.allocation;


import core.stdc.stdlib;
import core.stdc.string;
import core.exception;

import unstd.math;
import unstd.lifetime;


/**
Returns $(D true) if $(D A) is an unaligned allocator.

The following code should compile for any unaligned allocator.

----
A a = void;
auto p = a.tryUnalignedAllocate(cast(size_t) 1);
a.unalignedFree(p);
static assert(is(typeof(p) == void*));
----
*/
template isUnalignedAllocator(A)
{
	enum bool isUnalignedAllocator = __traits(compiles,
	{
		A a = void;
		auto p = a.tryUnalignedAllocate(cast(size_t) 1);
		a.unalignedFree(p);
		static assert(is(typeof(p) == void*));
	});
}

version(unittest) private struct _DummyUnalignedAllocator
{
	void* tryUnalignedAllocate(size_t count)
	{ return null; }

	void unalignedFree(void* ptr)
	{ }
}

unittest
{
	static assert(!isUnalignedAllocator!int);
	static assert( isUnalignedAllocator!_DummyUnalignedAllocator);
}


/**
Requests a properly aligned block of memory of $(D count * T.sizeof)
bytes from $(D allocator).

If $(D initialize) is true the returned memory will be set to $(D T.init).

If allocation fails allocate will also call $(COREREF exception, onOutOfMemoryError)
which is expected to throw an $(COREREF exception, OutOfMemoryError).

Preconditions:
$(D count != 0)

Returns:
Allocated array or null if allocaton failed.
*/
T[] allocate(T, A)(ref A allocator, size_t count, bool initialize = true)
if(isUnalignedAllocator!A)
{
	T[] arr = allocator.tryAllocate!T(count, initialize);
	if(!arr)
		onOutOfMemoryError();
	return arr;
}

/// ditto
T[] tryAllocate(T, A)(ref A allocator, size_t count, bool initialize = true)
if(isUnalignedAllocator!A)
in { assert(count); }
body
{
	void* ptr = allocator.tryRawAllocate(T.alignof, T.sizeof, count, false);
	if(!ptr)
		return null;
	T[] arr = (cast(T*) ptr)[0 .. count];
	if(initialize)
		setElementsToInitialState(arr);
	return arr;
}

/**
Deallocates the memory referenced by $(D arr.ptr) from $(D allocator)
and sets $(D arr) to null.

If $(D arr.ptr) is null, no action occurs.
*/
void free(T, A)(ref A allocator, ref T[] arr)
if(isUnalignedAllocator!A)
{
	if(arr.ptr)
	{
		allocator.rawFree(arr.ptr);
		arr = null;
	}
}

unittest
{
	_DummyUnalignedAllocator a;
	int[] arr = a.tryAllocate!int(1);
	assert(!arr);
	arr = a.tryAllocate!int(1, false);
	assert(!arr);
	a.free(arr);
}


/**
Requests an $(D alignment)-byte aligned block of memory of $(D count * elementSize)
bytes from $(D allocator).

If $(D zeroFill) is true the returned memory will be zero-filled.

If allocation fails rawAllocate will also call $(COREREF exception, onOutOfMemoryError)
which is expected to throw an $(COREREF exception, OutOfMemoryError).

Preconditions:
$(D alignment != 0 && elementSize % alignment == 0 && count != 0)

Returns:
A pointer to the allocated memory or null if allocaton failed.
*/
void* rawAllocate(A)(ref A allocator, size_t alignment, size_t elementSize, size_t count, bool zeroFill = true)
if(isUnalignedAllocator!A)
{
	void* ptr = allocator.tryRawAllocate(alignment, elementSize, count, zeroFill);
	if(!ptr)
		onOutOfMemoryError();
	return ptr;
}

/// ditto
void* tryRawAllocate(A)(ref A allocator, size_t alignment, size_t elementSize, size_t count, bool zeroFill = true)
if(isUnalignedAllocator!A)
in { assert(alignment && elementSize % alignment == 0 && count); }
body
{
	if(auto buffBytes = memoryMult(elementSize, count))
		if(auto totalBytes = memoryAdd(buffBytes, alignmentMemoryPadding(alignment)))
			if(void* p = allocator.tryUnalignedAllocate(totalBytes))
			{
				p = alignMemory(alignment, p);
				if(zeroFill)
					memset(p, 0, buffBytes);
				return p;
			}
	return null;
}

/**
Deallocates the memory referenced by $(D ptr) from $(D allocator).

If $(D ptr) is null, no action occurs.
*/
void rawFree(A)(ref A allocator, void* ptr)
if(isUnalignedAllocator!A)
{
	if(ptr)
		allocator.unalignedFree(dealignMemory(ptr));
}

unittest
{
	_DummyUnalignedAllocator a;
	void* p = a.tryRawAllocate(4, 4, 1);
	assert(!p);
	p = a.tryRawAllocate(4, 4, 1, false);
	assert(!p);
	a.rawFree(p);
}


struct CHeap
{
	@disable this();
	@disable this(this);

static nothrow:
	// Allocate memory with C's `malloc`.
	void* tryUnalignedAllocate(size_t count)
	in { assert(count); }
	body
	{ return malloc(count); }

	// Free memory with C's `free`.
	void unalignedFree(void* ptr)
	in { assert(ptr); }
	body
	{ core.stdc.stdlib.free(ptr); }
}

__gshared CHeap _cHeap = void;

/// An unaligned allocator which uses C's $(D malloc)/$(D free).
@property ref CHeap cHeap() nothrow
{ return _cHeap; }

///
unittest
{
	static assert(isUnalignedAllocator!(typeof(cHeap)));

	auto longs = cHeap.allocate!long(3, false);
	assert(longs.length == 3);
	cHeap.free(longs);
	assert(!longs);

	assert(!cHeap.tryAllocate!ubyte(size_t.max));
}

///
unittest
{
	auto chars = cHeap.allocate!char(2);
	scope(exit) cHeap.free(chars);
	assert(chars == [char.init, char.init]);
}


private:

// Helper functions for memory alignment.
// Note: maximum allowed alignment is 256.
// ----------------------------------------------------------------------------------------------------

size_t alignmentMemoryPadding(size_t alignment) pure @safe
{ return alignment; }

void* alignMemory(size_t alignment, void* unalignedPtr) pure
in { assert(unalignedPtr && alignment && alignment <= ubyte.max + 1); }
out(res) { assert(dealignMemory(res) == unalignedPtr); }
body
{
	void* ptr = cast(void*) alignUp(alignment, cast(size_t) unalignedPtr);
	if(ptr == unalignedPtr)
		ptr += alignment;

	(cast(ubyte*) ptr)[-1] = cast(ubyte)(ptr - unalignedPtr - 1);
	return ptr;
}

inout(void)* dealignMemory(inout void* alignedPtr) pure
in { assert(alignedPtr); }
body
{
	const d = (cast(ubyte*) alignedPtr)[-1] + 1;
	return alignedPtr - d;
}

unittest
{
	void[alignmentMemoryPadding(256)] buff = void;
	foreach(alignment; [1, 4, 16, 64, 128, 256])
		assert(alignMemory(alignment, buff.ptr) != buff.ptr);
}


// Helper functions for memory amound manipulation.
// ----------------------------------------------------------------------------------------------------

size_t memoryAdd(size_t bytes1, size_t bytes2)
in { assert(bytes1 || bytes2); }
body
{
	const size_t bytes = bytes1 + bytes2;
	if(bytes < bytes1)
		return 0;
	return bytes;
}

size_t memoryMult(size_t elementSize, size_t count)
in { assert(elementSize && count); }
body
{
	const size_t bytes = elementSize * count;
	if(bytes / elementSize != count)
		return 0;
	return bytes;
}

unittest
{
	assert( memoryAdd(3, 4) == 7);
	assert( memoryAdd(1, 0) == 1);
	assert( memoryAdd(2, -3) == size_t.max);
	assert(!memoryAdd(3, -1));
	assert( memoryMult(3, 4) == 12);
	assert( memoryMult(3, 1) == 3);
	assert( memoryMult(1, -1) == size_t.max);
	assert(!memoryMult(3, -1));
}
