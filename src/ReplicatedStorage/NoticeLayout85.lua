-- Shared, bounded screen-space layout for the announcement stack and console.
local L={}
function L.Notices(width,height,bottom)
 local row=height<480 and 36 or width<650 and 56 or 44
 local y=math.max(8,tonumber(bottom)or 104)+8
 local available=height-18-y
 local count=math.clamp(math.floor((available+4)/(row+4)),0,3)
 return {X=width/2,Y=y,Width=math.max(1,math.min(height<480 and width*.55 or 720,width-24)),Row=row,Count=count}
end
function L.Console(width,height)
 local w=math.max(1,math.min(1000,width-24));local h=math.max(1,math.min(720,height-24))
 return {Width=w,Height=h,X=width/2,Y=height/2}
end
return L
