# Integer division integration validation — 2026-09-30

All 119 Livt.ML tests passed, with zero failures or skipped tests, in 619.80 seconds.
The suite includes the new QuantizedTensorShapeTest overflow boundaries and
recovery checks, plus existing fixed and incremental transformer regressions.
See [JUnit results](ml-all.xml) and [source hashes](source-sha256.json).

Validation used GHDL 4.1.0, the installed Livt compiler, and an isolated project
copy with a local Livt.Math dependency containing the new scheduled division API.
The checked-in registry dependency was unchanged. The final source differs from
the tested snapshot only in comments; the final manifest additionally enables
variable-divisor warnings. No package was published.

Reproduce in a development copy with the local Math dependency described in
[the integration policy](../../integer-division.md), then run `livt test`.
This is functional simulation evidence, not full-model synthesis or routed timing.
The Math package retains separate divider synthesis and reset evidence.
