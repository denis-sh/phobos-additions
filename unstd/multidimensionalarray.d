/**
Functions and types that manipulate multidimensional rectangular arrays.

Copyright: Denis Shelomovskij 2011-2013

License: $(HTTP boost.org/LICENSE_1_0.txt, Boost License 1.0).

Authors: Denis Shelomovskij

Macros:
	TR = <tr>$0</tr>
	TH = <th>$0</th>
	TD = <td>$0</td>
	TABLE = <table border=1 cellpadding=4 cellspacing=0>$0</table>
 */
module unstd.multidimensionalarray;

import core.exception;
import std.exception;
import std.array;
import unstd.traits;
import unstd.generictuple; //for RepeatType
import std.typecons;
import std.conv;
import std.string;
import std.range;
import std.algorithm;


struct AllR { }

struct R_
{
	size_t from, to;

	@disable this();

	static AllR opSlice()
	{
		return AllR();
	}

	static R_ opSlice(size_t from, size_t to)
	{
		R_ r = void;
		r.from = from, r.to = to;
		return r;
	}
}

enum R = R_.init;

private template RCount(T...)
{
	static if(T.length)
		enum RCount = (is(Unqual!(T[0]) == R_) || is(Unqual!(T[0]) == AllR)) + RCount!(T[1 .. $]);
	else
		enum RCount = 0u;
}

private template isROrSize(T)
{
	enum isROrSize = RCount!T || isImplicitlyConvertible!(T, const(size_t));
}

/**
Implements multidimensional rectangular arrays.

Something like FORTRAN's one.

Example:
----
// Let's creates an GC allocated three-dimensional rectangular array from 2 matrices 3x4
auto matrices = mdimArray!int(2, 3, 4); //matrices has a type MultidimensionalArray!(int, 3)

// Initializing the array
matrices[] = 5;

// Iterating the array
foreach(z, y, x, ref el; matrices) // using opApply
	el = z * 100 + y * 10 + x;

int c = 0;
foreach(ref el; matrices.byElementForward)
	el = c++;

c = 0;
foreach(i; 0 .. matrices.elements)
	matrices.byElementRandomAccess[i] = c++;

c = 0;
foreach(matrix; matrices.byTopDimension)       // for each of two matrices
	foreach(row; matrix.byTopDimension)        // for each row
		foreach(ref el; matrix.byTopDimension) // for each element
			el = c++;

c = 0;
foreach_reverse(ref el; matrices.byElementRandomAccess)
	el = c++;

c = 0;
foreach_reverse(i; 0 .. matrices.elements)
	matrices.byElementRandomAccess[i] = c++;

// Inexing/slicing
// * use <integer> to select a position
// * use R[<integer> .. <integer>] to select a range
// * use R[]  to select the whole range
matrices = matrices[R[], R[], R[]]);  // the entire array, same as [R[0..2], R[0..3], R[0..4]]
auto array2d = matrices[0, R[], R[]]); // the first matrix
auto array1d = matrices[0, 1, R[]]);  // the second row of the first matrix
array1d = matrices[0, R[], 1]);       // the second column of the first matrix
matrices[0, 1, 1] = 9;                // setting an element at a crossing of the row an the column

// first two rows and three columns of the secon matrix
array2d = matrices[1, R[0 .. 2], R[0 .. 3]]);
----
*/
struct MultidimensionalArray(T, size_t n) if(n >= 1)
{
	/// Dimentions of this array.
	alias n dimentions;

	static if(n == 1)
		alias TypeTuple!(size_t) SizeTypes;
	else
		alias TypeTuple!(size_t, MultidimensionalArray!(T, n-1).SizeTypes) SizeTypes;

	this(in size_t[n] p_lengths...)
	{
		this.p_lengths = p_lengths;
		strides[$-1] = 1;
		static if(n > 1)
		{
			strides[$-2] = p_lengths[$-1];
			foreach_reverse(i; iotaTuple!(n-2))
				strides[i] = p_lengths[i+1] * strides[i+1];
		}
		data = new T[strides[0] * p_lengths[0]];
	}

	this(T[] data, in size_t[n] p_lengths...)
	{
		this.p_lengths = p_lengths;
		strides[$-1] = 1;
		foreach_reverse(i; iotaTuple!(n-1))
			strides[i] = p_lengths[i+1] * strides[i+1];
		debug
		{
			immutable expectedLength = strides[0] * p_lengths[0];
			enforce(data.length == expectedLength, format("data length (%s) does't match the expected length (%s) for creating an MultidimensionalArray", data.length, expectedLength));
		}
		this.data = data;
	}

	/// Returns the read only view at its lengths array.
	@property ref const(size_t)[n] lengths() const
	{
		return p_lengths;
	}

