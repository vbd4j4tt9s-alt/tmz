-- Prepare reusable approved meshes once for this server session.
local RS=game:GetService('ReplicatedStorage')
-- R149: the generated Watermelon / Snow Melon / Ember Pumpkin meshes bake alongside (they fall back to their part-built fruit and log once on failure).
task.spawn(function()local ok,why=pcall(function()return require(RS:WaitForChild('FruitMeshes149')).Prepare()end);if not ok then warn('[R149 fruit meshes] '..tostring(why))end end)
local ok,ready,errors=pcall(function()return require(RS:WaitForChild('ApprovedPlantMeshes')).Prepare()end)
if not ok then warn('[R50 plants] '..tostring(ready))
elseif not ready then
 warn('[R50 plants] '..#errors..' mesh templates unavailable; other plants are ready. First failure: '..tostring(errors[1]))
end
