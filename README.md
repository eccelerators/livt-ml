# Livt.ML

Fixed-size machine-learning building blocks for Livt hardware-oriented designs.

`Livt.ML` provides small, explicit components for integer vectors, quantized
linear inference, activation functions, embeddings, attention, normalization,
transformer-style composition, and simple fitted models. The package is
intentionally concrete rather than generic: APIs expose fixed sizes, stored
outputs, and visible scale factors so generated hardware remains easy to
inspect.

## 📦 Package

```toml
[dependencies]
"Livt.ML" = "1.0.1"
```

`Livt.ML` uses `Livt.Math` for reusable arithmetic primitives such as integer
square root and `Livt.IO` for RAM-backed tensor storage. Current memory sources
target the generic Livt.IO development API: byte tensors use scheduled
`BlockRam<byte, 2048>` banks, and causal attention uses
`AsynchronousDistributedRam32x32`. Verify these source changes with coherent
workspace dependency snapshots; published dependency pins are unchanged.

## 📚 API Overview

| Namespace | Component | Purpose |
|---|---|---|
| `Livt.ML.Numeric` | `RequantizeInt8` | Converts int32 accumulators to signed int8 with ties-to-even rounding and saturation |
| `Livt.ML.Numeric` | `ScheduledRequantizeUInt8` | Scheduled rational uint8 requantization with ties-to-even rounding and saturation |
| `Livt.ML.Convolution` | `QLinearConv1x8Same5x5` | Quantized convolution from one 28x28 plane to eight planes |
| `Livt.ML.Convolution` | `QLinearConv8x16Same5x5` | Quantized convolution from eight 14x14 planes to sixteen planes |
| `Livt.ML.Convolution` | `QLinearConv1x8Same5x5Ram` | RAM-backed non-streaming reference for the first MNIST convolution |
| `Livt.ML.Convolution` | `QLinearConv8x16Same5x5Ram` | RAM-backed non-streaming reference for the second MNIST convolution |
| `Livt.ML.Convolution` | `QConv2DStreamBase` | Reusable zero-point-aware uint8-by-int8 convolution MAC building block |
| `Livt.ML.Convolution` | `QConv2D1x8Kernel5Image28Stream` | Specialized high-throughput 1x8, 5x5, 28x28 streaming convolution |
| `Livt.ML.Convolution` | `QConv2D8x16Kernel5Image14Stream` | Specialized high-throughput 8x16, 5x5, 14x14 streaming convolution |
| `Livt.ML.Pooling` | `MaxPool8x28To14` | 2x2 stride-two max pooling for eight planes |
| `Livt.ML.Pooling` | `MaxPool16x14To4` | 3x3 stride-three max pooling for sixteen planes |
| `Livt.ML.Pooling` | `MaxPool8x28To14Ram` | RAM-backed reference preserving the tensor lifecycle |
| `Livt.ML.Pooling` | `MaxPool16x14To4Ram` | RAM-backed reference preserving the tensor lifecycle |
| `Livt.ML.Pooling` | `MaxPool8x28To14Stream` | Line-buffered streaming alternative with a toggle handshake |
| `Livt.ML.Pooling` | `MaxPool16x14To4Stream` | Four-window streaming alternative with ONNX floor sizing |
| `Livt.ML.Linear` | `QLinearMatMul256x10` | Zero-point-aware per-column quantized projection from 256 activations to ten outputs |
| `Livt.ML.Linear` | `QLinearMatMul256x10Ram` | Compact RAM-backed non-streaming projection reference |
| `Livt.ML.Linear` | `QLinearMatMul256x10Stream` | Compact-weight streaming projection with ten parallel accumulators |
| `Livt.ML.Linear` | `Int8Linear4x8` | Applies eight signed-int8 rows to four inputs with int32 biases and accumulators |
| `Livt.ML.Linear` | `Int8Linear8x3` | Applies three signed-int8 rows to eight inputs with int32 biases and accumulators |
| `Livt.ML.Linear` | `VecAdd` | Adds two 8-element integer vectors |
| `Livt.ML.Linear` | `DotProduct` | Computes an 8-element dot product with positive saturation |
| `Livt.ML.Linear` | `MatrixVectorMultiplication` | Applies a 4 by 8 integer matrix to a vector |
| `Livt.ML.Linear` | `Linear8x8` | Applies an 8 by 8 integer matrix to a vector |
| `Livt.ML.Linear` | `Int8LinearAccumulator` | Storage-free centered int8 projection lane with int32 accumulation |
| `Livt.ML.Linear` | `Int8Mac8` | Context-free eight-lane signed-int8 MAC for memory-fed datapaths |
| `Livt.ML.Linear` | `Int8BroadcastMac64x8` | Pipelined 64-output matrix-row accumulator using eight signed 16x8 lanes |
| `Livt.ML.Linear` | `Int8Dot64x8` | Pipelined 64-element dot product using eight signed 16x8 lanes |
| `Livt.ML.Storage` | `ByteTensorRam2048` | Byte tensor storage backed by one Livt.IO RAM bank |
| `Livt.ML.Storage` | `ByteTensorRam4096` | Byte tensor storage backed by two Livt.IO RAM banks |
| `Livt.ML.Storage` | `ByteTensorRam8192` | Byte tensor storage backed by four Livt.IO RAM banks |
| `Livt.ML.Storage` | `Int16TensorRam2048` | Signed 16-bit activation tensor backed by Livt.IO RAM |
| `Livt.ML.Storage` | `Int32TensorRam2048` | Signed 32-bit accumulator tensor backed by Livt.IO RAM |
| `Livt.ML.Activation` | `ReLU` | Stateless integer ReLU |
| `Livt.ML.Activation` | `SigmoidLUT` | 256-entry sigmoid lookup table |
| `Livt.ML.Activation` | `SiLUApprox` | 8-element SiLU approximation |
| `Livt.ML.Activation` | `SoftmaxApprox` | 8-element scaled softmax approximation |
| `Livt.ML.Activation` | `StableSoftmax8` | Max-subtracted signed-score softmax with Q1.15 outputs |
| `Livt.ML.Activation` | `GeluNewApproxQ8` | GPT-Neo GELU-new approximation for Q8.8 values |
| `Livt.ML.Norm` | `RMSNorm` | 8-element integer RMS normalization |
| `Livt.ML.Norm` | `LayerNorm64` | Readable learned 64-value LayerNorm reference |
| `Livt.ML.Norm` | `LayerNorm64Stream` | Toggle-stream implementation without tensor-valued public calls |
| `Livt.ML.Embedding` | `FixedTokenEmbedding` | Mutable 16 by 8 integer embedding table |
| `Livt.ML.Embedding` | `Embedding64Stream` | External-memory base for streaming a 64-value row |
| `Livt.ML.Embedding` | `TokenEmbedding50257x64Stream` | GPT-2-vocabulary specialization without an internal table |
| `Livt.ML.Embedding` | `PositionEmbedding8x64Stream` | Context-eight position specialization |
| `Livt.ML.Attention` | `KVCache` | Four-slot key/value cache |
| `Livt.ML.Attention` | `ScaledDotProductAttention` | Attention over the fixed key/value cache |
| `Livt.ML.Attention` | `CausalAttentionHead4Context8` | One reusable GPT-Neo causal head for context 8 and width 4 |
| `Livt.ML.Classifier` | `ArgMax3` | Deterministic argmax for three logits |
| `Livt.ML.Classifier` | `ArgMax10` | Deterministic first-maximum argmax for ten logits |
| `Livt.ML.Classifier` | `StreamingArgMax` | Arbitrary-length ArgMax without materializing logits |
| `Livt.ML.Classifier` | `ClassProjection` | Experimental fixed projection from 8 features to 3 logits |
| `Livt.ML.Transformer` | `FeedForwardBlock` | Two-layer 8-element feed-forward block |
| `Livt.ML.Transformer` | `TransformerBlock` | Experimental transformer-style composition block |
| `Livt.ML.Model` | `LinearRegression` | Fits and evaluates a small integer linear model |

