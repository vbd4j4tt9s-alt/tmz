"""R156 preview: R153's dump_tree153.luau draws no TextBox, so the Bag's Search box was missing from every picture. This writes a copy that also dumps a TextBox
(its Text, or its PlaceholderText in the placeholder colour while it is empty) and a Color3 stub for a label without a stroke colour.
Usage: python3 patch_dump156.py IN.luau OUT.luau"""
import sys

src = open(sys.argv[1], encoding='utf-8').read()
EDITS = [
    ("local GUI={Frame=true,", "local GUI={TextBox=true,Frame=true,"),
    ("local isText=o.ClassName=='TextLabel'or o.ClassName=='TextButton'",
     "local isText=o.ClassName=='TextLabel'or o.ClassName=='TextButton'or o.ClassName=='TextBox'\n"
     " local txt,col=o.Text,o.TextColor3;if o.ClassName=='TextBox'and(txt==nil or txt=='')then txt,col=o.PlaceholderText,o.PlaceholderColor3 or col end"),
    ("if isText and o.Text and o.Text~=''then", "if isText and txt and txt~=''then"),
    ("q(o.Text),", "q(txt),"),
    ("c3(o.TextColor3 or Color3.new(0,0,0))", "c3(col or Color3.new(0,0,0))"),
]
for old, new in EDITS:
    assert src.count(old) == 1, 'dump_tree153.luau changed: %r found %d times' % (old, src.count(old))
    src = src.replace(old, new)
stub = "local Color3={new=function(r,g,b)return {R=r,G=g,B=b}end} -- (a label without a stroke colour)\n"
open(sys.argv[2], 'w', encoding='utf-8').write(stub + src)
