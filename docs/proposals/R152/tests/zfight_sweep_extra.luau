-- R152 z-fighting sweep: what the R149 whole-map scene (zfight_scene.luau + the R151 hub displays, make_hub_scene.py) does not build, injected by make_sweep_scene.py before the scene is dumped.
--  * the Void Pack giveaway pedestal (the REAL VoidGiveaway152 / VoidGiveawayArt152 on the finished hub: it stands on the plaza HubDecor151 paved at the lobby's centre, 0 / -392);
--  * GEO = true prints the keyboard grid of this map (biomes, spacebars, the cells the server's scan leaves out) so the sweep can pick its sample rows.
-- Globals (optional): GIVEAWAY = false leaves the pedestal out; GEO = true prints "GEO ..." lines.
if GIVEAWAY~=false then
 step('VoidGiveaway152',function()
  local Service=server('VoidGiveaway152');local Store=server('VoidGiveawayStore152')
  local svc=Service.new(Config,{CanSave={}},{},{},{MapRoot=map},{Store=Store.new({Studio=true,Memory=true}),Studio=true,NoLoop=true})
  svc:Start();R.advance(.2)
 end)
end
if GEO then
 step('GEO',function()
  local K=W.module('KeyboardTrack');local g=K.Geometry(map:GetAttributes(),nil)
  print(string.format('GEO rows=%d cols=%d pitch=%.4f z0=%.2f keyEnd=%.2f skip=%d',g.Rows,g.Cols,g.Pitch,g.Z0,g.KeyEndZ,g.SkipCount))
  for i,s in ipairs(g.Segs)do print(string.format('GEO seg %d id=%d %s z=%.1f..%.1f rows=%d first=%d last=%d spaceLast=%d pitch=%.4f',i,s.Id,s.Name,s.StartZ,s.EndZ,s.Rows,s.FirstRow,s.LastRow,s.SpaceLast,s.RowPitch))end
  local rows={};for r in pairs(g.RowSkip)do rows[#rows+1]=r end;table.sort(rows)
  local runs,a,b={},nil,nil
  for _,r in ipairs(rows)do
   if a and r==b+1 then b=r else if a then runs[#runs+1]={a,b}end;a,b=r,r end
  end
  if a then runs[#runs+1]={a,b}end
  for _,run in ipairs(runs)do
   local z0=g.RowZ(run[1]);local _,z1=g.RowZ(run[2]);local n=0;for r=run[1],run[2]do n+=g.RowSkip[r]end
   print(string.format('GEO skiprows %d..%d z=%.1f..%.1f cells=%d seg=%d',run[1],run[2],z0,z1,n,g.RowSeg[run[1]]))
  end
 end)
end