Most stateful components follow the same call shape: configure any stored
weights or tables, call `Compute(...)`, then read results with `GetOutput(...)`.
Out-of-range getters return `0`; out-of-range setters ignore the write.
Optimized components ending in `Stream` instead use the documented toggle
handshake and bounded internal storage; see
[`docs/streaming.md`](docs/streaming.md).

`ClassProjection`, `ScaledDotProductAttention`, and `TransformerBlock` remain
experimental compositions. Their APIs may evolve when exercised by an imported
language model; the numeric, tensor, RAM, and streaming operator APIs form the
current stable inference foundation.

```livt
using Livt.ML.Linear

component ExampleLayer
{
	layer: Linear8x8

	new()
	{
		this.layer = new Linear8x8()
	}

	public fn Run(input: int[8])
	{
		this.layer.SetRowValues(0, 1, 0, 0, 0, 0, 0, 0, 0)
		this.layer.Compute(input)
		var first: int = this.layer.GetOutput(0)
	}
}
```

## 🔢 Data Model

The API uses fixed-size `int` vectors, mostly `int[8]`. Signed-int8 tensor
elements are represented by `int` values in `[-128, 127]`; quantized linear
layers retain signed int32 accumulator results until callers explicitly invoke
`RequantizeInt8`. Several
components expose integer scale constants:

