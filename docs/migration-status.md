# Migration Status

This document tracks the single-component or experimental repositories that
have been folded into `Livt.ML` or deliberately left elsewhere.

## Migrated To Livt.ML

| Source project | New location |
| --- | --- |
| `livt-vector-addition` | `Livt.ML.Linear.VecAdd` |
| `livt-dot-product` | `Livt.ML.Linear.DotProduct` |
| `livt-matrix-vector-multiplication` | `Livt.ML.Linear.MatrixVectorMultiplication` |
| `livt-relu` | `Livt.ML.Activation.ReLU` |
| `livt-sigmoid-lut` | `Livt.ML.Activation.SigmoidLUT` |
| `livt-silu` | `Livt.ML.Activation.SiLUApprox` |
| `livt-softmax` | `Livt.ML.Activation.SoftmaxApprox` |
| `livt-rms-norm` | `Livt.ML.Norm.RMSNorm` |
| `livt-kv-cache` | `Livt.ML.Attention.KVCache` |
| `livt-scaled-dot-product-attention` | `Livt.ML.Attention.ScaledDotProductAttention` |
| `livt-transformer-block` | `Livt.ML.Transformer.TransformerBlock` |
| `livt-linear-regression` | `Livt.ML.Model.LinearRegression` |

## Added Directly In Livt.ML

| Component | Reason |
| --- | --- |
| `Livt.ML.Linear.Linear8x8` | reusable dense projection for small fixed-size models |
| `Livt.ML.Transformer.FeedForwardBlock` | reusable two-layer FFN block for later transformer work |

## Migrated To Livt.Math

| Source project | New location |
| --- | --- |
| `livt-square-root` | `Livt.Math.Sqrt.SqrtLUT`, `Livt.Math.Sqrt.SqrtNewtonRaphson` |
| `livt-mac-unit` | `Livt.Math.Arithmetic.MacUnit` |

## Deliberately Not Migrated To Livt.ML

| Project | Reason |
| --- | --- |
| `livt-ethernet-frame-classifier` | application/domain package; consumes `Livt.ML` |
| `livt-fft-app` | signal-processing/application package |
| `livt-fir-filter` | signal-processing package |
| `livt-llm` | Python training/reference project |
| `livt-rag` | Python application/reference project |

## Follow-Up Before Publishing

- publish `Livt.ML`
- decide what to do with the old single-component repositories: archive,
  deprecate, or keep as examples
- review variable-divider hardware warnings in `RMSNorm`, `SoftmaxApprox`,
  `LinearRegression`, and `SqrtNewtonRaphson`