	/// Returns the elements count of the array.
	@property size_t elements() const
	{
		size_t res = p_lengths[0];
		foreach(i; iotaTuple!(n-1))
			res *= p_lengths[i + 1];
		return res;
	}

	/**
	Returns the maximum number of tail dimensions without pading. Note, that there can be no
	such dimensions.
	*/
	@property size_t packedDimensions() const
	{
		static if(n > 1)
		{
			size_t packedStride = 1;
			foreach_reverse(i; iotaTuple!n)
			{
				static if(i < n-1)
					packedStride *= p_lengths[i+1];
				assert(strides[i] >= packedStride);
				if(strides[i] > packedStride)
					return n - i - 1;
			}
		}
		return n;
	}

	/// Returns a forward range which has mutable elements and a length for iteration by an element.
	@property byElementForward()
	{
		static struct Result
		{
			private MultidimensionalArray e; //entity
			private size_t rest, shift;
			private size_t[n] indices;

			@property bool empty() const
			{
				return !rest;
			}

			@property ref front()
			{
				assert(!empty, "Trying to call front() on an empty MultidimensionalArray.byElementForward");
				return e.data[shift];
			}

			void popFront()
			{
				assert(!empty, "Trying to call popFront() on an empty MultidimensionalArray.byElementForward");
				--rest;
				foreach_reverse(i; iotaTuple!n)
				{
					shift += e.strides[i];
					if(++indices[i] < e.p_lengths[i])
						break;
					else
					{
						assert(i || !rest);
						shift -= indices[i] * e.strides[i];
						indices[i] = 0;
					}
				}
			}

			@property save()
			{
				return this;
			}

			@property size_t length() const
			{
				return rest;
			}
		}
		return Result(this, elements, 0);
	}

	/// Returns a finite random-access range which has mutable elements and a length for iteration by an element.
	@property byElementRandomAccess()
	{
		static struct Result
		{
			private MultidimensionalArray e; //entity
			private size_t frontIndex, rest, frontShift, backShift;
			private size_t[n] frontIndices, afterBackIndices;

			@property bool empty() const
			{
				return !rest;
			}

			@property ref front()
			{
				assert(!empty, "Trying to call front() on an empty MultidimensionalArray.byElementRandomAccess");
				return e.data[frontShift];
			}

			@property ref back()
			{
				assert(!empty, "Trying to call back() on an empty MultidimensionalArray.byElementRandomAccess");
				return e.data[backShift];
			}

			@property ref opIndex(size_t i) {
				assert(!empty, format("Trying to call opIndex(%s) on an empty MultidimensionalArray.byElementRandomAccess", i));
				assert(i < length, format("Index is out of bounds: trying to call opIndex(%s) on an MultidimensionalArray.byElementRandomAccess with a length = %s", i, length));

				i += frontIndex;
				size_t shift;
				foreach_reverse(j; iotaTuple!n)
				{
					//TODO: do % and / in one operation
					immutable size_t currIndex = i % e.p_lengths[j];
					i /= e.p_lengths[j];
					shift += currIndex * e.strides[j];
				}

				return e.data[shift];
			}

			void popFront()
			{
				assert(!empty, "Trying to call popFront() on an empty MultidimensionalArray.byElementRandomAccess");
				++frontIndex;
				--rest;
				foreach_reverse(i; iotaTuple!n)
				{
					frontShift += e.strides[i];
					if(++frontIndices[i] < e.p_lengths[i])
						break;
					else
					{
						assert(i || !rest);
						frontShift -= frontIndices[i] * e.strides[i];
						frontIndices[i] = 0;
					}
				}
			}

			void popBack()
			{
				assert(!empty, "Trying to call popBack() on an empty MultidimensionalArray.byElementRandomAccess");
				--rest;
				foreach_reverse(i; iotaTuple!n)
				{
					backShift -= e.strides[i];
					if(--afterBackIndices[i] > 0)
						break;
					else
					{
						assert(i || !rest);
						backShift += e.p_lengths[i] * e.strides[i];
						afterBackIndices[i] = e.p_lengths[i];
					}
				}
			}

			@property save()
			{
				return this;
			}

			@property size_t length() const
			{
				return rest;
			}
		}
		immutable els = elements;
		return Result(this, 0, els, 0, els-1, 0, p_lengths);
	}

