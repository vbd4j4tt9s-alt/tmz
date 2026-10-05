-- V123. Clone the approved artwork as uploaded, reusable MeshParts.
-- No runtime mesh generation, triangle Parts, or distance-based art replacement.
local Storage=game:GetService('ReplicatedStorage')
local Renderer={}
function Renderer.GetGeometry(key)
    local assets=Storage:FindFirstChild('SeedPackMeshAssets')
    local model=assets and assets:FindFirstChild(key)
    if model and model:GetAttribute('MeshBakeVersion')==123 then return model end
    return nil
end
function Renderer.Clear(bag)
    local old=bag:FindFirstChild('NativePackArt');if old then old:Destroy() end
    bag:SetAttribute('NativePackArtReady',nil)
end
function Renderer.Build(bag,isValid)
    if bag:GetAttribute('BagVariant')=='EclipseReliquary'then return require(script.Parent.EclipsePackArt).Build(bag)end
    if bag:GetAttribute('BagVariant')==require(script.Parent.VerityCatalog).Variant then return require(script.Parent.VerityPackArt).Build(bag,isValid)end -- R149: the pure yellow pouch with Verity's face (VerityPackArt)
    if bag:GetAttribute('BagVariant')=='MechLimited'then
        if bag:GetAttribute('CompactPackReady')then return true end
        return require(script.Parent.MechArt).Pack(bag)
    end
    -- R151: an ordinary design's pouch takes its shape variation (PackShapes151): the reshaped template when it is baked, else (variations off, a failed bake, a
    -- client that is not ready) nil, i.e. the place's own mesh. The Void, the Mech, the special packs and the Verity pack never come through here.
    if bag:GetAttribute('CompactPackReady') and bag:FindFirstChild('PackGeometry') then return true end
    -- (a bag flagged DefaultPackShape, a picture that must show the plain pouch, is built from the design's own mesh: no variation is asked for, nothing is baked)
    local key=bag:GetAttribute('PackArtKey')or''
    return Renderer.BuildStandard(bag,key,isValid,bag:GetAttribute('DefaultPackShape')~=true and require(script.Parent.PackShapes151).ForBuild(key) or nil)
end
-- R151: `template` (optional) is a template Model to build from instead of the place's own (VerityPackArt passes the neutral Verity pouch, a clone of
-- Storm_02 with white vertex colours); everything else is the same code, so such a pack is built exactly like a plain one.
function Renderer.BuildStandard(bag,key,isValid,template)
    if bag:GetAttribute('CompactPackReady') and bag:FindFirstChild('PackGeometry') then return true end
    local root=bag.PrimaryPart
    template=template or Renderer.GetGeometry(key)
    assert(root and template,'[V123] Missing approved pack mesh. Finish the V123 installer in Edit mode first.')
    local folder=Instance.new('Folder');folder.Name='PackGeometry'
    local scale=bag:GetAttribute('VisualScale') or 1
    local count=0
    for _,source in ipairs(template:GetChildren()) do
        if isValid and not isValid() then folder:Destroy();return false end
        if source:IsA('MeshPart') then
            local p=source:Clone()
            local frame=source:GetAttribute('PackLocalFrame')
            assert(typeof(frame)=='CFrame','[V123] Invalid mesh frame: '..source.Name)
            frame=CFrame.new(frame.Position*scale)*frame.Rotation
            p.Size=source.Size*scale;p.CFrame=root.CFrame*frame
            p.Anchored=root.Anchored;p.Massless=true
            p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
            p:SetAttribute('PackLocalFrame',frame)
            if not p.Anchored then
                local w=Instance.new('WeldConstraint');w.Part0=root;w.Part1=p;w.Parent=p
            end
            if (bag:GetAttribute('PackSize')or 1)>10 then game:GetService('CollectionService'):AddTag(p,'GiantVisualPart')end
            p.Parent=folder;count+=1
        end
    end
    assert(count==template:GetAttribute('MeshCount') and count>0,'[V123] Incomplete mesh template')
    if isValid and not isValid() then folder:Destroy();return false end
    count+=require(script.Parent.PackTierEmblem).Build(folder,root,key,template,scale)
    folder.Parent=bag
    bag:SetAttribute('CompactPackPartCount',count+10)
    bag:SetAttribute('CompactPackReady',true)
    return true
end
return Renderer
