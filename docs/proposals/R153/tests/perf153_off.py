"""R153 performance patch, switched off: a copy of a src tree with the patch's code changes undone (perf153.patch, next to this file, applied in
reverse), for run_perf153.sh's default comparison (this checkout as it is against the same checkout without the patch). Both sides then have the
same texts and whatever lands later; only the patch differs. The 73 retired dead files stay retired on both sides: nothing loads them.
Usage: python3 perf153_off.py <src dir> <out dir> (out gets a full copy of src).

R154: the two owner-approved bigger wins that came after it (B1: parts under 1.5 studs cast no shadow; B3: phones' keyboard letters at 12 px / stud and 56 rows
ahead; docs/proposals/R154/tests/perf154.patch) are undone FIRST, so the "off" side is the R153 release's own code: the comparison then shows what R153's
patch AND R154's two changes make, and perf154_opts.luau lets exactly B1 and B3 differ. R154_KEEP=1 leaves them on the off side (the R153 patch alone).

A hunk that does not apply stops the run (exit 1): the patched code was edited since; regenerate perf153.patch (perf153.md, "Tests") / perf154.patch (perf154.md)."""
import os, shutil, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
PATCH = os.path.join(HERE, 'perf153.patch')
PATCH154 = os.path.normpath(os.path.join(HERE, '..', '..', 'R154', 'tests', 'perf154.patch'))


def undo(out, patch, what):
    args = ['patch', '-R', '-p2', '-d', out, '-s', '-t', '-N', '-F', '1', '--no-backup-if-mismatch', '-r', '-', '-i', patch]
    dry = subprocess.run(args[:1] + ['--dry-run'] + args[1:], capture_output=True, text=True)
    if dry.returncode != 0:
        print('perf153_off: %s no longer undoes its change cleanly (the code was edited since; regenerate it):' % os.path.basename(patch))
        print((dry.stdout + dry.stderr).strip()[:2000])
        sys.exit(1)
    done = subprocess.run(args, capture_output=True, text=True)
    if done.returncode != 0:
        print('perf153_off: patch failed:', (done.stdout + done.stderr).strip()[:2000])
        sys.exit(1)
    files = [l[6:].strip() for l in open(patch, encoding='utf-8') if l.startswith('+++ b/')]
    print('perf153_off: %s undone in %d files' % (what, len(files)))


def main():
    src, out = sys.argv[1], sys.argv[2]
    if os.path.exists(out):
        shutil.rmtree(out)
    shutil.copytree(src, out)
    if os.path.exists(PATCH154) and not os.environ.get('R154_KEEP'):
        undo(out, PATCH154, 'R154 B1 + B3')
    undo(out, PATCH, 'the R153 perf patch')
    print('perf153_off: done (%s)' % out)


if __name__ == '__main__':
    main()
