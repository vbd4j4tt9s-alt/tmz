--!nocheck
-- R151 test helpers: a JSON encoder / decoder (HttpService.JSONEncode / JSONDecode stand-ins) and a MessagingService bus that behaves like Roblox
-- where it matters here: a message is a string of at most 1,000 bytes, PublishAsync / SubscribeAsync can fail, a subscriber is called for EVERY server's
-- messages on the topic (the publisher's own server included, which is why the origin check exists), and every call is logged with the clock.
local E={}
-- JSON ----------------------------------------------------------------------------------------------------------------------------------------
local function esc(s)
 return '"'..s:gsub('[%c"\\]',function(c)
  if c=='"'then return '\\"'elseif c=='\\'then return '\\\\'elseif c=='\n'then return '\\n'elseif c=='\r'then return '\\r'elseif c=='\t'then return '\\t'end
  return string.format('\\u%04x',c:byte())
 end)..'"'
end
local function encode(v)
 local t=type(v)
 if t=='nil'then return 'null'elseif t=='boolean'then return tostring(v)
 elseif t=='number'then
  if v~=v or v==math.huge or v==-math.huge then error('cannot encode '..tostring(v))end
  if v%1==0 and math.abs(v)<1e15 then return string.format('%d',v)end
  return string.format('%.14g',v)
 elseif t=='string'then return esc(v)
 elseif t=='table'then
  if v[1]~=nil or next(v)==nil then
   local out={};for i=1,#v do out[i]=encode(v[i])end;return '['..table.concat(out,',')..']'
  end
  local keys={};for k in pairs(v)do if type(k)~='string'then error('object keys must be strings')end;keys[#keys+1]=k end;table.sort(keys)
  local out={};for _,k in ipairs(keys)do out[#out+1]=esc(k)..':'..encode(v[k])end
  return '{'..table.concat(out,',')..'}'
 end
 error('cannot encode '..t)
end
E.encode=encode
local function decode(s)
 local i=1
 local function ws()i=s:find('%S',i)or #s+1 end
 local value
 local function str()
  local out={};i+=1
  while true do
   local c=s:sub(i,i)
   if c==''then error('unterminated string')end
   if c=='"'then i+=1;break end
   if c=='\\'then
    local n=s:sub(i+1,i+1)
    if n=='u'then out[#out+1]=utf8.char(tonumber(s:sub(i+2,i+5),16));i+=6
    else out[#out+1]=({n='\n',t='\t',r='\r',b='\b',f='\f'})[n]or n;i+=2 end
   else out[#out+1]=c;i+=1 end
  end
  return table.concat(out)
 end
 function value()
  ws();local c=s:sub(i,i)
  if c=='{'then
   local t={};i+=1;ws()
   if s:sub(i,i)=='}'then i+=1;return t end
   while true do
    ws();local k=str();ws();assert(s:sub(i,i)==':','expected :');i+=1;t[k]=value();ws()
    local d=s:sub(i,i);i+=1;if d=='}'then return t end;assert(d==',','expected , or }')
   end
  elseif c=='['then
   local t={};i+=1;ws()
   if s:sub(i,i)==']'then i+=1;return t end
   while true do
    t[#t+1]=value();ws();local d=s:sub(i,i);i+=1;if d==']'then return t end;assert(d==',','expected , or ]')
   end
  elseif c=='"'then return str()
  elseif s:sub(i,i+3)=='true'then i+=4;return true
  elseif s:sub(i,i+4)=='false'then i+=5;return false
  elseif s:sub(i,i+3)=='null'then i+=4;return nil
  else
   local num=s:match('^-?%d+%.?%d*[eE]?[+-]?%d*',i);assert(num and num~='','bad json at '..i);i+=#num;return tonumber(num)
  end
 end
 local result=value();ws()
 assert(i>#s,'trailing json');return result
end
E.decode=decode
-- A HttpService stand-in for PullAnnouncer.
function E.http()
 local n=0
 return {JSONEncode=function(_,t)return encode(t)end,JSONDecode=function(_,s)return decode(s)end,GenerateGUID=function()n+=1;return string.format('00000000-0000-4000-8000-%012d',n)end}
end
-- MessagingService bus --------------------------------------------------------------------------------------------------------------------------------
-- bus:Server(name) -> a service object for one server (PublishAsync / SubscribeAsync). bus.Now = function returning unix seconds.
-- bus.FailPublish / bus.FailSubscribe = number of next calls that fail (error), bus.Hold = true queues deliveries until bus:Flush().
function E.bus(clock,now)
 local bus={Log={},Subs={},FailPublish=0,FailSubscribe=0,Held={},Hold=false,Clock=clock,Now=now}
 function bus:Server(name)
  local service={Name=name,Publishes={}}
  function service.PublishAsync(_,topic,message)
   local entry={Server=name,Topic=topic,At=bus.Clock(),Bytes=type(message)=='string'and #message or -1}
   if bus.FailPublish>0 then bus.FailPublish-=1;entry.Failed=true;table.insert(bus.Log,entry);error('503: MessagingService is temporarily unavailable')end
   if type(topic)~='string'or#topic==0 or#topic>80 then error('invalid topic')end
   if type(message)~='string'then error('this test bus only takes strings')end
   if#message>1000 then error('413: message too long (limit 1 kB)')end
   entry.Message=message;table.insert(bus.Log,entry);table.insert(service.Publishes,entry)
   local packet={Data=message,Sent=bus.Now()}
   if bus.Hold then table.insert(bus.Held,{Topic=topic,Packet=packet,From=name})else bus:_deliver(topic,packet)end
  end
  function service.SubscribeAsync(_,topic,callback)
   if bus.FailSubscribe>0 then bus.FailSubscribe-=1;error('MessagingService:SubscribeAsync failed: temporarily unavailable')end
   local sub={Server=name,Topic=topic,Callback=callback,Connected=true}
   table.insert(bus.Subs,sub)
   return {Disconnect=function()sub.Connected=false end,Connected=true}
  end
  return service
 end
 function bus:_deliver(topic,packet)
  for _,sub in ipairs(table.clone(self.Subs))do if sub.Connected and sub.Topic==topic then sub.Callback({Data=packet.Data,Sent=packet.Sent})end end
 end
 function bus:Flush()local held=self.Held;self.Held={};for _,h in ipairs(held)do self:_deliver(h.Topic,h.Packet)end end
 function bus:Count(server)local n=0;for _,e in ipairs(self.Log)do if not e.Failed and(not server or e.Server==server)then n+=1 end end;return n end
 return bus
end
return E