- `SigmoidLUT`, `SiLUApprox`, and `SoftmaxApprox` use scaled integer
  approximations.
- `ScaledDotProductAttention` uses explicit score and weight scale constants.
- `LinearRegression` stores the fitted slope as `aFixed`, scaled by
  `LinearRegression.SCALE`.
- `DotProduct.ACC_MAX` defines the positive saturation limit used by the linear
  projection components.
- `LayerNorm64`, `GeluNewApproxQ8`, and their learned affine values use Q8.8
  scale 256; `StableSoftmax8` emits Q1.15 weights at scale 32768.
- `Int8LinearAccumulator` retains signed int32 sums and deliberately does not
  choose output scales; model importers supply those after calibration.
- `Int8BroadcastMac64x8` and `Int8Dot64x8` accept signed 16-bit activations,
  packed signed-int8 weights, and retain signed int32 accumulator results.
  Callers must prove that activations fit `[-32768, 32767]` before the boundary.

Approximation components are useful for simulation, reference designs, and
early hardware exploration. Timing-critical designs should review
[`docs/hardware-notes.md`](docs/hardware-notes.md).

## 🧪 Build and Test

Build the package:

```sh
livt build
```

Run the configured test components:

```sh
livt test
```

The test list is defined in `livt.toml`. Short call-order examples live in
[`docs/usage.md`](docs/usage.md).

## 🔧 Layout

```text
src/numeric/      ML-specific quantization and requantization
src/linear/       vector addition, dot products, and dense projections
src/pooling/      tensor-reference and line-buffered streaming pooling
src/storage/      banked byte tensors backed by Livt.IO RAM components
src/activation/   ReLU, sigmoid/SiLU/GELU approximations, and stable softmax
src/norm/         RMSNorm and reference/streaming LayerNorm
src/embedding/    fixed tables and external-memory embedding streams
src/attention/    KV cache plus reference and bounded causal attention
src/classifier/   small classifier helpers
src/transformer/  fixed-size transformer-style blocks
src/model/        small fitted model components
tests/<domain>/   tests mirroring each source domain
docs/             usage examples and package notes
```

Source namespaces mirror their folders, for example `Livt.ML.Attention`.
Test namespaces mirror the same structure below `Livt.ML.Tests`.

## 📖 Notes

