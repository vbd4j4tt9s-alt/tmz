--!nocheck
-- R158 design preview: prints walls158.lua's part lists as JSON lines for make158.py (one line per list):
--   SPECS <name> [ {Group, Name, Shape, Size, CF, Color, Material, Transparency, Mesh, Shadow}, ... ]
--   RESTYLE {path: {Color, Material}}     HIDE <option> [path prefixes]     BUDGET {list: parts}
-- Usage: /opt/luau/luau dump158.luau   (from any folder: walls158.lua is found next to this file)
local D=require('./walls158')
local function enc(v)
 local t=type(v)
 if t=='number'then
  if v~=v or v==math.huge or v==-math.huge then error('bad number')end
  if math.floor(v)==v and math.abs(v)<1e15 then return string.format('%d',v)end
  return string.format('%.5f',v):gsub('0+$',''):gsub('%.$','')
 elseif t=='string'then return'"'..v:gsub('\\','\\\\'):gsub('"','\\"')..'"'
 elseif t=='boolean'then return tostring(v)
 elseif t=='nil'then return'null'
 elseif t=='table'then
  if #v>0 or next(v)==nil then local o={};for i=1,#v do o[i]=enc(v[i])end;return'['..table.concat(o,',')..']'end
  local keys={};for k in pairs(v)do keys[#keys+1]=tostring(k)end;table.sort(keys)
  local o={};for _,k in ipairs(keys)do o[#o+1]=enc(k)..':'..enc(v[k])end;return'{'..table.concat(o,',')..'}'
 end
 error('cannot encode '..t)
end
local budget={}
local function emit(name,list)print('SPECS '..name..' '..enc(list));budget[name]=#list end
emit('walls',D.TrackWalls())
emit('walls_lite',D.TrackWalls({Lite=true}))
emit('backdrops',D.Backdrops())
for _,o in ipairs({'A','B','C'})do
 local list,hide=D.BaseWalls(o)
 emit('base'..o,list)
 print('HIDE base'..o..' '..enc(hide))
end
print('RESTYLE '..enc(D.Restyle()))
print('BIOMES '..enc(D.Biomes))
print('BASEOPTIONS '..enc(D.BaseOptions))
print('BUDGET '..enc(budget))
