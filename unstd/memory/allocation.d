/** Manual memory management routines.

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
