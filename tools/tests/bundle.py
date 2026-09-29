"""bundle.py OUT name=path ... -> Luau module returning {name=source} with safe long brackets."""
import sys
out, pairs = sys.argv[1], sys.argv[2:]
parts = ['return {']
for p in pairs:
    name, path = p.split('=', 1)
    src = open(path, 'rb').read().decode('utf-8')
    level = 1
    while (']' + '=' * level + ']') in src: level += 1
    eq = '=' * level
    parts.append(f'[{name!r}]=[{eq}[\n{src}]{eq}],'.replace("'", '"', 2))
parts.append('}')
open(out, 'w', encoding='utf-8').write('\n'.join(parts))
