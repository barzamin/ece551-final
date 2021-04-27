#!/usr/bin/env python3

import os
import shutil
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

test_out = builddir/'questa'
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
    'vsim':   str(QUESTA_BIN / 'vsim'),
    'vlib':   str(QUESTA_BIN / 'vlib'),
    'vlog':   str(QUESTA_BIN / 'vlog'),
    'vcover': str(QUESTA_BIN / 'vcover'),
    'design_vision': '/cae/apps/bin/design_vision', # this CAE spoofscript properly loads licensing and process libraries
}

src = {
    'rtl': list(srcdir.glob('*.sv')),
    'models': list((srcdir/'models').glob('*.sv')),
    'testbenches': list(testdir.glob('*.sv'))
}


class Library:
    def __init__(self, name, basedir=None):
        self.name = name
        self.basedir = basedir and str(basedir)

    def init(self):
        try:
            subprocess.run([TOOLS['vlib'], self.name], cwd=self.basedir, check=True, env=QUESTA_ENVVARS)
        except subprocess.CalledProcessError as error:
            raise Exception('failed to create questasim library: {}'.format(error.output))

    def build(self, sources, *args):
        subprocess.run([TOOLS['vlog'],
            '-work', self.name,
            *args,
            *map(str, sources)],
            cwd=self.basedir, check=True, env=QUESTA_ENVVARS)

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

    def simulate(self, *args, **kwargs):
        try:
            proc = self._exec(
                *args,
                **kwargs)
        except subprocess.CalledProcessError as err:
            if err.returncode == 1:
                raise VsimAssertionFail()
            elif err.returncode == 3:
                raise VsimUnexpectedError()
            elif err.returncode == 12:
                raise VsimElaborationError()
            else:
                raise VsimUnknownStatusCode(err.returncode)

    def _exec(self, *args, do=None):
        do = do or ''
        do += ';do {}'.format(str(simscript))
        return subprocess.run([TOOLS['vsim'], '-batch',
                '-work', self.library.name,
                '-vopt', '-voptargs=+acc',
                '-do', do,
                *args,
                '{}.{}'.format(self.library.name, self.toplevel)],
            cwd=str(test_out),
            check=True, env=QUESTA_ENVVARS)

def ensure_build_dirs():
    builddir.mkdir(exist_ok=True)
    test_out.mkdir(exist_ok=True)
    (test_out/'coveragedbs').mkdir(exist_ok=True)
    synth_out.mkdir(exist_ok=True)
    (synth_out/'reports').mkdir(exist_ok=True)

def test(args):
    ensure_build_dirs()

    # copy test data
    for p in testdir.glob('*.hex'):
        shutil.copy(str(p), str(test_out))

    if args.test == []:
        tests = [p for p in src['testbenches'] if p.stem.endswith('_tb')]
    else:
        tests = [testdir / '{}.sv'.format(t) for t in args.test]

    simlib = Library('ece551tb', basedir=test_out)
    try:
        bargs = []
        if args.coverage:
            print(c.OKCYAN + '[-] building DUT with coverage enabled' + c.RESET)
            bargs += ['+cover=bcestf', '-coveropt', '3']
        simlib.build(src['rtl'], *bargs)
    except Exception as e:
        # print(c.BOLD + c.FAIL + '[#] failed to build DUT RTL. dying')
        # exit(1)
        raise e

    try:
        simlib.build(src['models'] + src['testbenches'])
    except Exception as e:
        print(c.BOLD + c.FAIL + '[#] failed to build models and/or testbenches. dying')
        exit(1)

    passed = 0
    for test in tests:
        print(c.HEADER + '[-] running test {}'.format(test.stem) + c.RESET)
        try:
            sargs = []
            do = None
            if args.vcd_all:
                do = 'vcd file {}.vcd; vcd add -r sim:/*; '.format(test.stem)
            if args.coverage:
                print(c.OKCYAN + '[-] run recording coverage data' + c.RESET)

                sargs += ['-coverage']

            Simulator(simlib, test.stem).simulate(*sargs, do=do)

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

    print(c.OKBLUE + '-'*32 + c.RESET)
    print(c.OKBLUE + '[&] {}/{} tests passed'.format(passed, len(tests))
        + (' (' + c.OKCYAN + 'recorded coverage data' + c.OKBLUE + ')' if args.coverage else '') + c.RESET)

def cover(args):
    shutil.rmtree(str(test_out/'coverage-report'), ignore_errors=True)
    subprocess.run([TOOLS['vcover'], 'merge',
            '-totals',
            '-out', str(test_out/'cover.ucdb'),
            str(test_out/'coverstore')],
        cwd=str(test_out), check=True)
    subprocess.run([TOOLS['vcover'], 'report',
            '-html',
            '-out', str(test_out/'coverage-report'),
            str(test_out/'cover.ucdb')],
        cwd=str(test_out), check=True)

def synth(args):
    ensure_build_dirs()
    with open(str(basedir / 'synth' / 'synthesize.dc')) as f:
        template = Template(f.read())

    buildscript = str(synth_out/'synthesize.dc')
    with open(buildscript, 'w') as f:
        f.write(template.render(sources=src['rtl']))

    subprocess.run([TOOLS['design_vision'], '-no_gui', '-shell', 'dc_shell',
            '-f', buildscript],
        cwd=str(synth_out), check=True)

def clean(args):
    shutil.rmtree(str(builddir), ignore_errors=True)

def main():
    parser = argparse.ArgumentParser(description='build system for ece551 final project')
    # parser.add_argument('command', metavar='COMMAND')
    subparsers = parser.add_subparsers(title='subcommands',
                                       description='tasks',
                                       dest='command')
    subparsers.required = True

    parser_tests = subparsers.add_parser('test')
    parser_tests.add_argument('test', nargs='*')
    parser_tests.add_argument('--vcd-all', action='store_true', help='dump all signals to a VCD file in the test builddir')
    parser_tests.add_argument('--coverage', action='store_true', help='collect coverage data')
    parser_tests.set_defaults(func=test)

    parser_synth = subparsers.add_parser('synth')
    parser_synth.set_defaults(func=synth)

    parser_cover = subparsers.add_parser('cover')
    parser_cover.set_defaults(func=cover)

    parser_clean = subparsers.add_parser('clean')
    parser_clean.set_defaults(func=clean)

    args = parser.parse_args()
    args.func(args)

if __name__ == '__main__':
    main()