	/// Returns a finite random-access range for iteration over the top dimension.
	/// It has mutable elements iff $(D dimentions) is 1.
	@property byTopDimension()
	{
		static struct Result
		{
			private MultidimensionalArray e; //entity

			@property bool empty() const
			{
				return !e.p_lengths[0];
			}

			static if(n == 1)
			{
				@property ref front() {
					assert(!empty, "Trying to call front() on an empty MultidimensionalArray.byTopDimension");
					return e.data[0];
				}

				@property ref back() {
					assert(!empty, "Trying to call back() on an empty MultidimensionalArray.byTopDimension");
					return e.data[$-1];
				}

				@property ref opIndex(size_t i) {
					assert(!empty, format("Trying to call opIndex(%s) on an empty MultidimensionalArray.byTopDimension", i));
					assert(i < length, format("Index is out of bounds: trying to call opIndex(%s) on an MultidimensionalArray.byTopDimension with a length = %s", i, length));
					return e.data[i];
				}
			}
			else
			{
				@property front()
				{
					assert(!empty, "Trying to call front() on an empty MultidimensionalArray.byTopDimension");
					return opIndex(0);
				}

				@property back()
				{
					assert(!empty, "Trying to call back() on an empty MultidimensionalArray.byTopDimension");
					return opIndex(e.p_lengths[0] - 1);
				}

				@property opIndex(size_t i) {
					assert(!empty, format("Trying to call opIndex(%s) on an empty MultidimensionalArray.byTopDimension", i));
					assert(i < length, format("Index is out of bounds: trying to call opIndex(%s) on an MultidimensionalArray.byTopDimension with a length = %s", i, length));

					MultidimensionalArray!(T, n-1) res;
					res.p_lengths = e.p_lengths[1 .. $];
					res.strides = e.strides[1 .. $];
					immutable shift = i * e.strides[0];
					res.data = e.data[shift .. shift + e.strides[0]];
					return res;
				}
			}

			void popFront()
			{
				assert(!empty, "Trying to call popFront() on an empty MultidimensionalArray.byTopDimension");
				e.data = e.data[e.strides[0] .. $];
				--e.p_lengths[0];
			}

			void popBack()
			{
				assert(!empty, "Trying to call popBack() on an empty MultidimensionalArray.byTopDimension");
				e.data = e.data[0 .. $ - e.strides[0]];
				--e.p_lengths[0];
			}

			@property save()
			{
				return this;
			}

			@property size_t length() const
			{
				return e.p_lengths[0];
			}
		}
		return Result(this);
	}

	/**
	Map indices. Just for fun.

	Example:
----
auto matrix = mdimArray!char(30, 20);
matrix[] = ' ';

foreach(ref el; matrix.mapIndices!`a, a`) // fills a diagonal
	el = 'X';

foreach(ref el; matrix.mapIndices!`a^^2 / 5, a`()) // fills a parabola points
	el = 'Y';

writeln(matrix);
---
	*/
	@property auto byFunction(string pred)()
	{
		static struct Result
		{
			MultidimensionalArray rarr;
			size_t a;
			size_t[n] indices;
			@property bool empty() const { return !rarr.goodGetOffset(indices); }
			@property auto save() { return Result(rarr, a, indices); }
			@property ref front() { return rarr[indices]; }
			void popFront()
			{
				++a;
				//slow unless @@@BUG@@@ 2356 will be fixed: indices = mixin('['~pred~']');
				void setArr(size_t[n] arr...) { indices = arr; }
				mixin(`setArr(`~pred~`);`);
			}
		}
		auto res = Result(this, -1);
		res.popFront();
		return res;
	}

	/**
	Implements by-element iteration with inidces starting from the top dimension.

	Example:
----
auto matrix = mdimArray!int(2, 3, 4);
foreach(z, y, x, ref el; matrices)
	el = z * 100 + y * 10 + x;
----
	*/
	int opApply(int delegate(SizeTypes, ref T) dg)
	{
		if(!elements)
			return 0;
		SizeTypes indices = 0;
		indices[$-1] = -1;
		for(;;)
		{
			foreach_reverse(plane, ref index; indices)
			{
				if(++index < p_lengths[plane])
					break;
				else if(plane)
					index = 0;
				else
					return 0;
			}
			if(int res = dg(indices, data[offset(indices)]))
				return res;
		}
		assert(0);
	}

	/**
	Implements elements initialisation with a $(D value), where $(D value) can be
	of type $(D T) or an input range which $(D front) can be assigned to an element.
	The range should contain exectly $(D elements) elements, otherwise an $(D Exception)
	will be thrown.

	Returns:
	If $(D value) is of type $(D T) or a forward range, returns $(D value).
	Otherwise ($(D value) is an input range but not a forward range) returns $(D void).

	Example:
----
auto a23 = mdimArray!int(2, 3);
auto a46 = mdimArray!int(4, 6);
auto a234 = mdimArray!int(2, 3, 4);

a23[] = a234[] = 7;
a23[] = take(a46[] = a234[] = iota(24), 6);
----
	*/
	T opSliceAssign()(T value)
	{
		fill(byElementForward, value);
		return value;
	}

