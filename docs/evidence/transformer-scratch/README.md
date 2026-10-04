# RAM-backed transformer scratch validation

The focused tests pass for the source hashes in `validation.json`:
shape/rounding, causal masks, full-capacity scratch reuse across both attention
methods, failure recovery, and undersized scratch rejection.

The reset runner injects shared reset after a real scratch write while attention
is active, then checks the restarted numerical scenario. Both synchronous and
asynchronous reset pass. Only isolated simulation copies receive the passive
monitor and reset stimulus; production sources are unchanged by the runner.

Run `livt test -r FixedTransformerKernelsTest` to regenerate tests, then
`scripts/test_transformer_scratch.py` and `scripts/test_transformer_scratch_reset.py`
with Python 3. Keep the normal CPU/memory guard for compilation/simulation.

An initial broader IncrementalTransformerKernelsTest run included the unrelated
32K-row argmax test and was explicitly interrupted. The focused runs replace
that run for this change; the full library suite has not been claimed as passed.

Hardware area/latch evidence belongs to the Tang project's TM-FLAN-007A archive.
