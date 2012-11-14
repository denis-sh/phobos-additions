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
		programming purposes. $(I phobos)'s $(PHOBOSREF range, ElementEncodingType)
		should be used only if array is treated as a range, otherwise it reduced
		templated code readability and looks inconsistent because many templates
		are from "differen world" and doesn't have to know anything about ranges.
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
		This pull also includes $(D asFlatStaticArray) function.
	),
	$(IDENTITY
		These templates are needed for analysing multidimensional static arrays.
	)
)
$(MEMBERSDESC
	Function converting everything into a static array,
	$(FREF array, asFlatStaticArray),
	$(IDENTITY
		Included in $(PHOBOSPULL 924) ($(GREEN open)) with static array traits.
	),
	$(IDENTITY
		TODO docs
	)
)
$(MEMBERSDESC
	Sliceable multidimensional array,
	$(FREF multidimensionalarray, MultidimensionalArray)
	$(FREF multidimensionalarray, mdimArray)
	,
	no.,
	$(IDENTITY
		TODO docs
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
		TODO docs
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
		TODO docs
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
		range creation functions from $(PHOBOSMODULEREF range).
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
		range algorithm functions from $(PHOBOSMODULEREF algorithm).
	)
)
$(MEMBERSDESC
	Template creating a set of flags,
	$(FREF typecons, flagEnum),
	no.,
	$(IDENTITY
		TODO docs
	)
)
$(MEMBERSDESC
	Commonly needed in programming mathematical functions,
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
		TODO docs
	)
)
$(MEMBERSDESC
	Instantiate template,
	$(FREF templates, Inst),
	no.,
	$(IDENTITY
		TODO docs
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
		TODO docs
	)
)
$(MEMBERSDESC
	Bind template arguments,
	$(FREF templates, TemplateBind)
	$(FREF templates, Bind)
	,
	no.,
	$(IDENTITY
		TODO docs
	)
)
$(MEMBERSDESC
	Combine template predicates,
	$(FREF templates, TemplateNot)
	$(FREF templates, TemplateAnd)
	$(FREF templates, TemplateOr)
	,
	no.,
	$(IDENTITY
		TODO docs
	)
)

Macros:
H2 = <h2>$0</h2>
H3 = <h3>$0</h3>
H4 = <h4>$0</h4>
MEMBERSDESC = $(H3 $1) $(H4 $(I Members):) $(P $2) $(H4 $(I phobos) pulls:) $(P $3) $(H4 Description:) $(P $4) $(BR) $(BR)
FREF = $(DPREF $1, $2) $(BR)
IDENTITY = $0
PHOBOSPULL = $(HTTPS github.com/D-Programming-Language/phobos/pull/$1, #$1)
+/
module index;