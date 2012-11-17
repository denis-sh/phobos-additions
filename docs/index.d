/++
$(I phobos-additions) is a library with useful general stuff not included in Phobos
for various reasons.

$(H2 Brief $(I phobos-additions) content description)
$(MEMBERSDESC
	ExtractTypes trait,
	$(FREF traits, ExtractTypes),
	no.,
	$(IDENTITY
		Useful for serialization algorithms which need to know all composing types.
	)
)
$(MEMBERSDESC
	ArrayElementType trait,
	$(FREF traits, ArrayElementType),
	$(IDENTITY
		$(PHOBOSPULL 776), $(RED closed) by Andrei Alexandrescu
	),
	$(IDENTITY
		A convenient template to retrieve array element type for template
		programming purposes. $(I Phobos)'s $(STDREF range, ElementEncodingType)
		should be used only if array is treated as a range, otherwise it reduces
		templated code readability and looks inconsistent because many templates
		are from "differen world" and don't have to know anything about ranges.
	)
)
$(MEMBERSDESC
	Multidimensional static array traits,
	$(FREF traits, staticArrayDimensions)
	$(FREF traits, MultidimensionalStaticArrayElementType)
	$(FREF traits, multidimensionalStaticArrayElementsCount)
	$(FREF traits, multidimensionalStaticArrayLengths)
	,
	$(IDENTITY
		Partially (except $(D multidimensionalStaticArrayLengths)) in $(PHOBOSPULL 924) ($(GREEN open)).
	),
	$(IDENTITY
		These templates are needed for analysing multidimensional static arrays.
	)
)
$(MEMBERSDESC
	Function converting everything into a static array,
	$(FREF array, asFlatStaticArray),
	$(IDENTITY
		$(PHOBOSPULL 952) ($(GREEN open))
	),
	$(IDENTITY
		$(D asFlatStaticArray) adds an ability to view any abject as
		a single-dimensional static array which is very useful for template code as
		it eliminates error-prone need to create branches and recursion for
		static-arrays support.
	)
)
$(MEMBERSDESC
	Sliceable multidimensional array,
	$(FREF multidimensionalarray, MultidimensionalArray)
	$(FREF multidimensionalarray, mdimArray)
	,
	no.,
	$(IDENTITY
		$(DPMODULE multidimensionalarray) module adds ability to slice
		multidimensional rectangular arrays and ranges to iterate slices.
	)
)
$(MEMBERSDESC
	Generic tuple general templates,
	$(FREF generictuple, GenericTuple)
	$(FREF generictuple, TypeTuple)
	$(FREF generictuple, expressionTuple)
	,
	$(IDENTITY
		$(PHOBOSPULL 780) ($(GREEN open)).
	),
	$(IDENTITY
		There should be at least both $(D GenericTuple) and $(D TypeTuple) as the latter
		is a common usecase of generic tuples.
		E.g. $(D TypeTuple) is used ~70% of generic tuple usage in $(I Phobos).
	)
)
$(MEMBERSDESC
	Packed generic tuple templates,
	$(FREF generictuple, PackedGenericTuple)
	$(FREF generictuple, PackedTypeTuple)
	$(FREF generictuple, packedExpressionTuple)
	$(FREF traits, isPackedTuple)
	,
	no.,
	$(IDENTITY
		Useful when passing more than one generic tuple to a template.
	)
)
$(MEMBERSDESC
	Generic tuple creation templates,
	$(FREF generictuple, RetroTuple)
	$(FREF generictuple, StrideTuple)
	$(FREF generictuple, ChainTuple)
	$(FREF generictuple, RoundRobinTuple)
	$(FREF generictuple, RadialTuple)
	$(FREF generictuple, RepeatTuple)
	$(FREF generictuple, ZipTuple)
	$(FREF generictuple, iotaTuple)
	$(FREF generictuple, IndexedTuple)
	$(FREF generictuple, ChunksTuple)
	,
	no.,
	$(IDENTITY
		Templates for generic tuple creation by analogy with
		range creation functions from $(STDMODULE range).
	)
)
$(MEMBERSDESC
	Generic tuple algorithm templates,
	$(FREF generictuple, cmpTuple)
	$(FREF generictuple, equalTuple)
	$(FREF generictuple, FilterTuple)
	$(FREF generictuple, groupTuple)
	$(FREF generictuple, JoinTuple)
	$(FREF generictuple, MapTuple)
	$(FREF generictuple, ReduceTuple)
	$(FREF generictuple, UniqTuple)
	,
	no.,
	$(IDENTITY
		Templates for various algorithms on generic tuples by analogy with
		range algorithm functions from $(STDMODULE algorithm).
	)
)
$(MEMBERSDESC
	Template creating a set of flags,
	$(FREF typecons, flagEnum),
	no.,
	$(IDENTITY
		Creates a set of flags for which any non-flag operations ar prohibited.
	)
)
$(MEMBERSDESC
	Commonly needed in programming integer mathematical functions related to
	powers of 2,
	$(FREF math, isPowerOf2)
	$(FREF math, roundDownToPowerOf2)
	$(FREF math, roundUpToPowerOf2)
	$(FREF math, log2RoundedDown)
	$(FREF math, log2RoundedUp)
	$(FREF math, alignDown)
	$(FREF math, alignUp)
	,
	no.,
	$(IDENTITY
		It is just too commonly needed to not include it in a standard library
		forsing almost everybody to spend time writing such functions.
	)
)
$(MEMBERSDESC
	Instantiate template,
	$(FREF templates, Inst),
	no.,
	$(IDENTITY
		A convenience util to instantiate templates needed because of $(B D) syntax
		issues.
	)
)
$(MEMBERSDESC
	Create template from string,
	$(FREF templates, Template)
	$(FREF templates, UnaryTemplate)
	$(FREF templates, BinaryTemplate)
	$(FREF templates, unaryPred)
	$(FREF templates, binaryPred)
	,
	no.,
	$(IDENTITY
		A stuff for creating templates from strings.
	)
)
$(MEMBERSDESC
	Bind template arguments,
	$(FREF templates, BindTemplate)
	$(FREF templates, Bind)
	,
	no.,
	$(IDENTITY
		A stuff for binding templates arguments.
	)
)
$(MEMBERSDESC
	Combine template predicates,
	$(FREF templates, notTemplate)
	$(FREF templates, andTemplates)
	$(FREF templates, orTemplates)
	,
	no.,
	$(IDENTITY
		A stuff for combining template predicates.
	)
)

Macros:
H2 = <h2>$0</h2>
H3 = <h3>$0</h3>
H4 = <h4>$0</h4>
MEMBERSDESC = $(H3 $1) $(H4 $(I Members):) $(P $2) $(H4 $(I Phobos) pulls:) $(P $3) $(H4 Description:) $(P $4) $(BR) $(BR)
FREF = $(DPREF $1, $2) $(BR)
IDENTITY = $0
PHOBOSPULL = $(HTTPS github.com/D-Programming-Language/phobos/pull/$1, #$1)
+/
module index;