-- Edit-time helper called by the R42 Command Bar installer. No runtime asset downloads.
local Art=require(script.Parent.BatArt)
local C=require(game:GetService('ReplicatedStorage').BatConfig)
local M={}
function M.Install()
 assert(not game:GetService('RunService'):IsRunning(),'Stop Play before importing the bat appearance.')
 local storage=game:GetService('ServerStorage');local existing=storage:FindFirstChild(Art.TemplateName)
 if existing then
  assert(existing:IsA('Tool')and existing:GetAttribute('BatAppearanceAssetId')==C.AssetId
   and existing:GetAttribute('BatAppearanceVersion')==Art.Version,'A different bat appearance already occupies '..Art.TemplateName..'. It was preserved.')
  return existing
 end
 -- GetObjects is restricted to the Studio edit command. Originals stay unparented.
 local loaded=game:GetObjects('rbxassetid://'..C.AssetId)
 local clean;local okay,why=pcall(function()
  assert(#loaded==1,'Expected one bat asset root.')
  clean=Art.Sanitize(loaded[1],C.AssetId)
 end)
 for _,item in ipairs(loaded)do item:Destroy()end
 if not okay then if clean then clean:Destroy()end;error(why)end
 clean.Name=Art.TemplateName;clean.Parent=storage
 print('Bat appearance imported: '..C.AssetId..'. Save the place to retain it.')
 return clean
end
return M
