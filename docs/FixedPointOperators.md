# Generic fixed-point operators

The new operators add explicit integer semantics; existing Q8 operators and
fixed-size APIs are unchanged. `Numeric.FixedPointMath` parameterizes activation
width/fraction and unsigned scale fraction. It decodes signed INT4, reconstructs
each weight with nearest/ties-even rounding, and implements symmetric saturated
residual/gated operations. Out-of-range reconstructed weights are errors.

`Linear.FixedPointAccumulator` retains 64-bit sums until final requantization;
`Linear.QuantizedMatrix` streams flattened row-major groups through injected
`Storage.IQuantizedWeights` and `Livt.IO.IRam<int>` providers. Row boundaries need
not coincide with scale groups, and the last group may be partial. There is no
learned-weight ROM in these components.

`Norm.FixedRmsNorm` parameterizes length, format, epsilon and RAM provider. It
uses floor mean square and floor square root, then separate rounded and clipped
normalization and gamma multiplication. `Activation.MaskedFixedSoftmax` uses
injected exponent tables, excludes masks from maximum and denominator, rejects
fully masked rows, and applies no probability-sum correction.
`Activation.ZeroIdentityLookup` exposes table geometry and the zero/identity tail
policy explicitly. `Storage.RamLookupTable` is a bounded external RAM view.

Calls are scheduled and serialized under one owner. Providers must remain stable
through an operation. Norm/softmax require disjoint contiguous spans. Invalid
requests return false (norm/softmax) or zero with `Failed()` (matrix/scalar).
Accumulator failures remain latched until `Begin()`; reset cancels arithmetic
handshakes, while provider RAM retains its cells. Width, dimension and format
constraints reject unsafe specializations during compilation.

These operators use Livt.Math's portable 64-bit backend because Livt `int` is
32-bit and logic-vector multiply/divide is unsupported. Public formats are
generic; the backend transport is currently fixed at 64 bits. This serial
implementation establishes exact arithmetic, not an FPGA timing or throughput
guarantee. More parallel workers can preserve the same operator boundaries.

The FLAN-T5 consumer's FT5-010 suite exercises at least two parameter combinations
per generic primitive and exact saved model checkpoints, plus negative cases.
Relevant existing ML/Math and TinyStories regressions remain part of validation.