	/// ditto
	auto opSliceAssign(Range)(Range value)
	if(isInputRange!Range && isAssignable!(T, ElementType!Range))
	{
		static if(hasLength!Range)
			debug enforce(value.length == elements, format("MultidimensionalArray.opSliceAssign(Range): value length (%s) doesn't match array elements count (%s)", value.length, elements));
		static if(isForwardRange!Range)
			Range t = value.save;
		foreach(ref el; byElementForward)
		{
			debug enforce(!value.empty, format("MultidimensionalArray.opSliceAssign(Range): value doesn't contain enough elements (< %s)", elements));
			el = value.front;
			value.popFront();
		}
		debug enforce(value.empty, format("MultidimensionalArray.opSliceAssign(Range): value contains too many elements (> %s)", elements));
		static if(isForwardRange!Range)
			return t;
	}

	/// ditto
	auto opSliceAssign(U)(MultidimensionalArray!(U, n) value) if(is(Unqual!U == T))
	{
		debug enforce(value.p_lengths == p_lengths, format("MultidimensionalArray.opSliceAssign(MultidimensionalArray): value lengths %s aren't equal to this lengths %s", value.p_lengths, p_lengths));
		opSliceAssign(value.byElementForward);
		return value;
	}

	/**
	Support for $(D dup) and $(D idup) properties for MultidimensionalArray.
	*/
	@property dup()
	{
		auto res = MultidimensionalArray!(Unqual!T, n)(lengths);
		res[] = this;
		return res;
	}

	/// ditto
	@property idup()
	{
		static if(is(T == immutable))
			return this;
		else
		{
			auto res = dup;
			return *cast(MultidimensionalArray!(immutable T, n)*) &res;
		}
	}

	/**
	Inexing/slicing.

	A parameter can be:

$(TABLE
	$(TR $(TH type)           $(TH meaning)         $(TH effect on a resulting dimensions))
	$(TR $(TD $(D n))         $(TD a position)      $(TD -1))
	$(TR $(TD $(D R[m .. n)]) $(TD a range)         $(TD 0))
	$(TR $(TD $(D R[]))       $(TD the whole range) $(TD 0))
)
	Examples:
	See $(D MultidimensionalArray) examples.

	Bugs:
	A bit ugly syntax is used because dmd hasn't support for a better one yet (see  $(DBUGZILLA 6798)).
	*/
	ref opIndex()(in size_t[n] indices...)
	{
		debug enforce(goodGetOffset(indices), format("MultidimensionalArray.opIndex(size_t[n]): indices %s are out of bounds (lengths are %s)", indices, p_lengths));
		return data[offset(indices)];
	}

	/// ditto
	auto opIndex(A...)(A args) if(args.length == n && allSatisfy!(isROrSize, A) && RCount!A)
	{
		alias MultidimensionalArray!(T, RCount!A) ResultType;

		size_t[n] firstIndices;

		ResultType res;
		static if(RCount!A == n)
			res.strides = strides;

		debug string formatOutOfBounds(int i, string idx, string reason)
		{
			return format("MultidimensionalArray.opIndex: Index #%s = %s is out of bounds 0 .. %s (%s)", i+1, idx, p_lengths[i], reason);
		}
		foreach(i, a; args)
		{
			alias Unqual!(A[i]) UnqualAi;

			static if(RCount!UnqualAi)
			{
				enum j = RCount!(A[0 .. i]);
				static if(RCount!A != n)
					res.strides[j] = strides[i];
			}
			static if(is(UnqualAi == R_))
			{
				debug enforce(a.from <= a.to, format("MultidimensionalArray.opIndex: Index #%s = %s..%s is a range with from > to", i+1, a.from, a.to));
				debug enforce(a.from >= 0, formatOutOfBounds(i, format("%s..%s", a.from, a.to), "from < 0"));
				debug enforce(a.to <= p_lengths[i], formatOutOfBounds(i, format("%s..%s", a.from, a.to), "to > lengths[i]"));
				firstIndices[i] = a.from;
				res.p_lengths[j] = a.to - a.from;
			}
			else static if(is(UnqualAi == AllR))
			{
				firstIndices[i] = 0;
				res.p_lengths[j] = p_lengths[i];
			}
			else
			{
				debug enforce(a >= 0, formatOutOfBounds(i, to!string(a), "index < 0"));
				debug enforce(a < p_lengths[i], formatOutOfBounds(i, to!string(a), "index >= lengths[i]"));
				firstIndices[i] = a;
			}
		}

		res.data = data[offset(firstIndices) .. $]; //TODO $ -> actual bound
		return res;
	}

	/// ditto
	auto opIndexAssign(U, A...)(U value, A args) if(args.length == n && allSatisfy!(isROrSize, A))
	{
		static if(RCount!A)
			return this[args][] = value;
		else
		{
			debug enforce(goodGetOffset(args), format("MultidimensionalArray.opIndexAssign: index out of bounds (lengths: %s, indices: %s)", p_lengths, [args]));
			return data[offset(args)] = value;
		}
	}

