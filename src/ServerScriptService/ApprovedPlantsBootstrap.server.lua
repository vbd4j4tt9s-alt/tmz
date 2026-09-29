-- Prepare reusable approved meshes once for this server session.
local RS=game:GetService('ReplicatedStorage')
local ok,ready,errors=pcall(function()return require(RS:WaitForChild('ApprovedPlantMeshes')).Prepare()end)
if not ok then warn('[R50 plants] '..tostring(ready))
elseif not ready then
 warn('[R50 plants] '..#errors..' mesh templates unavailable; other plants are ready. First failure: '..tostring(errors[1]))
end
