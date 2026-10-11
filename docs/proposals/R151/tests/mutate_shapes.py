"""R151: breaks a copy of the pack shape code in one specific way, so run_pack_shapes.sh --mutations can prove the tests notice it.
Usage: python3 mutate_shapes.py <src dir (a COPY: it is edited in place)> <mutation name | list | kind NAME>
Each mutation says which check must notice it: 'shapes' (test_pack_shapes.luau), 'server' (test_pack_shapes_server.luau) or 'static' (check_shape_plumbing.py)."""
import os
import sys

src, name = sys.argv[1], sys.argv[2]
RS = 'ReplicatedStorage/'
SV = 'ServerScriptService/ChestChaseServer/'
CL = 'StarterPlayer/StarterPlayerScripts/'

# name: (kind, file, old, new)
M = {
    # --- the field
    'crimp_moves': ('shapes', RS + 'PackShapes151.lua', 'local function body(v)return 1-ss(.80,.94,math.abs(v))end', 'local function body(v)return 1-ss(.80,1.3,math.abs(v))end'),
    'y_moves': ('shapes', RS + 'PackShapes151.lua', ' return u*sx,v,w*sz', ' return u*sx,v*1.02,w*sz'),
    'grows_too_much': ('shapes', RS + 'PackShapes151.lua', 'return 1-.04*b,1+.05*b end', 'return 1-.04*b,1+.12*b end'),
    # --- the roll
    'roll_never_six': ('shapes', RS + 'PackShapes151.lua', 'id=math.min(M.Count,math.floor(math.clamp(u,0,1)*M.Count)+1)', 'id=math.min(M.Count,math.floor(math.clamp(u,0,1)*(M.Count-1))+1)'),
    'void_takes_shape': ('shapes', RS + 'PackShapes151.lua', "if type(variantKey)~='string'or variantKey=='EclipseReliquary'or variantKey=='MechLimited'or variantKey==", "if type(variantKey)~='string'or false and variantKey=='EclipseReliquary'or variantKey=='MechLimited'or variantKey=="),
    # R152: the Verity pack takes a shape again (it rolls, carries and builds one)
    'verity_takes_shape': ('shapes', RS + 'PackShapes151.lua', "or variantKey==require(script.Parent.VerityCatalog).Variant then return false end", " then return false end"),
    'roll_ignores_force': ('shapes', RS + 'PackShapes151.lua', ' local id=mode\n', ' local id=nil\n'),
    # --- the bake
    'prints_whitened': ('shapes', RS + 'PackShapes151.lua', '  if neutral then\n   colors=editable:GetColors()', '  if true then\n   colors=editable:GetColors()'),
    'editable_leak': ('shapes', RS + 'PackShapes151.lua', "if editable then pcall(function()editable:Destroy()end)end", ''),
    'hard_coded_id': ('shapes', RS + 'PackShapes151.lua', 'local meshId=source.MeshId', "local meshId='rbxassetid://75504658868908'"),
    'frame_not_following': ('shapes', RS + 'PackShapes151.lua', 'local newFrame=d.Magnitude<1e-6 and frame or frame*CFrame.new(d.X,d.Y,d.Z)', 'local newFrame=frame'),
    'size_not_updated': ('shapes', RS + 'PackShapes151.lua', 'part.Name=source.Name;part.Size=info.Size', 'part.Name=source.Name;part.Size=source.Size'),
    'not_one_at_a_time': ('shapes', RS + 'PackShapes151.lua', ' if current then return end', ' '),
    # --- builds never yield / sticky / settle
    'build_waits': ('shapes', RS + 'PackShapes151.lua', " local s=M.Request(key,shape,neutral)\n if s=='Ready'then return M.Template(key,shape,neutral),shape end",
                    " local s=M.Request(key,shape,neutral)\n if s=='Loading'and not(Run:IsClient()and not Run:IsServer())then task.wait()end\n if s=='Ready'then return M.Template(key,shape,neutral),shape end"),
    'client_does_not_wait': ('shapes', RS + 'PackShapes151.lua', "if s=='Loading'and Run:IsClient()and not Run:IsServer()then error('Pack shape is still loading',0)end", ''),
    'failure_not_sticky': ('shapes', RS + 'PackShapes151.lua', "local bad=failed[pair];if bad then return'Off',bad.Reason end", "local bad=nil;if bad then return'Off',bad.Reason end"),
    'settle_keeps_cold_roll': ('shapes', RS + 'PackShapes151.lua', " if M.Request(key,shape,neutral,true)=='Ready'then return shape end\n stats.Demoted+=1;publish();return 0", " M.Request(key,shape,neutral,true);return shape"),
    'off_ignored': ('shapes', RS + 'PackShapes151.lua', "if off then return'off'end", "if false then return'off'end"),
    # --- the budget
    'never_evicts': ('shapes', RS + 'PackShapes151.lua', ' while resident>limit do', ' while false do'),
    'evicts_newest': ('shapes', RS + 'PackShapes151.lua', "and(not oldest or e.Last<oldest.Last)then oldest=e end", "and(not oldest or e.Last>oldest.Last)then oldest=e end"),
    'evicts_pinned': ('shapes', RS + 'PackShapes151.lua', "if pair~=keep and not pins[pair]and(force", "if pair~=keep and(force"),
    'ignores_grace': ('shapes', RS + 'PackShapes151.lua', "(force or now-e.Last>=M.Config.GraceSeconds)", "(true)"),
    # a world without the EditableMesh API warns (a stray warning in every older suite)
    'unavailable_warns': ('shapes', RS + 'PackShapes151.lua', "if not warned and not reason:find(M.Unavailable,1,true)then warned=true;", "if not warned then warned=true;"),
    'never_sweeps': ('shapes', RS + 'PackShapes151.lua', "if not pins[pair]and now-e.Last>=M.Config.IdleSeconds then remove(pair)end", "local _=pair"),
    'over_budget_kept': ('shapes', RS + 'PackShapes151.lua', "if resident>M.Config.HardResidentVertices then\n  local e=cache[pair]", "if false then\n  local e=cache[pair]"),
    'no_budget_guard': ('shapes', RS + 'PackShapes151.lua', "assert(resident<M.Config.HardResidentVertices,", "assert(true or resident<M.Config.HardResidentVertices,"),
    # --- the record and the journey
    'addchest_rerolls_default': ('server', SV + 'PlayerDataService.lua', 'if shape == nil then shape = PackShapes.Roll(chest.BagVariant) end', 'if shape == nil or shape == 0 then shape = PackShapes.Roll(chest.BagVariant) end'),
    'addchest_gives_void_a_shape': ('server', SV + 'PlayerDataService.lua', 'if shape > 0 and PackShapes.Applies(chest.BagVariant) then record.PackShape = shape end', 'if shape > 0 then record.PackShape = shape end'),
    'record_not_saved': ('server', SV + 'PlayerDataService.lua', 'PackShape=savedPackShape(chestRecord),', 'PackShape=nil,'),
    'record_not_loaded': ('server', SV + 'PlayerDataService.lua', 'PackShape=savedPackShape(savedChest),', 'PackShape=nil,'),
    'seed_keeps_shape': ('server', SV + 'PlayerDataService.lua', 'if row.Kind ~= "Pack" or not PackShapes.Applies(', 'if not PackShapes.Applies('),
    # R152: an older Verity record keeps the shape R151 rolled for it; a Verity pack handed a shape keeps it
    'verity_record_keeps_shape': ('server', SV + 'PlayerDataService.lua', ' or not PackShapes.Applies(PackRules.VariantKey(row.BagVariant)) then return nil end', ' then return nil end'),
    'verity_addchest_keeps_shape': ('server', SV + 'PlayerDataService.lua', 'if shape > 0 and PackShapes.Applies(chest.BagVariant) then record.PackShape = shape end', 'if shape > 0 then record.PackShape = shape end'),
    'spawn_not_stored': ('server', SV + 'ChestService.lua', '    seed.PackShape=shape -- R151\n', '    seed.PackShape=nil -- R151\n'),
    'spawn_not_pinned': ('server', SV + 'ChestService.lua', 'if shape and shape>0 then PackShapes.Pin(seed,', 'if false then PackShapes.Pin(seed,'),
    'spawn_keeps_cold_roll': ('server', SV + 'ChestService.lua', 'shape=PackShapes.Settle(design,rolledShape~=nil and rolledShape or PackShapes.Roll(variant))', 'shape=rolledShape~=nil and rolledShape or PackShapes.Roll(variant)'),
    'plan_not_ahead': ('server', SV + 'ChestService.lua', '    if ok then self.WorldPlan=upcoming end', '    if ok then self.WorldPlan=nil end'),
    'plan_not_prefetched': ('server', SV + 'ChestService.lua', '    pcall(PackShapes.Prefetch,wanted)\n', ''),
    'carry_drops_shape': ('server', SV + 'ChaseService.lua', 'chest.PackMutation,chest.PackShape) -- R151', 'chest.PackMutation) -- R151'),
    'drop_drops_shape': ('server', SV + 'ChaseService.lua', 'chest.PackMutation,chest.PackShape)\n    require(ReplicatedStorage.ItemEffectAnchor).Set(packet', 'chest.PackMutation)\n    require(ReplicatedStorage.ItemEffectAnchor).Set(packet'),
    'tool_has_no_shape': ('server', SV + 'ChestService.lua', 'if shape>0 then tool:SetAttribute("PackShape",shape) end', 'if false then tool:SetAttribute("PackShape",shape) end'),
    'hand_has_no_shape': ('server', SV + 'ChestService.lua', 'tool:GetAttribute("PackMutation"),shape)', 'tool:GetAttribute("PackMutation"))'),
    'hand_does_not_wait': ('server', SV + 'ChestService.lua', '            pcall(PackShapes.Await,design,shape,neutral)\n', ''),
    'mystery_silhouette_shaped': ('server', SV + 'MysteryPackService.lua', "state=='Ready'and shape or nil)\n end)", "shape)\n end)"),
    'mystery_not_given': ('server', SV + 'MysteryPackService.lua', 'PackShape=shape},{Luck=true})', 'PackShape=nil},{Luck=true})'),
    # --- the picture keys, the builders, the stack
    'picture_key_ignores_shape': ('server', RS + 'ItemPictures.lua', "table.concat(shape>0 and{'Pack',stage,variant,mutation,shape}or{'Pack',stage,variant,mutation},'|')", "table.concat({'Pack',stage,variant,mutation},'|')"),
    'picture_ignores_shape': ('shapes', RS + 'ItemPictures.lua', "spec.Mutation,nil,spec.Plain,spec.Shape)", "spec.Mutation,nil,spec.Plain)"),
    'bag_tags_every_pack': ('shapes', RS + 'SeedPackVisuals.lua', 'if shape~=nil then local Shapes=require(script.Parent.PackShapes151)', 'if true then local Shapes=require(script.Parent.PackShapes151)'),
    'renderer_ignores_shape': ('shapes', RS + 'SeedPackRenderer.lua', "    if shape~=nil then\n        local shown;", "    if false then\n        local shown;"),
    # --- the default shape (DefaultPackShape): the catalogue, shop and reward pictures, the market stalls
    'flag_does_not_win': ('shapes', RS + 'SeedPackVisuals.lua', "if defaultShape==true then m:SetAttribute('DefaultPackShape',true)\n    elseif shape~=nil then", "if defaultShape==true then m:SetAttribute('DefaultPackShape',true) end\n    if shape~=nil then"),
    'renderer_ignores_flag': ('shapes', RS + 'SeedPackRenderer.lua', "local shape=bag:GetAttribute('DefaultPackShape')~=true and bag:GetAttribute('PackShape')or nil", "local shape=bag:GetAttribute('PackShape')"),
    # R152: the Verity builder requires PackShapes151 again (it must never)
    'verity_uses_shapes': ('static', RS + 'VerityPackArt.lua', "local Config=require(script.Parent.VerityConfig)", "local Config=require(script.Parent.VerityConfig);local Shapes=require(script.Parent.PackShapes151)"),
    'picture_flag_keeps_roll': ('shapes', RS + 'ItemPictures.lua', "local shape=tool:GetAttribute('DefaultPackShape')==true and 0 or shapes().Sanitize(tool:GetAttribute('PackShape'))", "local shape=shapes().Sanitize(tool:GetAttribute('PackShape'))"),
    'picture_flag_not_passed': ('shapes', RS + 'ItemPictures.lua', "spec.Mutation,nil,spec.Plain,spec.Shape)", "spec.Mutation,nil,nil,spec.Shape)"),
    'market_not_default': ('static', SV + 'MarketLayout.lua', "spec.Variant,1,1,'None',nil,true)", "spec.Variant,1,1,'None')"),
    'viewport_not_default': ('static', RS + 'PackViewport89.lua', "'MechLimited',1,1,'None',nil,true)", "'MechLimited',1,1,'None')"),
    'stack_mixes_shapes': ('static', CL + 'Hotbar.client.lua', ",'SeedScale','PackShape'}", ",'SeedScale'}"),
    'catalogue_shows_a_roll': ('static', RS + 'TitleScreen104.lua', "visuals.Bag(CFrame.Angles(0,.15,-.12),world,1,nil,1,'Pack06',1,1,'None')", "visuals.Bag(CFrame.Angles(0,.15,-.12),world,1,nil,1,'Pack06',1,1,'None',nil,PackShape)"),
}
if name == 'list':
    print(' '.join(M))
    sys.exit(0)
if name == 'kind':
    print(M[sys.argv[3]][0])
    sys.exit(0)
kind, file, old, new = M[name]
path = os.path.join(src, file)
text = open(path, encoding='utf-8').read()
assert text.count(old) == 1, (name, file, text.count(old), old[:70])
open(path, 'w', encoding='utf-8').write(text.replace(old, new, 1))
print('ok')
