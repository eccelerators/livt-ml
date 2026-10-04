#!/usr/bin/env python3
"""Run focused scratch regressions after Livt has generated the library tests.

Uses existing out/debug VHDL. Rebuild with livt test after source changes; this
runner deliberately excludes the unrelated 32K-vocabulary argmax simulation.
Run under the project's normal build memory guard when available.
"""
from pathlib import Path
import os
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / 'out/scratch-focused'
WORK.mkdir(parents=True, exist_ok=True)
env = dict(os.environ)
env.pop('_JAVA_OPTIONS', None)
os.sched_setaffinity(0, sorted(os.sched_getaffinity(0))[:4])
ghdl = env.get('LIVT_GHDL_PATH') or shutil.which('ghdl')
if not ghdl:
    raise SystemExit('GHDL is required')
files = list((ROOT / 'out/debug').rglob('*.vhd'))
subprocess.run([ghdl, '-i', '--std=08', *map(str, files)], cwd=WORK, env=env, check=True)
cases = [('fixedtransformerkernelstest', ''),
         ('incrementaltransformerkernelstest', 'CausalDoesNotReadFutureAndCrossMasks'),
         ('incrementaltransformerkernelstest', 'SharedScratchReuseAfterFailure'),
         ('transformerscratchcapacitytest', '')]
for index, (name, case) in enumerate(cases):
    entity = 'livt_ml_tests_' + name
    subprocess.run([ghdl, '-m', '--std=08', entity], cwd=WORK, env=env,
                   check=True, timeout=120)
    command = [ghdl, '-r', '--std=08', entity,
               '--assert-level=error', '--stop-time=5ms']
    if case:
        command.insert(4, '-glivt_test_filter=' + case)
    result = subprocess.run(command, cwd=WORK, env=env, capture_output=True,
                            text=True, check=True, timeout=120)
    (WORK / f'case-{index}.log').write_text(result.stdout + result.stderr)
    print(result.stdout, flush=True)
    assert 'Simulation finished' in result.stdout, 'Test did not finish'
print('PASS focused transformer scratch: rounding/shape, masks, reuse/failure, capacity')
