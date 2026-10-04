#!/usr/bin/env python3
"""Inject a shared reset after a real scratch write during generated attention.

Run livt test -r IncrementalTransformerKernelsTest first. Only simulation copies
are instrumented: a passive kernel monitor triggers the test clock provider's
reset. Production/generated source files are never modified.
"""
from pathlib import Path
import os
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'out/debug'
WORK = ROOT / 'out/scratch-reset'
WORK.mkdir(parents=True, exist_ok=True)
env = dict(os.environ)
env.pop('_JAVA_OPTIONS', None)
os.sched_setaffinity(0, sorted(os.sched_getaffinity(0))[:4])
ghdl = env.get('LIVT_GHDL_PATH') or shutil.which('ghdl')
if not ghdl:
    raise SystemExit('GHDL is required')
probe = WORK / 'scratch_reset_probe.vhd'
probe.write_text('''library ieee; use ieee.std_logic_1164.all;
package scratch_reset_probe is
 signal interrupt_requested : std_logic := '0';
end package;
''')
files = [probe]
kernel_count = provider_count = 0
for source in sorted(OUT.rglob('*.vhd')):
    text = source.read_text()
    if (source.name.startswith('Livt.ML.Transformer.FixedTransformerKernels_')
            and 'incrementalweights' in source.name and '.Package.' not in source.name):
        kernel_count += 1
        pos = text.rfind('\nend;')
        assert pos >= 0
        text = text[:pos] + '''
 scratch_reset_monitor: process(ctor_lvt_context_in.clk)
  variable wrote : boolean := false;
 begin
  if rising_edge(ctor_lvt_context_in.clk) then
   if this_attention_out.busy = '1' then
    if this_scratch_out.write.busy = '1' then wrote := true; end if;
    if wrote and this_scratch_out.write.busy = '0' then
     work.scratch_reset_probe.interrupt_requested <= '1';
    end if;
   end if;
  end if;
 end process;
''' + text[pos:]
        destination = WORK / source.name
        destination.write_text(text)
        files.append(destination)
    elif source.name == 'Livt.Lang.TestContextProvider.vhd':
        provider_count += 1
        pattern = r'(this_lvt_context_in\.rst <= \'0\';\s*)wait;'
        replacement = '''\\1wait until work.scratch_reset_probe.interrupt_requested = '1';
        wait for 2 ns;
        report "INJECT reset after scratch write during active attention";
        this_lvt_context_in.rst <= '1';
        wait for 100 ns;
        this_lvt_context_in.rst <= '0';
        wait;'''
        text, count = re.subn(pattern, replacement, text)
        assert count == 1, 'Test reset provider changed'
        destination = WORK / source.name
        destination.write_text(text)
        files.append(destination)
    else:
        files.append(source)
assert kernel_count == provider_count == 1, (kernel_count, provider_count)
entity = 'livt_ml_tests_incrementaltransformerkernelstest'
commands = [[ghdl, '-i', '--std=08', *map(str, files)],
            [ghdl, '-m', '--std=08', entity]]
for mode in ['false', 'true']:
    commands.append([ghdl, '-r', '--std=08', entity,
                     '-glivt_test_filter=SharedScratchReuseAfterFailure',
                     f'-gLVT_RESET_ASYNC={mode}', '--assert-level=error', '--stop-time=5ms'])
for index, command in enumerate(commands):
    with (WORK / f'command-{index}.log').open('w') as log:
        subprocess.run(command, cwd=WORK, env=env, stdout=log,
                       stderr=subprocess.STDOUT, check=True, timeout=300)
    if index >= 2:
        text = (WORK / f'command-{index}.log').read_text()
        assert 'INJECT reset after scratch write' in text, 'Reset was never injected'
        assert 'Simulation finished' in text, 'Numerical test did not finish after reset'
print('PASS shared scratch reset during attention: synchronous and asynchronous')
