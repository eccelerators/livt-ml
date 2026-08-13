# Package Boundaries

`Livt.ML` is the package for reusable machine-learning components written in
Livt.

## Belongs In Livt.ML

- fixed-size ML linear algebra layers, such as `VecAdd`, `DotProduct`,
  `MatrixVectorMultiplication`, and quantized linear layers
- fixed-shape quantized convolution and pooling operators whose parameters are
  configured by an application rather than embedded in the package
- bounded streaming engines and their vendor-neutral handshake contracts;
  model-specific weights remain in the application or generated model wrapper
- ML-specific quantization contracts and requantization components
- activation functions and approximations, such as `ReLU`, `SigmoidLUT`,
  `SiLUApprox`, and `SoftmaxApprox`
- ML normalization layers, such as `RMSNorm`
- attention building blocks, such as `KVCache` and
  `ScaledDotProductAttention`
- reusable model helpers, such as `LinearRegression`
- transformer-style composition components that only depend on reusable ML
  layers

## Belongs In Livt.Math

- arithmetic primitives that are useful outside ML
- square root implementations
- multiply-accumulate helpers
- future fixed-point, saturating arithmetic, clamp, min, max, and small numeric
  helper components

## Belongs Elsewhere

- FFT, FIR, and similar DSP components should become signal-processing packages
  rather than base `Livt.ML` components.
- Crypto primitives belong in `Livt.Crypto`.

## Dependency Direction

`Livt.ML` depends on published `Livt.Math 0.4.0` and uses `Livt.IO 0.2.0` for
opaque RAM-backed tensor storage.
`Livt.Math` and `Livt.IO` must not depend on `Livt.ML`.

```text
Livt.Math
   ^
   |
Livt.ML

Livt.IO
   ^
   |
Livt.ML.Storage
```

Packages should only depend on `Livt.Math` directly when they use math
primitives themselves.

## API Stability

Numeric helpers, fixed-shape tensor operators, RAM-backed variants, and
streaming primitives form the stable inference foundation. `ClassProjection`,
`ScaledDotProductAttention`, and `TransformerBlock` are experimental
compositions until an imported language model validates their configuration,
state, and framing contracts end to end.
