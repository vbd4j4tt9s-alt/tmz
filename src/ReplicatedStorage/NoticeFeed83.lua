-- One text-only stack for world events and local feedback; no fullscreen frames/effects.
local F={};local RS=game:GetService('ReplicatedStorage');local Run=game:GetService('RunService')
local Copy=require(script.Parent.NoticeCopy83);local Layout=require(script.Parent.NoticeLayout85);local Queue={};local Showing={};local Seen={}
local seenOrder={};local started=false;local alive=true;local root,host,pg;local serial=0
local cueIds={RarePack='rbxassetid://118818986767152',WeatherAdopted='rbxassetid://133449446616894'}
local voices={};local nextWarm=0;local cueUntil=0;local currentVoice
local function warm()
 local now=os.clock();if now<nextWarm then return end;nextWarm=now+10
 local list={}
 for key,id in pairs(cueIds)do
  local voice=voices[key]
  if not voice then
   voice=Instance.new('Sound');voice.Name='Notice_'..key;voice.SoundId=id;voice.Volume=.34;voice.Looped=false
   require(script.Parent.AudioMixer).Route(voice,'Interface');voice.Parent=game:GetService('SoundService');voices[key]=voice
  end
  table.insert(list,voice)
 end
 task.spawn(function()if alive then pcall(function()game:GetService('ContentProvider'):PreloadAsync(list)end)end end)
end
local function remember(key)
 if Seen[key]then return false end;Seen[key]=true;table.insert(seenOrder,key)
 if #seenOrder>512 then Seen[table.remove(seenOrder,1)]=nil end;return true
end
local function cue(key,now)
 local voice=voices[key]
 -- Cold/denied audio is skipped, never queued to play after the text has gone.
 if not voice or not voice.IsLoaded then warm();return end
 if currentVoice then currentVoice:Stop()end
 currentVoice=voice;voice:Stop();require(script.Parent.SoundTiming).Play(voice)
 cueUntil=now+math.clamp(voice.TimeLength, .35, 3.5)
