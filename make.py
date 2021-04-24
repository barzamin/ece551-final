#!/usr/bin/env python3

from pathlib import Path
from typing import List
import subprocess
import argparse
import os

class c:
    HEADER    = '\033[95m'
    OKBLUE    = '\033[94m'
    OKCYAN    = '\033[96m'
    OKGREEN   = '\033[92m'
    WARNING   = '\033[93m'
    FAIL      = '\033[91m'
    RESET     = '\033[0m'
    BOLD      = '\033[1m'
    UNDERLINE = '\033[4m'

basedir = Path(__file__).parent.resolve()
srcdir = basedir / 'src'
testdir = basedir / 'tests'
builddir = basedir / 'build'

QUESTA_BASE = Path('/cae/apps/data/mentor-2020/questasim')
QUESTA_BIN = QUESTA_BASE / 'bin'
QUESTA_ENVVARS = {
    'LM_LICENSE_FILE': '1717@mentor.license.cae.wisc.edu',
    'CALIBRE_SKIP_OS_CHECKS': '1',
    'MGC_AMS_HOME': '/cae/apps/data/mentor-2020',
    'PATH': os.getenv('PATH'),
}
questa_out = builddir/'questa'
questa_work_lib = questa_out/'ece551tb'
tools = {
    'vsim': str(QUESTA_BIN / 'vsim'),
    'vlib': str(QUESTA_BIN / 'vlib'),
    'vlog': str(QUESTA_BIN / 'vlog'),
}

src_files = list(srcdir.glob('*.sv'))

def ensure_build_dirs():
    builddir.mkdir(exist_ok=True)
    (questa_out).mkdir(exist_ok=True)

def collect_tests(dir: Path) -> List[Path]:
    return list(dir.glob('*_tb.sv'))

def create_vsim_lib(name, indir=None):
    subprocess.run([tools['vlib'], name], cwd=indir and str(indir), check=True, env=QUESTA_ENVVARS)

def run(args, *aargs, **kwargs):
    print(' '.join(args))
    return subprocess.run(args, *aargs, **kwargs)

def questa_build(sources):
    subprocess.run([tools['vlog'],
        '-work', str(questa_work_lib),
        *map(str, sources)], check=True, env=QUESTA_ENVVARS)

def testall():
    ensure_build_dirs()
    tests = collect_tests(testdir)

    create_vsim_lib('ece551tb', indir=questa_out)
    questa_build(src_files + tests)

    for test in tests:
        print(c.HEADER + '[-] running test {}'.format(test.stem) + c.RESET)
        # assume module name is just the filename with extension stripped off
        module = test.stem
        sim_command = 'run -all'

        try:
            # TODO: handle stop, error counts
            subprocess.run([tools['vsim'], '-batch',
                    '-work', str(questa_work_lib),
                    '-do', sim_command,
                    '-vopt', 'ece551tb.{}'.format(module)],
                cwd=str(questa_out),
                # shell=True,
                check=True, env=QUESTA_ENVVARS)
        except subprocess.CalledProcessError as e:
            print(c.FAIL + '[!] test failed: `vsim` exited with {}'.format(e.returncode))

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
