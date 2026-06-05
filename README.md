# Livt.ML

Fixed-size machine-learning building blocks for Livt hardware-oriented designs.

`Livt.ML` provides small, explicit components for integer vectors, activation
functions, embeddings, attention, normalization, transformer-style composition,
and simple fitted models. The package is intentionally concrete rather than
generic: APIs expose fixed sizes, stored outputs, and visible scale factors so
generated hardware remains easy to inspect.

## 📦 Package

```toml
[dependencies]
"Livt.ML" = "0.1.0"
```

`Livt.ML` depends on `Livt.Math` for reusable arithmetic primitives such as
integer square root.

## 📚 API Overview

| Namespace | Component | Purpose |
|---|---|---|
| `Livt.ML.Linear` | `VecAdd` | Adds two 8-element integer vectors |
| `Livt.ML.Linear` | `DotProduct` | Computes an 8-element dot product with positive saturation |
| `Livt.ML.Linear` | `MatrixVectorMultiplication` | Applies a 4 by 8 integer matrix to a vector |
| `Livt.ML.Linear` | `Linear8x8` | Applies an 8 by 8 integer matrix to a vector |
| `Livt.ML.Activation` | `ReLU` | Stateless integer ReLU |
| `Livt.ML.Activation` | `SigmoidLUT` | 256-entry sigmoid lookup table |
| `Livt.ML.Activation` | `SiLUApprox` | 8-element SiLU approximation |
| `Livt.ML.Activation` | `SoftmaxApprox` | 8-element scaled softmax approximation |
| `Livt.ML.Norm` | `RMSNorm` | 8-element integer RMS normalization |
| `Livt.ML.Embedding` | `FixedTokenEmbedding` | Mutable 16 by 8 integer embedding table |
| `Livt.ML.Attention` | `KVCache` | Four-slot key/value cache |
| `Livt.ML.Attention` | `ScaledDotProductAttention` | Attention over the fixed key/value cache |
| `Livt.ML.Classifier` | `ArgMax3` | Deterministic argmax for three logits |
| `Livt.ML.Classifier` | `ClassProjection` | Small fixed projection from 8 features to 3 logits |
| `Livt.ML.Transformer` | `FeedForwardBlock` | Two-layer 8-element feed-forward block |
| `Livt.ML.Transformer` | `TransformerBlock` | Compact transformer-style composition block |
| `Livt.ML.Model` | `LinearRegression` | Fits and evaluates a small integer linear model |

Most stateful components follow the same call shape: configure any stored
weights or tables, call `Compute(...)`, then read results with `GetOutput(...)`.
Out-of-range getters return `0`; out-of-range setters ignore the write.

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

The 0.1.0 API uses fixed-size `int` vectors, mostly `int[8]`. Several
components expose integer scale constants:

- `SigmoidLUT`, `SiLUApprox`, and `SoftmaxApprox` use scaled integer
  approximations.
- `ScaledDotProductAttention` uses explicit score and weight scale constants.
- `LinearRegression` stores the fitted slope as `aFixed`, scaled by
  `LinearRegression.SCALE`.
- `DotProduct.ACC_MAX` defines the positive saturation limit used by the linear
  projection components.

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
src/linear/       vector addition, dot products, and dense projections
src/activation/   ReLU, sigmoid LUT, SiLU approximation, and softmax approximation
src/norm/         RMSNorm
src/embedding/    fixed token embedding table
src/attention/    KV cache and scaled dot-product attention
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
- [Package boundaries](docs/package-boundaries.md)
- [Migration status](docs/migration-status.md)
- [Hardware notes](docs/hardware-notes.md)

Compiler bugs should be recorded only in `COMPILER.md`. Hardware tradeoffs and
implementation notes belong in `docs/`.

## 🚀 Outlook

`Livt.ML` 0.1.0 is a broad fixed-size package. Future work should add more
hardware-optimized variants, shared fixed-point helpers through `Livt.Math`,
and stronger model-weight loading patterns.

## 📄 License

This project is licensed under the MIT License. See [LICENSE](LICENSE).
