/** Convenient wrapper for
$(HTTP msdn.microsoft.com/en-us/library/windows/desktop/aa366711(v=vs.85).aspx,
WinAPI _heap functions).

Copyright: Denis Shelomovskij 2012-2013

License: $(HTTP boost.org/LICENSE_1_0.txt, Boost License 1.0).

Authors: Denis Shelomovskij
*/
module unstd.windows.heap;


import core.sys.windows.windows;

import unstd.windows.exception;


/// Returns default heap of the calling process.
@property Heap processHeap()
{ return Heap(enforceWinAPI!GetProcessHeap(), false); }


/**
This struct encapsulates heap manipulation functionality.

This struct is neither default constructable nor copyable.
Pass it by $(D ref) to functions or use $(STDREF typecons, RefCounted).
*/
struct Heap
{
	/// Heap construction options.
	enum CreateOptions: DWORD
	{
		no = 0, /// No flags.
		createEnableExecute = HEAP_CREATE_ENABLE_EXECUTE, /// Add $(D HEAP_CREATE_ENABLE_EXECUTE) flag.
		generateExceptions = HEAP_GENERATE_EXCEPTIONS, /// Add $(D HEAP_GENERATE_EXCEPTIONS) flag.
		noSerialize = HEAP_NO_SERIALIZE, /// Add $(D HEAP_NO_SERIALIZE) flag.
	}

	/// General heap usage flags.
	enum Flags: DWORD
	{
		no = 0, /// No flags.
		generateExceptions = HEAP_GENERATE_EXCEPTIONS, /// Add $(D HEAP_GENERATE_EXCEPTIONS) flag.
		noSerialize = HEAP_NO_SERIALIZE, /// Add $(D HEAP_NO_SERIALIZE) flag.
	}

	private
	{
		HANDLE _handle = null;
		bool _own = false;
	}

	@disable this();
	@disable this(this);


	/**
	Construct a new $(D Heap).

	Wrapper for
	$(HTTP msdn.microsoft.com/en-us/library/windows/desktop/aa366599(v=vs.85).aspx, HeapCreate).

	Throws:
	$(D WinAPIException) if heap creation failed.
	*/
	this(CreateOptions options, size_t initialSize = 0, size_t maximumSize = 0)
	in { assert(!maximumSize || initialSize < maximumSize); }
	out { assert(associated); }
	body
	{
		_handle = enforceWinAPI!HeapCreate(options, initialSize, maximumSize);
		_own = true;
	}

	/**
	Construct a $(D Heap) from a $(D heapHandle).

	If $(D own) is true destroys the $(D heapHandle) on destruction
	using $(HTTP msdn.microsoft.com/en-us/library/windows/desktop/aa366700(v=vs.85).aspx, HeapDestroy).
	*/
	this(HANDLE heapHandle, bool own = true) @safe pure nothrow
	out { assert(associated); }
	body
	{
		_handle = heapHandle;
		_own = own;
	}

	~this()
	{
		if(!_own)
			return;
		assert(_handle);
		assert(_handle != enforceWinAPI!GetProcessHeap());
		enforceWinAPI!HeapDestroy(_handle);
	}


	/** Returns whether $(D this) is _associated with a heap handle.
	It is asserted that no member functions are called for an unassociated
	$(D Heap) struct.

	Examples:
	---
	assert(processHeap.associated);
	assert(!Heap.init.associated);
	auto h = Heap.init.handle; // assertion failure
	---
	*/
	@property bool associated() const @safe pure nothrow
	{ return !!_handle; }

	unittest
	{
		static assert(!Heap.init.associated);
		assert(processHeap.associated);
	}


	/// Gets the _handle of the associated heap.
	@property HANDLE handle() @safe pure nothrow
	in { assert(associated); }
	body { return _handle; }

	/// Returns whether handle of the associated heap will be destroyed on destruction.
	@property bool ownHandle() const @safe pure nothrow
	in { assert(associated); }
	body { return _own; }


	/** Allocates a block of memory.

	Wrapper for
	$(HTTP msdn.microsoft.com/en-us/library/windows/desktop/aa366597(v=vs.85).aspx, HeapAlloc).
	*/
	void* alloc(size_t bytes, bool zeroMemory = false, Flags flags = Flags.no) nothrow
	in { assert(associated); }
	body
	{
		if(zeroMemory)
			flags |= HEAP_ZERO_MEMORY;
		return HeapAlloc(_handle, flags, bytes);
	}