end
local function ensure()
 if started then return end;started=true
 warm()
 pg=game:GetService('Players').LocalPlayer:WaitForChild('PlayerGui')
 root=Instance.new('ScreenGui');root.Name='ChestChaseNotices83';root.ResetOnSpawn=false;root.DisplayOrder=100;root.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets;root.Parent=pg
 host=Instance.new('Frame');host.Name='NoticeStack';host.AnchorPoint=Vector2.new(.5,0);host.BackgroundTransparency=1;host.BorderSizePixel=0;host.Parent=root
 local elapsed=0
 local tick=Run.Heartbeat:Connect(function(dt)
  if not alive then return end;elapsed+=dt;if elapsed<.05 then return end;elapsed=0
  local now=os.clock();if currentVoice and now>=cueUntil then currentVoice:Stop();currentVoice=nil end
  local cam=workspace.CurrentCamera;if not cam then return end
  if #Queue==0 and #Showing==0 then host.Visible=false;return end;host.Visible=true
  local view=root.AbsoluteSize;local layout=Layout.Notices(view.X,view.Y,pg:GetAttribute('HudNoticeBottom'))
  for i=#Showing,1,-1 do if now>=Showing[i].Until then Showing[i].Label:Destroy();table.remove(Showing,i)end end
  while #Showing<layout.Count and #Queue>0 do
   local item=Queue[1]
   if now-item.QueuedAt>15 then table.remove(Queue,1);continue end
   if item.Cue and currentVoice and now<cueUntil then break end
   table.remove(Queue,1)
   local label=Instance.new('TextLabel');label.Name='Announcement';label.BackgroundTransparency=1;label.BorderSizePixel=0;label.RichText=true;label.Text=item.Text
   label.TextXAlignment=Enum.TextXAlignment.Center;label.TextYAlignment=Enum.TextYAlignment.Center;label.Font=Enum.Font.FredokaOne;label.TextColor3=Color3.new(1,1,1);label.TextScaled=true;label.TextWrapped=true;label.TextStrokeTransparency=1;label.Parent=host
   local fit=Instance.new('UITextSizeConstraint');fit.MaxTextSize=24;fit.MinTextSize=14;fit.Parent=label
   local stroke=Instance.new('UIStroke');stroke.Color=Color3.new(0,0,0);stroke.Thickness=2.5;stroke.Parent=label
   item.Label=label;item.Stroke=stroke;item.At=now;item.Until=now+item.Duration;table.insert(Showing,item)
   if item.Cue then cue(item.Cue,now)end
  end
  local width,row,y=layout.Width,layout.Row,layout.Y
  local size=Vector2.new(width,(row+4)*#Showing)
  host.Position=UDim2.fromOffset(view.X*.5,y);host.Size=UDim2.fromOffset(size.X,size.Y)
  for i,item in ipairs(Showing)do
   item.Label.Visible=i<=layout.Count;item.Label.Size=UDim2.new(1,0,0,row);item.Label.Position=UDim2.fromOffset(0,(i-1)*(row+4))
   local a=math.max(1-math.clamp((now-item.At)/.15,0,1),math.clamp((now-item.Until+.3)/.3,0,1))
   item.Label.TextTransparency=a;item.Stroke.Transparency=a
  end
 end)
 script.Destroying:Connect(function()alive=false;tick:Disconnect();if root then root:Destroy()end;table.clear(Queue);table.clear(Showing);for _,voice in pairs(voices)do voice:Destroy()end;table.clear(voices)end)
end
function F.Preload()ensure()end
function F.Push(text,duration,key,priority,sound)
 ensure();if not alive or type(text)~='string'or #text>1600 then return end
 if key and not remember(key)then return end
 if #Queue>=64 then table.remove(Queue,1)end
 serial+=1;local item={Text=text,Duration=math.clamp(duration or 4,.8,7),Serial=serial,QueuedAt=os.clock(),Cue=cueIds[sound]and sound or nil}
 if priority then
  table.insert(Queue,1,item)
  if priority==true and #Showing>=3 then Showing[1].Label:Destroy();table.remove(Showing,1)end
 else table.insert(Queue,item)end
end
function F.Plain(text,color,duration,key)F.Push(Copy.Color(text,color or Color3.new(1,1,1)),duration,key)end
local pending={};local scheduled=false
function F.Pack(m)
 if not alive or type(m)~='table'or type(m.Text)~='string'or #m.Text>200 or type(m.Biome)~='string'or #m.Biome>80 or type(m.SpawnId)~='string'or #m.SpawnId>180 or type(m.Stage)~='number'or m.Stage~=m.Stage or m.Stage<1 or m.Stage>8 then return end
 ensure();local key='pack:'..m.SpawnId;if not remember(key)then return end
 local group=tostring(m.Stage)..':'..m.Text;local old=pending[group]
 if old then old.Count+=1 else old=table.clone(m);old.Count=1;pending[group]=old end
 if scheduled then return end;scheduled=true
 task.delay(.2,function()
  if not alive then return end;scheduled=false
  local list={};for _,v in pairs(pending)do table.insert(list,v)end;table.clear(pending)
  table.sort(list,function(a,b)if a.Stage==b.Stage then return a.Text<b.Text end;return a.Stage<b.Stage end)
  for _,v in ipairs(list)do F.Push(Copy.Pack(v),4.5,nil,false,'RarePack')end
 end)
end
local weatherPending={};local weatherScheduled=false
function F.Weather(m)
 if not alive or type(m)~='table'or m.Kind~='WeatherAdopted'or type(m.EventId)~='string'or #m.EventId>180 then return end
 local W=require(script.Parent.WeatherTraits);local trait=W.Key(m.Trait)
 if W.Count(trait)~=1 then return end
 local count=tonumber(m.Count);if not count or count~=count or count<=0 or count>100000 or count%1~=0 then return end
 ensure();if not remember('weather:'..m.EventId)then return end
 local scope=m.Scope=='Owned'and'Owned'or m.Scope=='World'and'World'or((tonumber(m.Plants)or 0)+(tonumber(m.Fruits)or 0)>0 and'Owned'or'World')
 local stage=type(m.Stage)=='number'and m.Stage==m.Stage and m.Stage>=1 and m.Stage<=7 and math.floor(m.Stage)or 0
 local group=scope..':'..(scope=='World'and stage or 0)..':'..trait
 local old=weatherPending[group]
 if not old then old={Trait=trait,Scope=scope,Stage=stage,Count=0,Plants=0,Fruits=0,Packs=0};weatherPending[group]=old end
 old.Count+=count
 for _,key in ipairs({'Plants','Fruits','Packs'})do local n=tonumber(m[key]);if n and n==n and n>0 and n<=count then old[key]+=math.floor(n)end end
 -- R127: owner notices carry which plants/fruits changed, so the text can name them.
 if scope=='Owned'and type(m.Items)=='table'then
  local Glow=require(script.Parent.MutationGlow127);old.Items=old.Items or{}
  for _,item in ipairs(Glow.Items(m.Items,require(script.Parent.PlantCatalog)))do if #old.Items<Glow.MaxItems then table.insert(old.Items,item)end end
 end
 if weatherScheduled then return end;weatherScheduled=true
 task.delay(.2,function()
  if not alive then return end;weatherScheduled=false
  local list={};for _,v in pairs(weatherPending)do table.insert(list,v)end;table.clear(weatherPending)
  table.sort(list,function(a,b)if a.Scope~=b.Scope then return a.Scope>b.Scope end;if a.Trait~=b.Trait then return a.Trait<b.Trait end;return a.Stage<b.Stage end)
  for _,v in ipairs(list)do F.Push(Copy.Weather(v),4.5,nil,v.Scope=='Owned'and'weather'or false,'WeatherAdopted')end
 end)
end
return F
