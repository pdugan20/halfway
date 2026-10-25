"""Exercise publication boundaries with a fake gh CLI; never call GitHub."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class ReleaseWorkflowTests(unittest.TestCase):
    def run_publish(self, releases, *, api_fails=False, upload_fails=False):
        with tempfile.TemporaryDirectory(prefix="halfway-release-test-") as directory:
            path = Path(directory)
            (path / "releases.json").write_text(json.dumps([releases]))
            gh = path / "gh"
            gh.write_text("""#!/usr/bin/env python3
import os
from pathlib import Path
import sys
root = Path(os.environ['FIXTURE_ROOT'])
args = sys.argv[1:]
with (root / 'calls').open('a') as file:
    file.write(' '.join(args) + '\\n')
if args[0] == 'api':
    if os.environ['API_FAILS'] == '1':
        sys.exit(1)
    print((root / 'releases.json').read_text())
elif args[:2] == ['release', 'upload'] and os.environ['UPLOAD_FAILS'] == '1':
    sys.exit(1)
""")
            gh.chmod(0o755)
            env = dict(os.environ, PATH=f"{path}:{os.environ['PATH']}", FIXTURE_ROOT=str(path),
                       API_FAILS=str(int(api_fails)), UPLOAD_FAILS=str(int(upload_fails)))
            result = subprocess.run([str(ROOT / "scripts/publish-release"), "v1.2.0", "fixture.dmg", "appcast.xml"],
                                    env=env, text=True, capture_output=True)
            calls = (path / "calls").read_text()
            return result.returncode, calls

    def test_new_release_uploads_before_publication(self):
        code, calls = self.run_publish([])
        self.assertEqual(code, 0)
        self.assertLess(calls.index("release create"), calls.index("release upload"))
        self.assertLess(calls.index("release upload"), calls.index("release edit"))
        self.assertIn("--draft --generate-notes", calls)

    def test_draft_resumes_without_recreating(self):
        code, calls = self.run_publish([dict(tag_name="v1.2.0", draft=True, prerelease=False)])
        self.assertEqual(code, 0)
        self.assertNotIn("release create", calls)
        self.assertIn("release upload", calls)

    def test_older_version_cannot_replace_the_feed(self):
        code, calls = self.run_publish([dict(tag_name="v1.3.0", draft=False, prerelease=False)])
        self.assertNotEqual(code, 0)
        self.assertNotIn("release edit", calls)
        self.assertNotIn("release upload", calls)

    def test_published_version_is_immutable(self):
        code, calls = self.run_publish([dict(tag_name="v1.2.0", draft=False, prerelease=False)])
        self.assertNotEqual(code, 0)
        self.assertNotIn("release upload", calls)

    def test_api_failure_cannot_publish(self):
        code, calls = self.run_publish([], api_fails=True)
        self.assertNotEqual(code, 0)
        self.assertNotIn("release create", calls)

    def test_failed_upload_cannot_publish(self):
        code, calls = self.run_publish([], upload_fails=True)
        self.assertNotEqual(code, 0)
        self.assertNotIn("release edit", calls)


if __name__ == "__main__":
    unittest.main()