	/**
	Creates a slice of this entire array with reordered indices. $(D newOrder[i] = n) means that
	$(D i)-th index of a resulting array will behave like $(D n)-th index of the original array.
	Every index sould be used once, otherwise an $(D Exception) will be thrown.

	Example:
	----
auto matrix3x4 = mdimArray!int(3, 4);
auto transposed = matrix3x4.reorderIndices(1, 0);
assert(transposed.lengths == [4, 3]);
assert(&matrix3x4[2, 3] == &transposed[3, 2]);
	----

	Example:
	----
auto a = mdimArray!int(2, 3, 4);
auto b = a.reorderIndices(2, 0, 1);
assert(b.lengths == [4, 2, 3]);
assert(&a[1, 2, 3] == &b[3, 1, 2]);
	----
	*/
	auto reorderIndices(in size_t[n] newOrder...)
	{
		typeof(this) res;
		debug bool[n] used;
		foreach(newPlane, oldPlane; newOrder)
		{
			debug enforce(oldPlane >= 0 || oldPlane < n, format("MultidimensionalArray.reorderIndices: %s isn't a valid index number for a %s-dimnsional array", oldPlane, n));
			debug enforce(!used[oldPlane], format("MultidimensionalArray.reorderIndices: Index number %s is used more than one time in %s", oldPlane, newOrder));
			debug used[oldPlane] = true;
			res.strides[newPlane] = strides[oldPlane];
			res.p_lengths[newPlane] = p_lengths[oldPlane];
		}
		res.data = data;
		return res;
	}

	/// Dirty toString() functions just for debug purposes. Implemented for $(D dimentions) = 1, 2 or 3.
	static if(n == 1)
		string toString(size_t elementLength = 0) {
			string res = "[";
			foreach(i, el; this)
				res ~= to!string(el).rightJustify(elementLength) ~ (i == p_lengths[0]-1 ? "" : ", ");
				res ~= ']';
			return res;
		}
	else static if(n == 2)
		string toString(size_t elementLength = 0) {
			foreach(el; byElementForward)
				elementLength = max(elementLength, to!string(el).length);

			string res;
			foreach(i; 0 .. p_lengths[0])
				res ~= this[i, R[]].toString(elementLength) ~ '\n';
			return res;
		}
	else static if(n == 3)
		string toString(size_t elementLength = 0) {
			foreach(el; byElementForward)
				elementLength = max(elementLength, to!string(el).length);

			string res = "[";
			foreach(i; 0 .. p_lengths[0])
				res ~= '\n' ~ this[i, R[], R[]].toString(elementLength);
			res ~= "]\n";
			return res;
		}

private:
	size_t[n] p_lengths = void;
	size_t[n] strides = void;
	// it's better not to assume that data.length == strides[0] * p_lengths[0]
	T[] data;

	size_t offset(in size_t[n] indices...) const
	in { foreach(plane, index; indices) assert(index >= 0 && index <= p_lengths[plane]); }
	body {
		size_t res = 0;
		foreach(plane; iotaTuple!n)
			res += indices[plane] * strides[plane];
		return res;
	}

	bool goodGetOffset(in size_t[n] indices...) const
	{
		foreach(plane; iotaTuple!n)
			if(indices[plane] < 0 || indices[plane] >= p_lengths[plane])
				return false;
		return true;
	}
}

/**
Convenience function that returns an $(D MultidimensionalArray!(T, n)) object.

Returns:
The first overload returns a $(D MultidimensionalArray) with a newly allocated data
Others use an existing storage.

Params:
data = A memory storage for a resulting array of type $(D T[]).
array = An array to wrap. It can be a multidimensional static array or a
slice of it (has a dynamic top dimension).
lengths = Lengths of a resulting array.

Template_parameters:
$(D T) Element type of a resulting array. Should be explicitly defined only
for the first overload which has no memory storage.

$(D n) Dimensions of a resulting array. Can be explicitly defined to use only
first $(D n) of $(D array) dimensions.

$(D A) Type of a wrapping $(D array). It is inferred from the $(D array) argument
and should not be explicitly defined.

See_Also: MultidimensionalArray

Throws: The first overload throws an $(D RangeError) in $(D debug) build if $(D data) length isn't equal to $(D lengths) prouct.

Example:
----
// Let's create an GC allocated three-dimensional rectangular array from 2 matrices 3x4
auto matrix1 = mdimArray!int(2, 3, 4);

// Let's create the same array using an existing storage
auto darr2 = new int[24]; //At least 24 elements are needed
auto matrix2 = mdimArray(darr2, 2, 3, 4); //No need for explicit element type declaration

// Let's create the same array using an existing static array as data storage
int[4][3][2] sarr3; // or in a postfix form: int sarr[2][3][4];
auto matrix3 = mdimArray(sarr3); // No need for any explicit template declarations

// The head array can be dynamic
int[4][3][] darr3 = sarr3[];
auto matrix31 = mdimArray(darr3); // Works like previous one

// Let's create an array of static arrays
ubyte[4][4][3][2] sarr4; // a postfix form: ubyte[4] sarr[2][3][4];
auto matrix4 = mdimArray!3(sarr4); // Only 3 major of 4 dimensions are indeces

// The head array can also be dynamic
auto matrix41 = mdimArray!3(sarr4[]); // Works like previous one
----
*/
// #1: allocate new
auto mdimArray(T, size_t n)(size_t[n] lengths...) if(n > 0)
{
	return MultidimensionalArray!(T, n)(lengths);
}