- [Usage examples](docs/usage.md)
- [Numeric model](docs/numeric-model.md)
- [Package boundaries](docs/package-boundaries.md)
- [Migration status](docs/migration-status.md)
- [Hardware notes](docs/hardware-notes.md)
- [Streaming inference](docs/streaming.md)
- [TinyStories/GPT-Neo primitives](docs/tinystories-primitives.md)

Compiler bugs should be recorded only in `COMPILER.md`. Hardware tradeoffs and
implementation notes belong in `docs/`.

## 🚀 Outlook

`Livt.ML` 1.0.1 is a broad fixed-size package. Future work should add more
hardware-optimized variants, shared fixed-point helpers through `Livt.Math`,
and stronger model-weight loading patterns.

## 📄 License

This project is licensed under the MIT License. See [LICENSE](LICENSE).

## Generic wide fixed-point operators

Version 1.3.0-dev adds streamed INT4 projection, fixed-point RMSNorm, masked
softmax and lookup activation with explicit formats and injected storage.
See [contracts](docs/FixedPointOperators.md). Existing operator semantics are unchanged.

## Generic fixed-point transformer operations (1.4.0-dev)

`ITransformerKernels` and `FixedTransformerKernels` provide serialized embedding,
affine RMS normalization, matrix projection, unscaled masked attention with
relative position bias, table-driven activation/gating and residual addition.
Token/vector bounds, fixed-point formats, epsilon, external `IRam<int>` storage,
weights and activation tables are generic parameters. One worker can serve every
layer. This is a serial correctness implementation, not a throughput or FPGA
resource guarantee.

`QuantizedTensorWeights` selects immutable `ITensorCatalog` records and reads
low-nibble-first packed INT4 codes and unsigned scale words from external memory.
Addresses count int32 words except catalog packed-code addresses, which count
bytes. It handles unaligned byte offsets and flattened groups crossing matrix
rows. Invalid selection/reads latch a failure until a successful selection.

A kernel returns false on invalid dimensions, ranges, values or provider failure;
its destination may then contain partial writes and must be discarded. Input and
model spans must remain stable for the call. The memory provider must expose
contiguous valid ranges. Only residual addition permits exact input/output aliasing;
partial overlap is rejected. The caller owns serialization and result validity.
`FixedTransformerKernelsTest` covers a different Q8 format and shape from FLAN-T5,
including the deliberate lack of probability-sum correction.

## Incremental transformer operations (1.4.1-dev)

`IIncrementalTransformerKernels` extends the existing encoder interface with
single-query `CachedAttention` and `ProjectArgMax`; existing implementations of
`ITransformerKernels` need no changes. `FixedTransformerKernels` implements both
through interface inheritance and reuses its arithmetic and provider instances.

Cached attention takes an independent K/V length, query position, causal flag,
key mask and optional bias tensor. A bias ID of -1 disables bias. Bucket entries
are int32 words covering relative distances `-(MAX_TOKENS-1)..MAX_TOKENS-1`.
Masked/future K/V entries are not read. Scratch scores for excluded keys are
unspecified; their probabilities and contribution to context are zero.

Streaming projection supports up to 65,536 output rows independently of the
maximum vector width. It rounds and clips every complete dot product before
feeding `StreamingArgMax`, preserves lowest-index ties, and returns -1 on error.
It allocates no output-logit tensor. Tests cover a full 32,128-row scan, clipping
that creates a tie, poisoned masked/future cache entries, Q8 and existing kernel
contracts. Model cache addresses and lifecycle policy stay in application code.

## Scheduled integer division

[Division policy and migration status](docs/integer-division.md) describe the
shared Livt.Math quotient/remainder API and its use in transformer shape checks.
Runtime division is explicitly scheduled; compile-time arithmetic and existing
fixed-point rounding retain their own contracts.

The [arithmetic migration audit](docs/arithmetic-migration.md) records runtime
division changes, compatibility exceptions, and validation across base libraries.
