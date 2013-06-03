/**
Miscellaneous memory routines.

Copyright: Denis Shelomovskij 2013

License: $(HTTP boost.org/LICENSE_1_0.txt, Boost License 1.0).

Authors: Denis Shelomovskij
*/
module unstd.memory.misc;


import core.stdc.string;

import unstd.array;
import unstd.math;


/**
This struct provides a static buffer of maximum size $(D maxBytes) which is
aligned as requested by $(D alignment).

The whole struct may be misaligned and moved in memory.
*/
struct RawAutoalignedBuff(size_t alignment, size_t maxBytes)
{
	private
	{
		version(assert) enum _debug = true, _stamp = 0x90EA7FB;
		else enum _debug = false;

		void[alignUp!alignment(maxBytes + size_t.sizeof * (2 + _debug)) + alignment] _data = void;
	}

	/**
	Initializes the struct.

	$(D bytes) specifies buffer size.

	If $(D zeroFill) is true the memory will be zero-filled.

	Preconditions:
	$(D bytes <= maxBytes)
	*/
	void initialize(size_t bytes = maxBytes, bool zeroFill = true)
	in { assert(bytes <= maxBytes); }
	body
	{
		version(assert) *cast(size_t*) &_data[$ - size_t.sizeof * 3] = _stamp;
		*cast(size_t*) &_data[$ - size_t.sizeof * 2] = -1;
		*cast(size_t*) &_data[$ - size_t.sizeof] = bytes;
		if(zeroFill)
			memset(_data.ptr, 0, bytes + alignment - 1);
	}

	/**
	Returnes the buffer. Moves the buffer in memory if it is misaligned.

	Preconditions:
	$(D RawAutoalignedBuff) is initialized.
	*/
	@property void[] buff()
	in
	{
		version(assert) assert(*cast(size_t*) &_data[$ - size_t.sizeof * 3] == _stamp,
			RawAutoalignedBuff.stringof ~ " is uninitialized. You have to call `initialize` before retrieving the buffer.");
	}
	out(res)
	{ assert(isAligned!alignment(cast(size_t) res.ptr)); }
	body
	{
		void* alignedPtr = cast(void*) alignUp!alignment(cast(size_t) _data.ptr);
		size_t* dPtr = cast(size_t*) &_data[$ - size_t.sizeof * 2];
		const size_t bytes = *cast(size_t*) &_data[$ - size_t.sizeof];
		const size_t d = alignedPtr - _data.ptr, prevD = *dPtr;
		if(prevD != d)
		{
			if(prevD != -1)
				rawCopy(_data.ptr + prevD, alignedPtr, bytes);
			*dPtr = d;
		}
		return alignedPtr[0 .. bytes];
	}

	alias buff this;
}

///
unittest
{
	import unstd.math;

	alias Buff = RawAutoalignedBuff!(64, 16);

	void[1024] sbuff = void;
	auto mbuff = cast(Buff*) sbuff.ptr;
	mbuff.initialize();

	assert(isAligned!64(cast(size_t) mbuff.buff.ptr));
	assert(mbuff.buff == [0, 0, 0, 0]);
	mbuff.buff[] = [1, 2, 3, 4];

	rawCopy(sbuff.ptr, sbuff.ptr + 1, Buff.sizeof);
	mbuff = cast(Buff*) (sbuff.ptr + 1);

	assert(isAligned!64(cast(size_t) mbuff.buff.ptr)); 
	assert(mbuff.buff == [1, 2, 3, 4]);
}

unittest
{
	import unstd.generictuple;

	void[1024] sbuff = void;

	foreach(alignment; expressionTuple!(1, 2, 4, 16, 64))
	{
		alias Buff = RawAutoalignedBuff!(alignment, 8);
		static assert(Buff.sizeof % alignment == 0);

		foreach(i; 0 .. alignment + 1)
		{
			void* ptr = sbuff.ptr + i;
			auto mbuff = cast(Buff*) ptr;
			mbuff.initialize(8);
			void[] buff = mbuff.buff;

			immutable data = [0xABCDEF01, 0x12345678];
			buff[] = (cast(void[]) data)[];
			foreach(d; 1 .. alignment + 1)
			{
				void* newPtr = ptr + d;
				rawCopy(ptr, newPtr, Buff.sizeof);
				assert((cast(Buff*) newPtr).buff == data);
				rawCopy(newPtr, ptr, Buff.sizeof);
				assert(mbuff.buff == data);
			}
		}
	}
}
