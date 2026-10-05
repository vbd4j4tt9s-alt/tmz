"""Usage: python3 dump_verity_pouch.py [out.obj] [width height depth]   (default: the Storm_02 pouch, 1.97 x 2.06 x 1.004 studs, DepthShare of the depth)

Runs the REAL VerityPouch151.Generate (src/ReplicatedStorage/VerityPouch151.lua) on the Luau interpreter (/opt/luau/luau, the module wrapped in a few stub globals: Generate is pure data)
and writes the mesh it makes as a Wavefront OBJ (vertices, the module's own vertex normals, triangles): what the game bakes into the Verity pack's MeshPart, so the Blender
preview (../blender/verity_pack.py) draws the game's actual geometry. Prints the mesh's counts and bounding box."""
import os, subprocess, sys, tempfile
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '..', '..', '..', '..'))
out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, '..', 'verity_pouch.obj')
W, H, D = (float(x) for x in sys.argv[2:5]) if len(sys.argv) >= 5 else (1.97, 2.06, 1.004)
src = open(os.path.join(REPO, 'src', 'ReplicatedStorage', 'VerityPouch151.lua'), encoding='utf-8').read()
pre = '''--!nocheck
local fakeRun={IsServer=function()return false end,IsClient=function()return true end}
game={GetService=function(_,n)if n=='RunService'then return fakeRun end;return {FindFirstChild=function()return nil end}end}
Color3={new=function(r,g,b)return{R=r,G=g,B=b}end}
script={Parent={}}
local M=(function()
'''
post = '''
end)()
local d=M.Generate(%r,%r,%r*M.DepthShare)
local out={}
for _,p in ipairs(d.Vertices)do out[#out+1]=string.format('v %%.7f %%.7f %%.7f',p[1],p[2],p[3])end
for _,n in ipairs(d.Normals)do out[#out+1]=string.format('vn %%.7f %%.7f %%.7f',n[1],n[2],n[3])end
for _,t in ipairs(d.Faces)do out[#out+1]=string.format('f %%d//%%d %%d//%%d %%d//%%d',t[1],t[1],t[2],t[2],t[3],t[3])end
print(table.concat(out,'\\n'))
''' % (W, H, D)
with tempfile.NamedTemporaryFile('w', suffix='.luau', delete=False) as f:
    f.write(pre + src + post)
    path = f.name
try:
    res = subprocess.run([os.environ.get('LUAU', '/opt/luau/luau'), path], capture_output=True, text=True, check=True)
finally:
    os.unlink(path)
with open(out, 'w', encoding='utf-8') as f:
    f.write('# VerityPouch151.Generate(%g, %g, %g * DepthShare)\n' % (W, H, D) + res.stdout)
lines = res.stdout.split('\n')
nv = sum(1 for l in lines if l.startswith('v '))
nf = sum(1 for l in lines if l.startswith('f '))
xs = [tuple(float(c) for c in l.split()[1:]) for l in lines if l.startswith('v ')]
lo = [min(v[i] for v in xs) for i in range(3)]
hi = [max(v[i] for v in xs) for i in range(3)]
print('%d vertices, %d triangles; bounding box %s .. %s -> %s' % (nv, nf, [round(x, 4) for x in lo], [round(x, 4) for x in hi], out))
