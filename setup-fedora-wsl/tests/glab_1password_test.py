import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
WRAPPER = ROOT / 'setup-fedora-wsl/config/glab-graphwise/glab-1password'
FUNCTION = ROOT / 'setup-fedora-wsl/config/glab-graphwise/glab.fish'


class GlabTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.config = self.home / '.config/glab-1password/graphwise.json'
        self.config.parent.mkdir(parents=True)
        self.bin = self.home / 'bin'
        self.bin.mkdir()
        self.op = self.bin / 'op.exe'
        self.op.write_text('''#!/usr/bin/python3
import os, sys
from pathlib import Path
Path(os.environ['HOME'], 'op-called').touch()
assert sys.argv[1:] == ['read', '--no-newline', 'op://vault/item/token']
mode = os.environ.get('TEST_OP_MODE', 'success')
if mode == 'failure':
    print('fixture-secret', file=sys.stderr)
    sys.exit(1)
sys.stdout.buffer.write(b'' if mode == 'empty' else b'fixture-secret\\r\\n')
''')
        self.op.chmod(0o700)
        glab = self.home / '.local/share/mise/shims/glab'
        glab.parent.mkdir(parents=True)
        glab.write_text('''#!/usr/bin/python3
import json, os, sys
from pathlib import Path
Path(os.environ['HOME'], 'glab-called').touch()
print(json.dumps({'args': sys.argv[1:], 'authenticated': os.environ.get('GITLAB_TOKEN') == 'fixture-secret', 'host': os.environ.get('GITLAB_HOST')}))
sys.exit(int(os.environ.get('TEST_GLAB_STATUS', '0')))
''')
        glab.chmod(0o700)
        (self.bin / 'glab').symlink_to(glab)
        self.helper = self.home / '.local/bin/glab-1password'
        self.helper.parent.mkdir(parents=True)
        shutil.copyfile(WRAPPER, self.helper)
        self.helper.chmod(0o700)
        self.config.write_text(json.dumps({'op_executable': str(self.op), 'secret_reference': 'op://vault/item/token', 'host': 'gitlab.example.com'}))
        self.env = {k: v for k, v in os.environ.items() if k not in ('GITLAB_TOKEN', 'GITLAB_ACCESS_TOKEN', 'OAUTH_TOKEN', 'GITLAB_HOST')}
        self.env.update(HOME=str(self.home), XDG_CONFIG_HOME=str(self.home / '.config'), PATH=str(self.bin) + ':/usr/bin:/bin', WSL_DISTRO_NAME='test')

    def invoke(self, *args, fish=False, cwd=None):
        command = ['fish', '--no-config', '-c', 'source "$argv[1]"; glab $argv[2..-1]', str(FUNCTION), *args] if fish else [str(self.helper), *args]
        return subprocess.run(command, env=self.env, capture_output=True, text=True, cwd=cwd or self.home)

    def add_paths(self, *paths):
        config = json.loads(self.config.read_text())
        config['paths'] = list(paths)
        self.config.write_text(json.dumps(config))

    def test_auto_profile_applies_to_nested_worktrees(self):
        self.add_paths('~/workspace/gitlab.example.com')
        worktree = self.home / 'workspace/gitlab.example.com/group/project/.paperclip/worktrees/task'
        worktree.mkdir(parents=True)
        result = self.invoke('mr', 'list', fish=True, cwd=worktree)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(json.loads(result.stdout)['authenticated'])

    def test_similar_directory_name_does_not_match(self):
        self.add_paths('~/workspace/gitlab.example.com')
        other = self.home / 'workspace/gitlab.example.com-other'
        other.mkdir(parents=True)
        result = self.invoke('mr', 'list', fish=True, cwd=other)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse((self.home / 'op-called').exists())

    def test_longest_path_wins_and_explicit_profile_overrides_it(self):
        self.add_paths('~/workspace')
        personal = json.loads(self.config.read_text())
        personal.update(host='personal.example.com', paths=['~/workspace/personal'])
        (self.config.parent / 'personal.json').write_text(json.dumps(personal))
        directory = self.home / 'workspace/personal/repo'
        directory.mkdir(parents=True)
        result = self.invoke('mr', 'list', fish=True, cwd=directory)
        self.assertEqual(json.loads(result.stdout)['host'], 'personal.example.com')
        result = self.invoke('--graphwise', 'mr', 'list', fish=True, cwd=directory)
        self.assertEqual(json.loads(result.stdout)['host'], 'gitlab.example.com')
        result = self.invoke('--profile', 'personal', 'mr', 'list', fish=True)
        self.assertEqual(json.loads(result.stdout)['host'], 'personal.example.com')

    def test_unknown_profile_does_not_fall_back(self):
        result = self.invoke('--profile', 'missing', 'mr', 'list', fish=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.home / 'glab-called').exists())

    def test_ambiguous_path_fails_without_reading_vault(self):
        self.add_paths(str(self.home))
        (self.config.parent / 'personal.json').write_bytes(self.config.read_bytes())
        result = self.invoke('mr', 'list', fish=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.home / 'op-called').exists())
        self.assertFalse((self.home / 'glab-called').exists())

    def test_explicit_repository_or_host_skips_path_selection(self):
        self.add_paths(str(self.home))
        for args in (('mr', 'list', '--repo', 'other.example.com/group/repo'), ('api', 'user', '--hostname=other.example.com')):
            result = self.invoke(*args, fish=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertFalse((self.home / 'op-called').exists())
        result = self.invoke('--graphwise', 'mr', 'list', '--repo', 'gitlab.example.com/group/repo', fish=True)
        self.assertTrue(json.loads(result.stdout)['authenticated'])

    def test_failed_automatic_lookup_never_falls_back(self):
        self.add_paths(str(self.home))
        self.env['TEST_OP_MODE'] = 'failure'
        result = self.invoke('mr', 'list', fish=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.home / 'glab-called').exists())

    def test_explicit_graphwise_flag_passes_token_and_preserves_arguments(self):
        result = self.invoke('--graphwise', 'mr', 'list', '--search', 'two words', fish=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout), {'args': ['mr', 'list', '--search', 'two words'], 'authenticated': True, 'host': 'gitlab.example.com'})
        self.assertNotIn('fixture-secret', result.stdout + result.stderr)

    def test_plain_glab_never_reads_1password_even_when_configured(self):
        result = self.invoke('mr', 'list', fish=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(json.loads(result.stdout)['authenticated'])
        self.assertFalse((self.home / 'op-called').exists())

    def test_failed_or_empty_lookup_never_runs_glab(self):
        for mode in ('failure', 'empty'):
            with self.subTest(mode=mode):
                self.env['TEST_OP_MODE'] = mode
                result = self.invoke('--graphwise', 'mr', 'list', fish=True)
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse((self.home / 'glab-called').exists())
                self.assertNotIn('fixture-secret', result.stdout + result.stderr)

    def test_missing_configuration_never_runs_glab(self):
        self.config.unlink()
        result = self.invoke('--graphwise', 'mr', 'list', fish=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.home / 'op-called').exists())
        self.assertFalse((self.home / 'glab-called').exists())

    def test_opt_in_requires_wsl_but_plain_glab_still_works(self):
        self.env.pop('WSL_DISTRO_NAME')
        result = self.invoke('--graphwise', 'mr', 'list', fish=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.home / 'op-called').exists())
        self.assertEqual(self.invoke('--version', fish=True).returncode, 0)

    def test_reinstall_preserves_local_profile_without_reading_vault(self):
        before = self.config.read_bytes()
        package = ROOT / 'setup-fedora-wsl/packages/glab-graphwise.sh'
        for _ in range(2):
            result = subprocess.run(['bash', str(package)], env=self.env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(self.config.read_bytes(), before)
            self.assertEqual(self.helper.read_bytes(), WRAPPER.read_bytes())
            function = self.home / '.config/fish/functions/glab.fish'
            self.assertEqual(function.read_bytes(), FUNCTION.read_bytes())
            self.assertFalse((self.home / 'op-called').exists())

    def test_preserves_glab_exit_status(self):
        self.env['TEST_GLAB_STATUS'] = '7'
        self.assertEqual(self.invoke('mr', 'list').returncode, 7)


class InstallerRoutingTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.setup = self.root / 'setup-fedora-wsl'
        (self.setup / 'lib').mkdir(parents=True)
        (self.setup / 'packages').mkdir()
        (self.root / 'dotfiles').mkdir()
        shutil.copyfile(ROOT / 'setup-fedora-wsl/install.sh', self.setup / 'install.sh')
        (self.setup / 'lib/utils.sh').write_text("""BOLD= GREEN= RESET=
log_info() { :; }
log_success() { :; }
log_step() { :; }
log_warn() { :; }
log_error() { echo "$*" >&2; }
assert_not_root() { :; }
assert_dnf() { :; }
is_wsl() { return 0; }
is_installed() { command -v "$1" >/dev/null; }
run_step() { shift; "$@"; }
""")
        for name in ('base', 'mise', 'languages', 'claude', 'agents', 'paperclip', 'glab-graphwise'):
            (self.setup / 'packages' / (name + '.sh')).write_text('echo ' + name + ' >> "$HOME/steps"\n')
        bins = self.root / 'bin'
        bins.mkdir()
        for name in ('rpm', 'git', 'chezmoi'):
            script = bins / name
            script.write_text('#!/bin/sh\nexit 0\n')
            script.chmod(0o700)
        self.env = dict(os.environ, HOME=str(self.root), PATH=str(bins) + ':/usr/bin:/bin')

    def run_installer(self, *args):
        return subprocess.run(['bash', str(self.setup / 'install.sh'), *args], env=self.env, capture_output=True, text=True)

    def test_default_all_and_dotfiles_never_install_graphwise(self):
        for args in ((), ('--all',), ('--dotfiles',)):
            with self.subTest(args=args):
                result = self.run_installer(*args)
                self.assertEqual(result.returncode, 0, result.stderr)
                steps = self.root / 'steps'
                self.assertNotIn('glab-graphwise', steps.read_text() if steps.exists() else '')

    def test_explicit_flag_installs_only_graphwise(self):
        result = self.run_installer('--glab-graphwise')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.root / 'steps').read_text().splitlines(), ['glab-graphwise'])


if __name__ == '__main__':
    unittest.main()
