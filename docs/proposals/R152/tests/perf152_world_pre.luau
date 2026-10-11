-- (perf152_world.py) the published pack meshes and a Clone that keeps attributes and the PrimaryPart, as on Roblox
require('./fixtures').packAssets(W)
do
 local raw=R.Inst.Clone
 local function pathTo(root,target)
  local path={};local x=target
  while x and x~=root do local p=x._parent;if not p then return nil end;for i,c in ipairs(p._children)do if c==x then table.insert(path,1,i)end end;x=p end
  if x~=root then return nil end;return path
 end
 function R.Inst.Clone(self)
  local c=raw(self)
  local function attrs(a,b)for k,v in pairs(a._attrs)do b._attrs[k]=v end;for i,ch in ipairs(a._children)do if b._children[i]then attrs(ch,b._children[i])end end end
  attrs(self,c)
  local pp=self._props.PrimaryPart
  if pp then local path=pathTo(self,pp);if path then local t=c;for _,i in ipairs(path)do t=t._children[i]end;c._props.PrimaryPart=t end end
  return c
 end
end
