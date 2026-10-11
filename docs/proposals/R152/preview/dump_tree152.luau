--!nocheck
-- R152 preview helper: R150's dump_tree.luau (docs/proposals/R150/preview/dump_tree.luau, unchanged there) plus the images R152 draws on the
-- client: an ImageLabel whose ImageContent is one of RarePullArt's images ("r152art://<name>" in the preview) gets
-- "img":{"name","color","a"} so render_gui152.mjs can draw it (tinted by ImageColor3, faded by ImageTransparency).
local base=require('./dump_tree')
local function num(v)
 if v==nil then return'null'end
 if v~=v or v==math.huge or v==-math.huge then return'0'end
 local s=string.format('%.3f',v):gsub('0+$',''):gsub('%.$','')
 return s==''and'0'or s
end
local function c3(c)return c and string.format('[%d,%d,%d]',math.floor(c.R*255+.5),math.floor(c.G*255+.5),math.floor(c.B*255+.5))or'null'end
-- the art images are given as hidden marker children the base dump does not know; instead: dump, then splice the images in by node order
return function(root,W,H)
 -- every GUI node in the order the base dump walks them (depth first, children in order, GUI classes only)
 local GUI={Frame=true,TextLabel=true,TextButton=true,ImageLabel=true,ImageButton=true,ScrollingFrame=true,CanvasGroup=true,ViewportFrame=true}
 local order={}
 local function walk(o)for _,c in ipairs(o:GetChildren())do if GUI[c.ClassName]then order[#order+1]=c;walk(c)end end end
 walk(root)
 local json=base(root,W,H)
 -- the base writes every node as {"n":...; insert "img" right after the n-th node's opening
 local i=0
 json=json:gsub('{"n":',function()
  i+=1;local o=order[i]
  local content=o and o.ClassName=='ImageLabel'and rawget(o,'_props').ImageContent
  local name=type(content)=='string'and content:match('^r152art://(.+)$')
  if name and o.Visible~=false then
   return string.format('{"img":{"name":"%s","color":%s,"a":%s},"n":',name,c3(o.ImageColor3),num(o.ImageTransparency or 0))
  end
  return'{"n":'
 end)
 return json
end
