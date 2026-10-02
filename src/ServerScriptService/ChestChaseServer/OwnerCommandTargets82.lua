-- An explicit final @target cannot be confused with a biome/count/seed selector.
local T={}
function T.Split(text)
 if type(text)~='string'or #text>220 then return nil,nil,'Command must be 1–220 characters.'end
 text=text:match('^%s*(.-)%s*$')
 local body,target=text:match('^(.-)%s+@([%w_]+)$')
 if body then return body,target end
 if text:find('@',1,true)then return nil,nil,'Put @username, @me or @all at the end.'end
 return text,nil
end
function T.IsGlobal(text)
 local s=text:lower():gsub('^/cctest%s+',''):gsub('^/test%s+',''):gsub('^%s*','')
 return s=='collisions'or s=='economy'or s:match('^weather')~=nil or s=='mechshop' or s:match('^eventpack')~=nil or s:match('^keepersmack')~=nil or s:match('^clearinventory')~=nil or s:match('^cleargarden')~=nil or s:match('^refreshpacks')~=nil or s:match('^refreshcycle')~=nil or s=='admins'or s:match('^holes')~=nil or s=='event'or s:match('^event%s+spawn')~=nil or s:match('^event%s+clear')~=nil
end
return T
