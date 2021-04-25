#!/usr/bin/env python3

import os
import argparse
import subprocess
from pathlib import Path
from collections import namedtuple
from jinja2 import Template

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
simscript = testdir / 'sim.do'

questa_out = builddir/'questa'
synth_out = builddir/'synth'

QUESTA_BASE = Path('/cae/apps/data/mentor-2020/questasim')
QUESTA_BIN = QUESTA_BASE / 'bin'
QUESTA_ENVVARS = {
    'LM_LICENSE_FILE': '1717@mentor.license.cae.wisc.edu',
    'CALIBRE_SKIP_OS_CHECKS': '1',
    'MGC_AMS_HOME': '/cae/apps/data/mentor-2020',
    'PATH': os.getenv('PATH'),
}
TOOLS = {
    'vsim': str(QUESTA_BIN / 'vsim'),
    'vlib': str(QUESTA_BIN / 'vlib'),
    'vlog': str(QUESTA_BIN / 'vlog'),
    'design_vision': '/cae/apps/bin/design_vision', # this CAE spoofscript properly loads licensing and process libraries
}

src = {
    'rtl': list(srcdir.glob('*.sv')),
    'models': list((srcdir/'models').glob('*.sv')),
}


class Library:
    def __init__(self, name, basedir=None):
        self.name = name
        self.basedir = basedir and str(basedir)

    def init(self):
        try:
            subprocess.run([TOOLS['vlib'], self.name], cwd=self.basedir, check=True, env=QUESTA_ENVVARS)
        except subprocess.CalledProcessError as error:
            raise Exception('failed to create questasim library: {}', error.output)

    def build(self, sources):
        try:
            subprocess.run([TOOLS['vlog'],
                '-work', self.name,
                *map(str, sources)],
                cwd=self.basedir, check=True, env=QUESTA_ENVVARS)
        except subprocess.CalledProcessError as error:
            raise Exception('failed to compile test source: {}', error.output)

class VsimAssertionFail(Exception): pass
class VsimUnexpectedError(Exception): pass
class VsimElaborationError(Exception): pass
class VsimUnknownStatusCode(Exception):
    def __init__(self, statuscode):
        super().__init__()
        self.statuscode = statuscode

class Simulator:
    def __init__(self, library, toplevel):
        self.library = library
        self.toplevel = toplevel

    def simulate(self, *args):
        try:
            proc = self._exec(*args)
        except subprocess.CalledProcessError as err:
            if err.returncode == 1:
                raise VsimAssertionFail()
            elif err.returncode == 3:
                raise VsimUnexpectedError()
            elif err.returncode == 12:
                raise VsimElaborationError()
            else:
                raise VsimUnknownStatusCode(err.returncode)

    def _exec(self, *args):
        return subprocess.run([TOOLS['vsim'], '-batch',
                '-do', str(simscript),
                *args,
                '{}.{}'.format(self.library.name, self.toplevel)],
            cwd=str(questa_out),
            check=True, env=QUESTA_ENVVARS)

def ensure_build_dirs():
    builddir.mkdir(exist_ok=True)
    questa_out.mkdir(exist_ok=True)
    synth_out.mkdir(exist_ok=True)
    (synth_out/'reports').mkdir(exist_ok=True)

def collect_tests(dir):
    return list(dir.glob('*_tb.sv'))

def testall():
    ensure_build_dirs()
    tests = collect_tests(testdir)

    simlib = Library('ece551tb', basedir=questa_out)
    simlib.build(src['rtl'] + src['models'])

    passed = 0
    for test in tests:
        print(c.HEADER + '[-] running test {}'.format(test.stem) + c.RESET)
        try:
            Simulator(simlib, test.stem).simulate()
            print(c.BOLD + c.OKGREEN + '[*] test passed' + c.RESET)
            passed += 1
        except VsimAssertionFail as e:
            print(c.BOLD + c.FAIL + '[!] test failed: assertion failed' + c.RESET)
        except VsimElaborationError as e:
            print(c.FAIL + '[!] test failed: testbench elaboration failed' + c.RESET)
        except VsimUnexpectedError as e:
            print(c.FAIL + '[!] unexpected vsim error' + c.RESET)
        except VsimUnknownStatusCode as e:
            print(c.FAIL + '[!] unknown vsim return code {}'.format(e.statuscode) + c.RESET)

    print()
    print(c.OKBLUE + '[&] {}/{} tests passed'.format(passed, len(tests)))

def synth():
    ensure_build_dirs()
    with open(str(basedir / 'synth' / 'synthesize.dc')) as f:
        template = Template(f.read())

    buildscript = str(synth_out/'synthesize.dc')
    with open(buildscript, 'w') as f:
        f.write(template.render(sources=src['rtl']))

    subprocess.run([TOOLS['design_vision'], '-no_gui', '-shell', 'dc_shell',
            '-f', buildscript],
        cwd=str(synth_out), check=True)

def clean():
    subprocess.run(['rm', '-rf', 'build'])

def main():
    parser = argparse.ArgumentParser(description='build system for ece551 final project')
    parser.add_argument('command', metavar='COMMAND')

    args = parser.parse_args()
    if args.command == 'synth':
        synth()
    elif args.command == 'testall':
        testall()
    elif args.command == 'clean':
        clean()
    else:
        raise Exception('invalid command {}'.format(args.command))

if __name__ == '__main__':
    main()
