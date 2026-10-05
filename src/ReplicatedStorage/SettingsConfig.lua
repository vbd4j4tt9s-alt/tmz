local C={Defaults={Music=100,Chase=100,Ambience=100,Effects=100,Interface=100,Quality='Auto',GlobalAnnouncements=true}}
-- R151: on / off settings (saved in the same Settings table of the Premium save, so no profile version change). GlobalAnnouncements: show pulls from
-- other servers (PullAnnouncer): the 🌐 chat lines. Pulls in this very server are always shown.
C.Toggles={GlobalAnnouncements=true}
-- R150: the saved volumes are also published on the Player (server, at data load) under these attribute names, so the client's AudioMixer can
-- use them before the SettingsState request is answered.
C.AudioAttributes={Music='AudioMusic',Chase='AudioChase',Ambience='AudioAmbience',Effects='AudioEffects',Interface='AudioInterface'}
function C.Valid(key,value)
 if key=='Quality'then return value=='Auto'or value=='High'or value=='Low'end
 if C.Toggles[key]then return type(value)=='boolean'end
 return C.Defaults[key]~=nil and type(value)=='number'and value==value and value%1==0 and value>=0 and value<=100
end
function C.Read(saved)
 local out={}
 for k,v in pairs(C.Defaults)do
  if type(saved)=='table'and C.Valid(k,saved[k])then out[k]=saved[k]else out[k]=v end -- (not "and saved[k] or v": a saved false would turn back into true)
 end
 return out
end
return C
