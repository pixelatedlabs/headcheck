# This is free and unencumbered software released into the public domain.

import subprocess, sys

# Read arguments passed from Zig build.
path = sys.argv[1]
version = sys.argv[2]

# Too few arguments.
res = subprocess.run([path], capture_output=True, text=True)
assert res.returncode == 2
assert res.stdout == 'usage: headcheck <url>\n'

# Too many arguments.
res = subprocess.run([path, 'foo', 'bar'], capture_output=True, text=True)
assert res.returncode == 2
assert res.stdout == 'usage: headcheck <url>\n'

# Invalid URL.
res = subprocess.run([path, 'baz'], capture_output=True, text=True)
assert res.returncode == 2
assert res.stdout == 'unparseable: baz\n'

# Valid URL with successful response.
res = subprocess.run([path, 'http://www.google.com'], capture_output=True, text=True)
assert res.returncode == 0
assert res.stdout == 'success: 200\n'

# Valid URL with unsuccessful response.
res = subprocess.run([path, 'http://google.com'], capture_output=True, text=True)
assert res.returncode == 1
assert res.stdout == 'failure: 301\n'

# Help text.
res = subprocess.run([path, '--help'], capture_output=True, text=True)
assert res.returncode == 0
assert res.stdout == 'docs: https://pixelatedlabs.com/headcheck\n'

# Version text.
res = subprocess.run([path, '--version'], capture_output=True, text=True)
assert res.returncode == 0
assert res.stdout == f'version: {version}\n'

print("all tests passed")