/// ditto
// #2: use existing storage
auto mdimArray(size_t n, T)(T[] data, size_t[n] lengths...) if(n > 0)
{
	return MultidimensionalArray!(T, n)(data, lengths);
}

private auto mdimArray_BUG(size_t n, T)(T[] data, size_t[n] lengths...) if(n > 0)
{
	return MultidimensionalArray!(T, n)(data, lengths);
}

/// ditto
// #3: use some dimensions of an existing static array
auto mdimArray(size_t n, A)(ref A array) if(n > 0 && n <= staticArrayDimensions!A)
{
	alias MultidimensionalStaticArrayElementType!(A, n) ElementType;
	return mdimArray_BUG!(n, ElementType)(cast(ElementType[])array, multidimensionalStaticArrayLengths!(A, n));
}

/// ditto
// #4: use all dimensions of an existing static array
auto mdimArray(A)(ref A array) if(isStaticArray!A)
{
	return mdimArray!(staticArrayDimensions!A)(array);
}

/// ditto
// #5: use some dimensions of an existing dynamic array of static arrays
auto mdimArray(size_t n, A)(A array) if(isDynamicArray!A && n > 0 && n-1 <= staticArrayDimensions!(ElementType!A))
{
	alias MultidimensionalStaticArrayElementType!(ElementType!A, n-1) U;
	return mdimArray_BUG!(n, U)(cast(U[])array, array.length, multidimensionalStaticArrayLengths!(ElementType!A, n-1));
}

/// ditto
// #6: use all dimensions of an existing dynamic array of static arrays
auto mdimArray(A)(A array) if(isDynamicArray!A)
{
	return mdimArray!(1 + staticArrayDimensions!(ElementType!A))(array);
}

unittest //mdimArray
{
	void test234matrix(T)(ref T matrix)
	{
		static assert(isForwardRange!(typeof(matrix.byElementForward)));
		static assert(hasAssignableElements!(typeof(matrix.byElementForward)));
		static assert(hasLength!(typeof(matrix.byElementForward)));

		static assert(isBidirectionalRange!(typeof(matrix.byElementRandomAccess)));
		static assert(isRandomAccessRange!(typeof(matrix.byElementRandomAccess)));
		static assert(hasAssignableElements!(typeof(matrix.byElementRandomAccess)));
		static assert(hasLength!(typeof(matrix.byElementRandomAccess)));

		static assert(isBidirectionalRange!(typeof(matrix.byTopDimension)));
		static assert(isRandomAccessRange!(typeof(matrix.byTopDimension)));
		static assert(hasAssignableElements!(typeof(matrix.byTopDimension)) == (T.dimentions == 1));
		static assert(hasLength!(typeof(matrix.byTopDimension)));
		with(matrix)
		{
			assert(data.length == 24);
			static assert(lengths.length == 3);
			assert(lengths == [2, 3, 4]);
		}
	}

	auto matrix1 = mdimArray!int(2, 3, 4); // #1
	test234matrix(matrix1);

	auto darr2 = new int[24];
	auto matrix2 = mdimArray(darr2, 2, 3, 4); // #2
	test234matrix(matrix2);

	int[4][3][2] sarr3;
	auto matrix3 = mdimArray(sarr3); // #4
	test234matrix(matrix3);

	int[4][3][] darr3 = sarr3[];
	auto matrix31 = mdimArray(darr3); // #6
	test234matrix(matrix31);

	ubyte[4][4][3][2] sarr4;
	auto matrix4 = mdimArray!3(sarr4); // #3
	test234matrix(matrix4);

	auto matrix41 = mdimArray!3(sarr4[]); // #5
	test234matrix(matrix41);
}

