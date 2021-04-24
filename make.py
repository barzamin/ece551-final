#!/usr/bin/env python3

from pathlib import Path
from typing import List
import subprocess
import argparse


basedir = Path(__file__).parent.resolve()
srcdir = basedir / 'src'
testdir = basedir / 'tests'
builddir = basedir / 'build'

QUESTA_BASE = Path('/cae/apps/data/mentor-2020/questasim')
QUESTA_BIN = QUESTA_BASE / 'bin'
tools = {
    'vsim': str(QUESTA_BIN / 'vsim'),
    'vlib': str(QUESTA_BIN / 'vlib'),
    'vlog': str(QUESTA_BIN / 'vlog'),
}

src_files = list(srcdir.glob('*.sv'))

def ensure_build_dirs():
    builddir.mkdir(exist_ok=True)
    (builddir/'questa').mkdir(exist_ok=True)

def collect_tests(dir: Path) -> List[Path]:
    return list(dir.glob('*_tb.sv'))

def create_vsim_lib(name, indir=None):
    subprocess.run([tools['vlib'], name], cwd=indir and str(indir), check=True)

def run(args, *aargs, **kwargs):
    print(' '.join(args))
    return subprocess.run(args, *aargs, **kwargs)

def testall():
    ensure_build_dirs()
    tests = collect_tests(testdir)

    create_vsim_lib('ece551tb', indir=builddir/'questa')

    subprocess.run([tools['vlog'], '-work', str(builddir/'questa'/'ece551tb'),
        *map(str, src_files),
        *map(str, tests)], check=True)

def main():
    parser = argparse.ArgumentParser(description='build system for ece551 final project')
    parser.add_argument('command', metavar='COMMAND')

    args = parser.parse_args()
    if args.command == 'synth':
        pass
    if args.command == 'testall':
        testall()
    else:
        raise Exception('invalid command {}'.format(args.command))

if __name__ == '__main__':
    main()
