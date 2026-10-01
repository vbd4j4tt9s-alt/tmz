-- R122 Studio-only owner tool: finds every dig in the long dig recording and saves the variant list.
-- Run in Play mode from the Command Bar (context "Client" is best, so you also hear it):
--   require(game.ReplicatedStorage.DigSoundAnalyzer).Run()
--   require(game.ReplicatedStorage.DigSoundAnalyzer).Run({Sensitivity=.2, QuietGap=.1})   -- more / smaller digs
-- It plays the sound through the Audio API (AudioPlayer -> AudioAnalyzer, plus AudioDeviceOutput to listen),
-- reads PeakLevel / RmsLevel every frame, detects each dig onset (DigSoundVariants.Detect), prints every point
-- where a dig is heard and the lines to save it, and applies the list to this session at once (attribute
-- DigSegments on TrackHoleConfig). Full steps: docs/proposals/holes_R122/DIG_SOUND.md.
local RunService=game:GetService('RunService')
local SoundService=game:GetService('SoundService')
local Variants=require(script.Parent:WaitForChild('DigSoundVariants'))
local configModule=script.Parent:WaitForChild('TrackHoleConfig')
local A={}

local function wire(from,to,parent)
 local w=Instance.new('Wire');w.SourceInstance=from;w.TargetInstance=to;w.Parent=parent;return w
end

-- Prints the report; returns the paste-ready Lua and the attribute JSON.
function A.Report(segments,info,length)
 print(string.format('[DigSound] %d digs found in %.2f s (threshold %.3f, floor %.3f, peak %.3f)',
  #segments,length or 0,info.Threshold or 0,info.Floor or 0,info.Peak or 0))
 local rows={}
 for i,s in ipairs(segments)do
  print(string.format('[DigSound]  #%d  dig heard at %.3f s   variant %.3f -> %.3f s  (length %.3f, peak %.2f)',
   i,s.Onset or s.Start,s.Start,s.Start+s.Length,s.Length,s.Peak or 0))
  rows[#rows+1]=string.format('{Start=%.3f,Length=%.3f}',s.Start,s.Length)
 end
 local lua='Segments={'..table.concat(rows,',')..'},'
 local json=Variants.Encode(segments)
 print('[DigSound] Paste into TrackHoleConfig.DigSound (replace the Segments line):\n  '..lua)
 print("[DigSound] Or save it as an attribute: STOP the game, then run in the Command Bar (Edit mode):\n  game.ReplicatedStorage.TrackHoleConfig:SetAttribute('DigSegments','"..json.."')")
 return lua,json
end

-- Yields while the sound plays once. options: any DigSound.Analyzer field, plus Id, Listen (default true), Timeout.
function A.Run(options)
 assert(RunService:IsStudio(),'DigSoundAnalyzer is a Studio-only owner tool')
 options=options or{}
 local cfg=Variants.Config
 local folder=Instance.new('Folder');folder.Name='DigSoundAnalyzer';folder.Parent=SoundService
 local player=Instance.new('AudioPlayer');player.AssetId=options.Id or cfg.Id;player.Looping=false;player.Parent=folder
 local analyzer=Instance.new('AudioAnalyzer');analyzer.Parent=folder;wire(player,analyzer,folder)
 if options.Listen~=false then local out=Instance.new('AudioDeviceOutput');out.Parent=folder;wire(player,out,folder)end
 local waited=0
 while not player.IsReady and waited<10 do waited+=task.wait(.1)end
 if not player.IsReady then folder:Destroy();warn('[DigSound] Sound did not load: '..tostring(player.AssetId));return nil end
 local length=player.TimeLength
 local use=(options.Use or cfg.Analyzer.Use)=='Rms'and'RmsLevel'or'PeakLevel'
 local samples={};local began=os.clock()
 player:Play()
 local connection=RunService.Heartbeat:Connect(function()
  if not player.IsPlaying then return end
  samples[#samples+1]={T=player.TimePosition,Level=analyzer[use]}
 end)
 local timeout=options.Timeout or(length+3)
 repeat task.wait(.05)until(not player.IsPlaying and os.clock()-began>.3)or os.clock()-began>timeout
 connection:Disconnect();player:Stop()
 folder:Destroy()
 local segments,info=Variants.Detect(samples,options)
 local _,json=A.Report(segments,info,length)
 if #segments>0 then configModule:SetAttribute(cfg.Attribute or'DigSegments',json)end
 print('[DigSound] Applied to this session. Tune with Run({Sensitivity=..,QuietGap=..}) if digs are missed or merged.')
 return segments
end

-- Plays the current variants one after another so the owner can listen to the cuts (Play mode, client).
function A.Preview(gap)
 assert(RunService:IsStudio(),'Studio only')
 local player=Variants.new();local camera=workspace.CurrentCamera
 local list=player:Segments()
 print(string.format('[DigSound] previewing %d variants',#list))
 for i,s in ipairs(list)do
  print(string.format('[DigSound]  variant #%d  %.3f s + %.3f s',i,s.Start,s.Length))
  player:Play(camera and camera.CFrame.Position or Vector3.zero,1,i)
  task.wait(s.Length+(gap or .4))
 end
end
return A
