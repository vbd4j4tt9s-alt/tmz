"""Build a Rojo-style sourcemap.json from src/MANIFEST.tsv so luau-lsp can resolve requires."""
import json, sys, os
root = sys.argv[1] if len(sys.argv) > 1 else 'src'
rows = [l.rstrip('\n').split('\t') for l in open(os.path.join(root, 'MANIFEST.tsv'), encoding='utf-8')][1:]
services = {'ReplicatedStorage', 'ServerScriptService', 'StarterPlayer', 'ReplicatedFirst', 'Workspace', 'StarterGui', 'StarterPack', 'ServerStorage'}
tree = {'name': 'Game', 'className': 'DataModel', 'children': []}
def node(parent, name, cls):
    for c in parent['children']:
        if c['name'] == name: 
            if cls != 'Folder': c['className'] = cls
            return c
    c = {'name': name, 'className': cls, 'children': []}; parent['children'].append(c); return c
for cls, path, f in rows:
    parts = path.split('/'); cur = tree
    for i, p in enumerate(parts):
        last = i == len(parts) - 1
        kind = cls if last else (p if i == 0 and p in services else ('StarterPlayerScripts' if p == 'StarterPlayerScripts' else 'Folder'))
        cur = node(cur, p, kind)
    cur['filePaths'] = [os.path.join(root, f)]
json.dump(tree, open('sourcemap.json', 'w'), indent=1)
print('ok', len(rows))
