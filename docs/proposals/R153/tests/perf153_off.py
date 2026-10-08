"""R153 performance patch, switched off: a copy of a src tree with the patch's code changes undone (perf153.patch, next to this file, applied in
reverse), for run_perf153.sh's default comparison (this checkout as it is against the same checkout without the patch). Both sides then have the
same texts and whatever lands later; only the patch differs. The 73 retired dead files stay retired on both sides: nothing loads them.
Usage: python3 perf153_off.py <src dir> <out dir> (out gets a full copy of src).

A hunk that does not apply stops the run (exit 1): the patched code was edited since; regenerate perf153.patch (perf153.md, "Tests")."""
import os, shutil, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
PATCH = os.path.join(HERE, 'perf153.patch')


def main():
    src, out = sys.argv[1], sys.argv[2]
    if os.path.exists(out):
        shutil.rmtree(out)
    shutil.copytree(src, out)
    files = [l[6:].strip() for l in open(PATCH, encoding='utf-8') if l.startswith('+++ b/')]
    args = ['patch', '-R', '-p2', '-d', out, '-s', '-t', '-N', '-F', '1', '--no-backup-if-mismatch', '-r', '-', '-i', PATCH]
    dry = subprocess.run(args[:1] + ['--dry-run'] + args[1:], capture_output=True, text=True)
    if dry.returncode != 0:
        print('perf153_off: perf153.patch no longer undoes the patch cleanly (the code was edited since; regenerate it):')
        print((dry.stdout + dry.stderr).strip()[:2000])
        sys.exit(1)
    done = subprocess.run(args, capture_output=True, text=True)
    if done.returncode != 0:
        print('perf153_off: patch failed:', (done.stdout + done.stderr).strip()[:2000])
        sys.exit(1)
    print('perf153_off: the R153 perf patch undone in %d files (%s)' % (len(files), out))


if __name__ == '__main__':
    main()