unittest //MultidimensionalArray properties: dimentions, lengths, elements, packedDimensions
{
	auto rarr3 = mdimArray!int(3, 4, 5);

	with(rarr3)
	{
		static assert(dimentions == 3);
		assert(lengths == [3, 4, 5]);
		assert(elements == 60);
		assert(packedDimensions == 3);
	}

	auto rarr3s = rarr3[R[], R[], R[]];
	with(rarr3)
	{
		static assert(dimentions == 3);
		assert(lengths == [3, 4, 5]);
		assert(elements == 60);
		assert(packedDimensions == 3);
	}

	rarr3s = rarr3[R[0..2], R[], R[]];
	with(rarr3s)
	{
		static assert(dimentions == 3);
		assert(lengths == [2, 4, 5]);
		assert(elements == 40);
		assert(packedDimensions == 3);
	}

	rarr3s = rarr3[R[0..1], R[], R[]];
	with(rarr3s)
	{
		static assert(dimentions == 3);
		assert(lengths == [1, 4, 5]);
		assert(elements == 20);
		assert(packedDimensions == 3);
	}

	foreach(i; 0 .. 4)
	{
		rarr3s = rarr3[R[], R[0..i], R[]];
		with(rarr3s)
		{
			static assert(dimentions == 3);
			assert(lengths == [3, i, 5]);
			assert(elements == 15 * i);
			assert(packedDimensions == 2);
		}
	}

	foreach(i; 0 .. 5)
	{
		rarr3s = rarr3[R[], R[], R[0..i]];
		with(rarr3s)
		{
			static assert(dimentions == 3);
			assert(lengths == [3, 4, i]);
			assert(elements == 12 * i);
			assert(packedDimensions == 1);
		}
	}

	auto rarr2 = rarr3[1, R[], R[]];
	with(rarr2)
	{
		static assert(dimentions == 2);
		assert(lengths == [4, 5]);
		assert(elements == 20);
		assert(packedDimensions == 2);
	}

	rarr2 = rarr3[R[], 1, R[]];
	with(rarr2)
	{
		static assert(dimentions == 2);
		assert(lengths == [3, 5]);
		assert(elements == 15);
		assert(packedDimensions == 1);
	}

	rarr2 = rarr3[R[], R[], 1];
	with(rarr2)
	{
		static assert(dimentions == 2);
		assert(lengths == [3, 4]);
		assert(elements == 12);
		assert(packedDimensions == 0);
	}
}

unittest //MultidimensionalArray iterations: byElementForward, byElementRandomAccess, byTopDimension, opApply
{
	void test(T)()
	{
		T sarr;
		auto darr = cast(int[])sarr;
		auto matrix = mdimArray(sarr);

		darr[] = -1;
		int c;
		foreach(ref el; matrix.byElementForward)
		{
			el = c;
			assert(darr[c] == c && el == c && &el == &darr[c]);
			++c;
		}

		darr[] = -1;
		c = 0;
		foreach(ref el; matrix.byElementRandomAccess)
		{
			el = c;
			assert(darr[c] == c && el == c && &el == &darr[c]);
			++c;
		}

		darr[] = -1;
		c = matrix.elements;
		foreach_reverse(ref el; matrix.byElementRandomAccess)
		{
			--c;
			el = c;
			assert(darr[c] == c && el == c && &el == &darr[c]);
		}

		darr[] = -1;
		foreach(i; 0 .. matrix.elements)
		{
			auto ptr = &matrix.byElementRandomAccess[i];
			*ptr = i;
			assert(darr[i] == i && ptr == &darr[i]);
		}

		darr[] = -1;
		{
			auto r = matrix.byElementRandomAccess;

			foreach(i; 0 .. matrix.elements)
			{
				assert(&r[matrix.elements-i-1] == &darr[$-1]);
				auto ptr = &r[0];
				//&r.front() instead of &r.front because of bad property syntax
				assert(ptr == &darr[i] && ptr == &r.front());
				r.popFront();
			}
		}

		darr[] = -1;
		c = 0;
		static if(matrix.dimentions == 3)
			foreach(x, y, z, ref el; matrix)
			{
				el = c;
				assert(c == x * matrix.strides[0] + y * matrix.strides[1] + z * matrix.strides[2]);
				assert(darr[c] == c && el == c && &el == &darr[c]);
				++c;
			}
		else static if(matrix.dimentions == 2)
			foreach(x, y, ref el; matrix)
			{
				el = c;
				assert(c == x * matrix.strides[0] + y * matrix.strides[1]);
				assert(darr[c] == c && el == c && &el == &darr[c]);
				++c;
			}

		darr[] = -1;
		c = 0;
		static if(matrix.dimentions == 3)
			foreach(subMatrix; matrix.byTopDimension)
				foreach(row; subMatrix.byTopDimension)
					foreach(ref el; row.byTopDimension)
					{
						el = c;
						assert(darr[c] == c && el == c && &el == &darr[c]);
						++c;
					}
		else static if(matrix.dimentions == 2)
			foreach(row; matrix.byTopDimension)
				foreach(ref el; row.byTopDimension)
				{
					el = c;
					assert(darr[c] == c && el == c && &el == &darr[c]);
					++c;
				}
		else static if(matrix.dimentions == 1)
			foreach(ref el; matrix.byTopDimension)
			{
				el = c;
				assert(darr[c] == c && el == c && &el == &darr[c]);
				++c;
			}

		/*darr[] = -1;
		c = 0;
		foreach(size_t[matrix.dimentions] indices, ref el; matrix)
		{
			el = c;
			assert(darr[c] == c && el == c && &el == &darr[c]);
			++c;
		}*/
	}
	test!(int[0])();
	test!(int[2])();
	test!(int[2][0])();
	test!(int[0][2])();
	test!(int[1][1])();
	test!(int[7][3])();
	test!(int[4][3][2])();
	test!(int[1][2][3][4])();
	test!(int[7][3][7][3])();
}

