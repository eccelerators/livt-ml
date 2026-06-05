# Package Boundaries

`Livt.ML` is the package for reusable machine-learning components written in
Livt.

## Belongs In Livt.ML

- fixed-size ML linear algebra layers, such as `VecAdd`, `DotProduct`, and
  `MatrixVectorMultiplication`
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

`Livt.ML` depends on published `Livt.Math 0.2.0`, but `Livt.Math` should not
depend on `Livt.ML`.

```text
Livt.Math
   ^
   |
Livt.ML
```

Packages should only depend on `Livt.Math` directly when they use math
primitives themselves.
