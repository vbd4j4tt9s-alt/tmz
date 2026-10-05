-- Prepare reusable approved meshes once for this server session.
local RS=game:GetService('ReplicatedStorage')
-- R149: the generated Watermelon / Snow Melon / Ember Pumpkin meshes bake alongside (they fall back to their part-built fruit and log once on failure).
task.spawn(function()local ok,why=pcall(function()return require(RS:WaitForChild('FruitMeshes149')).Prepare()end);if not ok then warn('[R149 fruit meshes] '..tostring(why))end end)
-- R151: the Verity pack's neutral (white vertex colour) copy of the standard pouch bakes alongside; the pack keeps its plain-parts sachet if that fails.
task.spawn(function()local ok,why=pcall(function()return require(RS:WaitForChild('VerityPouch151')).Prepare()end);if not ok then warn('[R151 Verity pouch] '..tostring(why))end end)
-- R151: the pack shape variations (PackShapes151) bake lazily at each design's first pack; loading the module now publishes ReplicatedStorage.PackShapeTemplates151 (the
-- status and the owner's /test packshape switches) before any client looks for them.
task.spawn(function()local ok,why=pcall(function()return require(RS:WaitForChild('PackShapes151'))end);if not ok then warn('[R151 pack shapes] '..tostring(why))end end)
local ok,ready,errors=pcall(function()return require(RS:WaitForChild('ApprovedPlantMeshes')).Prepare()end)
if not ok then warn('[R50 plants] '..tostring(ready))
elseif not ready then
 warn('[R50 plants] '..#errors..' mesh templates unavailable; other plants are ready. First failure: '..tostring(errors[1]))
end
