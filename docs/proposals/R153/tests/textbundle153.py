"""R153 perf: puts text files in a Luau module (the Luau command line has no file reading). Usage: python3 textbundle153.py <out.luau> name=path ..."""
import sys

out = sys.argv[1]
parts = []
for arg in sys.argv[2:]:
    name, _, path = arg.partition('=')
    text = open(path, encoding='utf-8').read()
    level = 1
    while (']' + '=' * level + ']') in text:
        level += 1
    eq = '=' * level
    parts.append('[%r]=[%s[\n%s]%s],' % (name, eq, text, eq))
open(out, 'w', encoding='utf-8').write('return {\n' + '\n'.join(parts) + '\n}\n')
