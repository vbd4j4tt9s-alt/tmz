local C={Defaults={Music=100,Chase=100,Ambience=100,Effects=100,Interface=100,Quality='Auto'}}
function C.Valid(key,value)
 if key=='Quality'then return value=='Auto'or value=='High'or value=='Low'end
 return C.Defaults[key]~=nil and type(value)=='number'and value==value and value%1==0 and value>=0 and value<=100
end
function C.Read(saved)
 local out={};for k,v in pairs(C.Defaults)do out[k]=type(saved)=='table'and C.Valid(k,saved[k])and saved[k]or v end;return out
end
return C
