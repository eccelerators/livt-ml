# Transformer scratch storage

`FixedTransformerKernels` borrows a fourth constructor argument and a final
`SCRATCH: IRam<int>` type parameter. Consumers must supply scratch explicitly;
the kernel no longer retains scores/probabilities as mutable arrays.

For `MAX_TOKENS = 32`, allocate `BlockRam<int, 64>` and pass it after activation
memory. Append that same type to every occurrence of the kernel specialization,
including encoder/decoder generic arguments. Existing three-argument constructor
calls need this migration. The package version is unchanged pending publication.

| Address range | Contents |
| --- | --- |
| `0 .. MAX_TOKENS-1` | Scores for one query/head |
| `MAX_TOKENS .. 2*MAX_TOKENS-1` | Exponents, then rounded probabilities |

Scratch must provide a contiguous valid range beginning at zero. Attention and
CachedAttention reject insufficient capacity before accessing model tensors.
Scratch must be independent of activation memory, and callers must serialize all
kernel operations and external scratch accesses. The same scratch can serve both
attention methods because they do not execute concurrently. Other kernel methods
do not use scratch.

Reads and writes use scheduled `IRam` completion semantics. This changes latency,
not the numeric format, rounding, masking, model shape or arithmetic operations.
`IRam` has no transport-error channel: use a reliable local RAM backend. Explicit
block/distributed styles request an implementation; inspect synthesis to confirm
physical mapping on the selected target.

Reset kernel and RAM transaction state together. RAM cells need no reset or bulk
clear. Each query initializes every consumed score/exponent/probability location;
masked cached-attention scores are explicitly written as zero. An interrupted
operation is discarded, and the next call initializes its own working set. A
validation/numeric failure may leave scratch partially overwritten; contents are
not a public result and must never be reused without a new attention call.

The motivation is measured hardware cost: the earlier Tang GW5AST-138B netlist
held two 32x32-bit arrays in five generated copies each (10,240 flip-flops), plus
selection/control logic. Shared RAM avoids array-valued scheduled state. The
actual resource saving and latency must be measured; reduced storage alone does
not prove routed timing or full-design fit.

## Focused verification

Generate current HDL with `livt test -r FixedTransformerKernelsTest`, then run
`python3 scripts/test_transformer_scratch.py` and
`python3 scripts/test_transformer_scratch_reset.py`. The first script checks five
scenarios covering shape/rounding, causal masks, full-capacity reuse across
attention methods, recovery after failure, and insufficient storage.
The second instruments only simulation copies to inject shared reset after a
completed scratch write during active attention, then reruns the numerical
scenario with both synchronous and asynchronous reset. Production HDL is untouched.

Both focused runners passed for this change. The unrelated full-vocabulary
argmax regression was interrupted to keep this validation focused; no complete
library-suite pass is claimed. Physical resource measurements are recorded in
the Tang project's TM-FLAN-007A evidence.
