-- Bounded one-shot spatial audio, independent of all music controllers.
local Debris=game:GetService('Debris')
local Content=game:GetService('ContentProvider')
local SoundService=game:GetService('SoundService')
local Timing=require(script.Parent.SoundTiming)
local Sfx={};local active={};local unavailable={};local warned={}
local function valid(id)return type(id)=='string'and id:match('^rbxassetid://[1-9]%d*$')end
function Sfx.Preload(ids)
    task.spawn(function()
        local sounds={}
        for _,id in ipairs(ids)do if valid(id)then
            local sound=Instance.new('Sound');sound.SoundId=id;table.insert(sounds,sound)
        end end
        pcall(function()
            Content:PreloadAsync(sounds,function(id,status)
                if status~=Enum.AssetFetchStatus.Success then unavailable[id]=true end
            end)
        end)
        for _,sound in ipairs(sounds)do sound:Destroy()end
    end)
end
function Sfx.Play(id,position,volume,pitch,lifetime)
    if not valid(id)then return end
    if unavailable[id]then
        if not warned[id]then warned[id]=true;warn('[V103] Sound unavailable for this session: '..id)end
        return
    end
    local now=os.clock()
    for i=#active,1,-1 do if not active[i].Item.Parent or active[i].Until<=now then table.remove(active,i)end end
    if #active>=12 then return end
    local parent=SoundService;local anchor
    if position then
        anchor=Instance.new('Part');anchor.Name='ChestChaseSfx';anchor.Size=Vector3.one
        anchor.Transparency=1;anchor.Anchored=true;anchor.CanCollide=false;anchor.CanTouch=false;anchor.CanQuery=false
        anchor.Position=position;anchor.Parent=workspace;parent=anchor
    end
    local sound=Instance.new('Sound');sound.Name='ChestChaseOneShot';sound.SoundId=id
    sound.Volume=math.clamp(volume,0,.5);sound.PlaybackSpeed=math.clamp(pitch or 1,.6,1.4)
    sound.RollOffMode=Enum.RollOffMode.InverseTapered;sound.RollOffMinDistance=20;sound.RollOffMaxDistance=260
    sound.Parent=parent
    local owner=anchor or sound
    local ttl=math.clamp(lifetime or 8,1,20)
    table.insert(active,{Item=owner,Until=now+ttl})
    sound.Ended:Connect(function()owner:Destroy()end)
    Debris:AddItem(owner,ttl);Timing.Play(sound)
    return sound
end
return Sfx