version(unittest) //MultidimensionalArray unittest helper functions
{
	bool isSame(RArr1, RArr2)(RArr1 rarr1, RArr2 rarr2)
	{
		assert(rarr1.lengths == rarr2.lengths);
		return &rarr1[0, 0, 0] == &rarr2[0, 0, 0];
	}
	bool isCopy(RArr1, RArr2)(RArr1 rarr1, RArr2 rarr2)
	{
		return !isSame(rarr1, rarr2) && equal(rarr1.byElementForward, rarr2.byElementForward);
	}
	bool equalRange(RArr, Range)(RArr rarr, Range r)
	{
		return equal(rarr.byElementForward, r);
	}
}

unittest //MultidimensionalArray copying: opSliceAssign, dup, idup
{
	alias std.range.repeat repeat; //std.string.repeat will be removed in February 2012

	auto a23 = mdimArray!int(2, 3);
	auto a46 = mdimArray!int(4, 6);
	auto a234 = mdimArray!int(2, 3, 4);
	assert(equalRange(a23, repeat(0, 6)));
	assert(equalRange(a46, repeat(0, 24)));
	assert(equalRange(a234, repeat(0, 24)));

	a23[] = a234[] = 7;
	assert(equalRange(a23, repeat(7, 6)));
	assert(equalRange(a234, repeat(7, 24)));

	a23[] = take(a46[] = a234[] = iota(24), 6);
	assert(equalRange(a23, iota(6)));
	assert(equalRange(a46, iota(24)));
	assert(equalRange(a234, iota(24)));

	auto b234 = a234.dup;
	assert(isCopy(a234, b234));

	b234[] = -1;
	assert(equalRange(a234, iota(24)));

	b234 = a234;
	assert(isSame(a234, b234));

	b234 = mdimArray!int(2, 3, 4);
	b234[] = a234;
	assert(isCopy(a234, b234));

	auto ia234 = a234.idup;
	static assert(is(typeof(ia234) == MultidimensionalArray!(immutable int, 3u)));
	static assert(!__traits(compiles, (ia234[] = 7)));
	static assert(!__traits(compiles, (ia234[] = new int[24])));
	assert(isCopy(a234, ia234));
	assert(isSame(ia234, ia234.idup));
	assert(isCopy(ia234, ia234.dup));

	const(int)[4][3][2] carr;
	auto ca234 = mdimArray(carr);
	static assert(is(typeof(ca234) == MultidimensionalArray!(const int, 3u)));
	static assert(!__traits(compiles, (ca234[] = 7)));
	static assert(!__traits(compiles, (ca234[] = new int[24])));
	assert(isCopy(ca234, ca234.idup));
	assert(isCopy(ca234, ca234.dup));


	b234[] = ia234;
	assert(isCopy(a234, b234));


	auto a123 = mdimArray!int(1, 2, 3);
	assert(equalRange(a123, repeat(0, 6)));

	a123[] = 7;
	assert(equalRange(a123, repeat(7, 6)));

	a123[] = [8, 8, 8,    8, 8, 8];
	assert(equalRange(a123, repeat(8, 6)));

	a123[] = repeat(9, 6);
	assert(equalRange(a123, repeat(9, 6)));

	auto matrix2 = mdimArray!(int[])(1, 2, 3);
	matrix2[] = [9];
}

unittest //MultidimensionalArray reordering: reorderIndices
{
	auto matrix3x4 = mdimArray!int(3, 4);
	auto transposed = matrix3x4.reorderIndices(1, 0);
	assert(transposed.lengths == [4, 3]);
	assert(&matrix3x4[2, 3] == &transposed[3, 2]);

	auto a = mdimArray!int(2, 3, 4);
	auto b = a.reorderIndices(2, 0, 1);
	assert(b.lengths == [4, 2, 3]);
	assert(&a[1, 2, 3] == &b[3, 1, 2]);
}

//TODO unittests for: byFunction, opIndexAssign, opIndex
