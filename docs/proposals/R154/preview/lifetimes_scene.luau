--!nocheck
-- R154 preview data (not a test): how long each speed popup of the REAL client lives on quality tier 1 (FastMode, or a slow frame rate: Studio after a few slow seconds) at 60 fps in the normal
-- stream of 10 a second, from the first frame it shows to the last (and its alpha on that last frame). Run on the R153 and the R154 code. Prints "LIFE {...}".
local PW=require('./speed_popups_world');local W,R=PW.W,PW.R
local C=PW.boot({tier=1})
local Style,me,pg=C.Style,C.Me,C.PG
PW.Tier=1
local function head(p)return p.Character:FindFirstChild('Head')end
local live,list={},{}
local t=0;local dt=1/60
for f=0,60*3-1 do
 if f%12==0 then C.fire(me,4200,1,1/5)end
 PW.frames(1,dt);t+=dt
 local field=PW.fieldOf(pg,head(me))
 if field then
  for _,fr in ipairs(PW.frameList(field))do
   local st=live[fr]
   if fr.Visible then
    local r=PW.read(fr)
    if not st or st.z~=r.ZIndex then st={z=r.ZIndex,t0=t};live[fr]=st end
    st.a=r.Alpha
   elseif st then
    list[#list+1]=string.format('{"t0":%.3f,"t1":%.3f,"a":%.3f}',st.t0,t,st.a);live[fr]=nil
   end
  end
 end
end
print('LIFE {"cap":'..Style.Cap(1,true,false)..',"life":'..Style.Life..',"popups":['..table.concat(list,',')..']}')
