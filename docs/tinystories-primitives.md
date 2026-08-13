# TinyStories/GPT-Neo primitive contract

The context-eight GPT-Neo slice expands Livt.ML through reusable semantic
operators rather than exposing raw ONNX bookkeeping nodes.

## Numeric formats

- Learned linear weights and zero points are accepted as integer values by
  `Int8LinearAccumulator`; the caller owns their storage and scale records.
- Linear products accumulate in signed int32 through `Livt.Math.MacInt32`.
- `Int8BroadcastMac64x8` and `Int8Dot64x8` provide the throughput datapath for
  width-64 projections: eight registered signed 16-by-8 products and signed
  int32 accumulation. The imported model must prove activation values fit
  signed 16-bit before using these components.
- `LayerNorm64`, its learned affine values, and `GeluNewApproxQ8` use Q8.8 scale
  256 at their documented boundaries.
- `StableSoftmax8` accepts signed scores and emits Q1.15 weights at scale 32768.
- `CausalAttentionHead4Context8` divides scores by two because the exact
  GPT-Neo head width is four and `sqrt(4) = 2`.

The model importer must derive activation scales, integer epsilon, projection
requantization, and scale-aligned residual additions from calibrated model data.
Those values are not guessed inside the base library.

## Reference and streaming variants

`LayerNorm64` is the readable non-streaming reference. Bulk `ComputeValues` and
`SetAffineValues` calls avoid repeated scalar calls, but current compiler shadow
signals still make it unsuitable for the default GHDL suite.
`LayerNorm64Stream` preserves the same mathematics while keeping arrays inside
a process and exposing scalar toggle handshakes; it is the performance-oriented
implementation and the default regression target.

`Embedding64Stream` similarly owns no table. It translates an entry index into
64 consecutive flat addresses supplied by a ROM, Livt.IO RAM, or external
memory controller. `TokenEmbedding50257x64Stream` and
`PositionEmbedding8x64Stream` demonstrate the base-plus-specialization pattern.

`StreamingArgMax` consumes indexed scores individually, retains only the best
value/index pair, and selects the lowest index on exact ties. A full vocabulary
projection can therefore avoid storing 50,257 logits.

For 64-output transformer matrices, `Int8BroadcastMac64x8` accepts one packed
weight row per activation and retains 64 accumulators. For the vocabulary tail,
`Int8Dot64x8` configures the final hidden vector once and evaluates one packed
vocabulary row per call. This pair avoids tensor-valued public calls, bounds
the multiplier count at eight, and supports double-buffered external-memory
row loading without embedding a memory policy in Livt.ML.

## Importer boundary

The host importer must specialize batch size one, context eight, and empty
input caches. Dynamic shape, mask, layout, and cache-output nodes are folded or
pruned on the host. Livt.ML implements embedding, LayerNorm, linear projection,
causal attention, softmax, GELU-new, residual arithmetic, and ArgMax semantics;
it does not implement ONNX `Shape`, `Range`, `Where`, or graph interpretation.
