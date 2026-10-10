-- An explicit final @target cannot be confused with a biome/count/seed selector.
local T={}
function T.Split(text)
 if type(text)~='string'or #text>220 then return nil,nil,'Command must be 1–220 characters.'end
 text=text:match('^%s*(.-)%s*$')
 -- R156: "/test pyramid @name reset" (the owner's order) is "/test pyramid reset @name"
 do local head,who,tail=text:match('^(.-[Pp][Yy][Rr][Aa][Mm][Ii][Dd])%s+@([%w_]+)%s+(%a+)$');if head and head:lower():match('pyramid$')then return head..' '..tail,who end end
 -- R158d: "/test starterverity @name reset" is "/test starterverity reset @name"
 do local head,who,tail=text:match('^(.-[Ss][Tt][Aa][Rr][Tt][Ee][Rr][Vv][Ee][Rr][Ii][Tt][Yy])%s+@([%w_]+)%s+(%a+)$');if head and head:lower():match('starterverity$')then return head..' '..tail,who end end
 local body,target=text:match('^(.-)%s+@([%w_]+)$')
 if body then return body,target end
 -- R157: "playtime @name 12" (the name before the minutes) means "playtime 12 @name": the one command that is typed that way
 local head,name,rest=text:match('^(.-)%s+@([%w_]+)%s+(%S+)$')
 if head and(head:lower():gsub('^/cctest%s+',''):gsub('^/test%s+',''))=='playtime'then return head..' '..rest,name end
 if text:find('@',1,true)then return nil,nil,'Put @username, @me or @all at the end.'end
 return text,nil
end
function T.IsGlobal(text)
 local s=text:lower():gsub('^/cctest%s+',''):gsub('^/test%s+',''):gsub('^%s*','')
 return s=='collisions'or s=='economy'or s:match('^weather')~=nil or s=='mechshop' or s:match('^eventpack')~=nil or s:match('^keepersmack')~=nil or s:match('^clearinventory')~=nil or s:match('^cleargarden')~=nil or s:match('^refreshpacks')~=nil or s:match('^fruithour')~=nil or s:match('^refreshcycle')~=nil or s=='admins'or s:match('^verityvoice')~=nil or s:match('^hubdisplays')~=nil or s:match('^voidgift')~=nil or s:match('^holes')~=nil or s=='event'or s:match('^event%s+spawn')~=nil or s:match('^event%s+clear')~=nil
end
return T