	/** Reallocates a block of memory (i.e. memory content is preserved).

	Wrapper for
	$(HTTP msdn.microsoft.com/en-us/library/windows/desktop/aa366704(v=vs.85).aspx, HeapReAlloc).
	*/
	void* reAlloc(void* ptr, size_t bytes, bool zeroMemory = false, bool inPlaceOnly = false, Flags flags = Flags.no) nothrow
	in { assert(associated); }
	body
	{
		if(zeroMemory)
			flags |= HEAP_ZERO_MEMORY;
		if(inPlaceOnly)
			flags |= HEAP_REALLOC_IN_PLACE_ONLY;
		return HeapReAlloc(_handle, flags, ptr, bytes);
	}


	/** Frees a block of memory.

	Wrapper for
	$(HTTP msdn.microsoft.com/en-us/library/windows/desktop/aa366701(v=vs.85).aspx, HeapFree).
	Also fixes $(D HeapFree) bug, see "Community Additions" section of function page.

	Throws:
	$(D WinAPIException) if memory freeing failed.
	*/
	void free(void* p, Flags flags = Flags.no)
	in { assert(associated); }
	body
	{
		BOOL res = HeapFree(_handle, flags, p);
		// Workaround bug mentioned in "Community Additions" section:
		if(cast(ubyte) GetVersion() < 6) // Not Windows Vista or later
			res = cast(ubyte) res;
		if(!res)
			throw new WinAPIException("HeapFree");
	}


	/** Retrieves the _size of an allocated from this heap memory block.

	Wrapper for
	$(HTTP msdn.microsoft.com/en-us/library/windows/desktop/aa366706(v=vs.85).aspx, HeapSize).

	Throws:
	$(D WinAPIException) if getting _size failed.
	*/
	size_t size(void* p, Flags flags = Flags.no)
	in { assert(associated); }
	body
	{
		SIZE_T res = HeapSize(_handle, flags, p);
		if(res == -1)
			throw new WinAPIException("HeapSize");
		return res;
	}
}

unittest
{
	assert(!processHeap.ownHandle);
	void* ptr = processHeap.alloc(1);
	assert(ptr);
	assert(processHeap.size(ptr) == 1);
	processHeap.free(ptr);
}

unittest
{
	auto heap = Heap(Heap.CreateOptions.noSerialize | Heap.CreateOptions.generateExceptions);
	assert(heap.ownHandle);
	void* ptr = heap.alloc(3);
	assert(ptr);
	assert(heap.size(ptr) == 3);
	ptr = heap.reAlloc(ptr, 4);
	assert(ptr);
	assert(heap.size(ptr) == 4);
	heap.free(ptr);
}


/**
An unaligned thread local allocator interface implementation for $(MREF Heap).

Can be constructed using the same arguments as $(D Heap).

Underlying $(D Heap) can be accessed via $(D heap) property.

See also $(DPREF2 memory, allocation, isUnalignedAllocator).
*/
struct HeapAllocator
{
	private Heap _heap;

	@disable this();
	@disable this(this);

	this(Heap.CreateOptions options, size_t initialSize = 0, size_t maximumSize = 0)
	{ _heap = Heap(options, initialSize, maximumSize); }

	this(HANDLE heapHandle, bool own = true)
	{ _heap = Heap(heapHandle, own); }

	@property ref inout(Heap) heap() inout
	{ return _heap; }

	void* tryUnalignedAllocate(size_t count) nothrow
	{ return _heap.alloc(count); }

	void* tryUnalignedReallocate(void* ptr, size_t preserveCount, size_t count) nothrow
	{ return _heap.reAlloc(ptr, count); }

	void unalignedFree(void* ptr)
	{ _heap.free(ptr); }
}


// WinAPI functions/manifest constants.
// ----------------------------------------------------------------------------------------------------

enum : DWORD
{
	HEAP_NO_SERIALIZE              = 0x00000001,
	HEAP_GENERATE_EXCEPTIONS       = 0x00000004,
	HEAP_ZERO_MEMORY               = 0x00000008,
	HEAP_REALLOC_IN_PLACE_ONLY     = 0x00000010,
	HEAP_CREATE_ENABLE_EXECUTE     = 0x00040000,
}

extern(Windows) nothrow extern
{
	HANDLE GetProcessHeap();
	HANDLE HeapCreate(DWORD flOptions, SIZE_T dwInitialSize, SIZE_T dwMaximumSize);
	BOOL HeapDestroy(HANDLE hHeap);
	PVOID HeapAlloc(HANDLE hHeap, DWORD dwFlags, SIZE_T dwBytes);
	PVOID HeapReAlloc(HANDLE hHeap, DWORD dwFlags, LPVOID lpMem, SIZE_T dwBytes);
	BOOL HeapFree(HANDLE hHeap, DWORD dwFlags, LPVOID lpMem);
	SIZE_T HeapSize(HANDLE hHeap, DWORD dwFlags, LPCVOID lpMem);
}
