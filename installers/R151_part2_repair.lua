-- R151 part 2 repair. Paste ALL of this into the Command Bar (Edit mode, Play stopped), Enter.
-- Part 2 refused with "Mixed script versions": some of its scripts are already the new version and some are still the old one
-- (usually a Studio undo / Ctrl+Z after an earlier paste, or an unsaved session). This puts every part-2 script back to its exact
-- old version from the part-2 backup, then installs part 2 again. It only uses the texts saved in ServerStorage.ChestChase_R151p2_Backup.
assert(not game:GetService('RunService'):IsRunning(),'[R151 repair] Stop Play first.')
local B=game.ServerStorage:FindFirstChild('ChestChase_R151p2_Backup')
assert(B,'[R151 repair] No ServerStorage.ChestChase_R151p2_Backup: paste installers/R151_install_part2.lua instead.')
local ses=game:GetService('ScriptEditorService')
local function load(e,n)
 local f=e:FindFirstChild(n);if not f then return nil end
 if f:IsA('StringValue')then return f.Value end
 local t={};for i=1,(f:GetAttribute('Chunks')or #f:GetChildren())do t[i]=f:FindFirstChild(tostring(i)).Value end
 return table.concat(t)
end
local fixes,bad={}, {}
for _,e in ipairs(B.Sources:GetChildren())do
 local t=e:FindFirstChild('Target');local item=t and t.Value;local path=e:GetAttribute('Path')
 if e:GetAttribute('New')then
  if not item then table.insert(bad,path..' (added script missing)')
  elseif item.Parent==e then print('[R151 repair] '..path..': not installed yet (ok)')
  else print('[R151 repair] '..path..': already in place -> parking it');table.insert(fixes,function()item.Parent=e end)end
 else
  local cur=item and ses:GetEditorSource(item);local before,after=load(e,'Before'),load(e,'After')
  if cur==before then print('[R151 repair] '..path..': old version (ok)')
  elseif cur==after then print('[R151 repair] '..path..': new version -> back to old');table.insert(fixes,function()ses:UpdateSourceAsync(item,function()return before end)end)
  else table.insert(bad,path..' (edited by hand: neither the old nor the new version)')end
 end
end
if #bad>0 then
 for _,b in ipairs(bad)do warn('[R151 repair] '..b)end
 error('[R151 repair] Stopped: send these lines to Claude. Nothing changed.')
end
for _,f in ipairs(fixes)do f()end
print('[R151 repair] '..#fixes..' script(s) reset; installing part 2 again...')
require(B.Installer)('install')
