"""R149 Verity mutation checks: python3 mutate_verity.py REPO SCRATCH
Breaks one thing at a time in a copy of REPO/src, bundles the copy the way run_verity.sh does and runs the suite that must notice. Every mutation
must make its suite fail ("caught"); the exit status is non-zero if one survives. Suites: lipsync (R149 client), client (R147 client / dialog), voice (R149 server)."""
import os, shutil, subprocess, sys

repo, scratch = sys.argv[1], sys.argv[2]
P = os.path.join(repo, 'docs/proposals')
INV = os.path.join(P, 'inventory_R113/tests')
TB = os.path.join(P, 'treadmill_bonus_R123/tests')
SUITES = {
    'lipsync': ('cl', os.path.join(P, 'R149/tests/test_verity_lipsync.luau')),
    'client': ('cl', os.path.join(P, 'R147/tests/test_verity_client.luau')),
    'voice': ('srv', os.path.join(P, 'R149/tests/test_verity_voice.luau')),
}
CLIENT = 'StarterPlayer/StarterPlayerScripts/VerityClient.client.lua'
VOICE = 'ReplicatedStorage/VerityVoice.lua'
CONFIG = 'ReplicatedStorage/VerityConfig.lua'
CMDS = 'ServerScriptService/ChestChaseServer/OwnerUpdateCommands82.lua'
TARGETS = 'ServerScriptService/ChestChaseServer/OwnerCommandTargets82.lua'
HELP = 'ReplicatedStorage/StudioTestHelp.lua'
SERVICE = 'ServerScriptService/ChestChaseServer/VerityService.lua'

MUTATIONS = [
    ('lipsync', 'the greeting is not cut (no PlaybackRegion)', CLIENT, "s.PlaybackRegionsEnabled=true;s.PlaybackRegion=NumberRange.new(start,stop)", "s.Name=s.Name"),
    ('lipsync', 'the owner\'s live cut on her model is ignored', CLIENT, "a,b=e.Model:GetAttribute('VerityVoiceStart'),e.Model:GetAttribute('VerityVoiceEnd')end", "a,b=nil,nil end"),
    ('lipsync', 'a refused region is not replaced by a client cut', CLIENT, "(age>.15 and position>=voice.Stop-.004)", "(false)"),
    ('lipsync', 'no fade at the end of the cut', CLIENT, "if gain~=voice.Gain then voice.Gain=gain;s.Volume=C.GreetingVolume*gain end", "if false then end"),
    ('lipsync', 'a clip that is not loaded is played at once', CLIENT, "if s.IsLoaded==false and not((s.TimeLength or 0)>0)then", "if false then"),
    ('lipsync', 'the owner\'s test message is ignored', CLIENT, "greet('test',{Start=a,End=b})", "do end"),
    ('lipsync', 'the owner\'s test plays 3D from her body, not flat', CLIENT, "local s=voiceSound(e,override~=nil)", "local s=voiceSound(e,false)"),
    ('lipsync', 'lip sync ignores the loudness', CLIENT, "talking and sound and sound.PlaybackLoudness or 0,dt,talking)", "0,dt,talking)"),
    ('lipsync', 'the mouth does not close when the sound stops', VOICE, "lip.Level=lip.Level*math.exp(-cfg.Release*dt)", "lip.Level=lip.Level"),
    ('lipsync', 'the lip level is stepped when nothing talks', CLIENT, "if talking or lip.Level>0 then", "if true then"),
    ('lipsync', 'her body animates (and the mouth is made) beyond AnimateDistance', CLIENT, "and not(camera and(camera.CFrame.Position-e.Base).Magnitude>C.AnimateDistance)", ""),
    ('lipsync', 'ReducedMotion does not stop the mouth', CLIENT, "local reduced=GuiService.ReducedMotionEnabled\n local camera=workspace.CurrentCamera", "local reduced=false\n local camera=workspace.CurrentCamera"),
    ('lipsync', 'the portrait model is kept after the window closes', CLIENT, " dropPortrait() -- (her 3D model lives only while the window is open)", " -- kept"),
    ('lipsync', 'the portrait is not driven by the lip sync', CLIENT, "if portraitOn or P.Model then portraitFrame(reduced)end", "if false then end"),
    ('lipsync', 'the mouth leaves her face (wrong depth)', VOICE, "Z=-z}", "Z=-z*.5}"),
    ('lipsync', 'no talking rhythm when no loudness is reported', VOICE, "elseif lip.Age>=cfg.FallbackAfter then", "elseif false then"),
    ('client', 'layout overrides the fitted font of the quest sentence (the cut-off "...")', CLIENT, "fit(quest,short and 15 or cw<380 and 18 or 20,11);y+=questH+gap", "quest.TextSize=short and 15 or 20;y+=questH+gap"),
    ('client', 'the quest sentence loses the room the event line gave up', CLIENT, "local questH=math.max(short and 30 or 40,bodyH-(eventRow+chipH+exH+statusH+buttonH)-gap*4)", "local questH=math.max(short and 30 or 40,bodyH-(eventRow+chipH+exH+statusH+buttonH)-gap*4-40)"),
    ('client', 'an empty row is left where the event line was', CLIENT, "local eventRow=eventLine.Visible and eventH+gap or 0", "local eventRow=eventH+gap"),
    ('voice', 'the command does not play the cut', CMDS, "  svc:PlayVoice(p)\n  local start,stop,custom=svc:VoiceRegion()\n  return true,'Playing", "  local start,stop,custom=svc:VoiceRegion()\n  return true,'Playing"),
    ('voice', 'the command does not set the cut', CMDS, "if not svc:SetVoiceRegion(start,stop)then return false,'Verity is not in this server.'end", ""),
    ('voice', 'the command takes an @target', TARGETS, "or s:match('^verityvoice')~=nil ", ""),
    ('voice', 'the cut is not kept inside the clip', VOICE, "stop=math.min(stop,length);", ""),
    ('voice', 'the fade never reaches zero', VOICE, "return math.clamp((stop-position)/fade,0,1)", "return math.clamp((stop-position)/fade,.5,1)"),
    ('voice', 'the help row is missing', HELP, "{'/test verityvoice 2.1 0.3'", "{'/test verityvoise 2.1 0.3'"),
    ('voice', 'an end past the maximum is not refused', CMDS, "if start<0 or stop>Voice.MaxSeconds then return false,", "if false then return false,"),
    ('voice', 'the service sends the Greet to everybody', SERVICE, "self.Remote:FireClient(player,'Greet',{Start=start,End=stop});return true", "for _,other in ipairs(game:GetService('Players'):GetPlayers())do self.Remote:FireClient(other,'Greet',{Start=start,End=stop})end;return true"),
]

def bundle_client(src, work):
    mk = open(os.path.join(INV, 'mkbundle.py'), encoding='utf-8').read().replace('/home/user/tmz/src', src)
    open(os.path.join(work, 'mkbundle_cl.py'), 'w', encoding='utf-8').write(mk)
    subprocess.run(['python3', os.path.join(work, 'mkbundle_cl.py'), os.path.join(work, 'rs_bundle.luau'),
                    'VerityClient=' + os.path.join(src, CLIENT)], check=True, stdout=subprocess.DEVNULL)
    for f in [os.path.join(repo, 'tools/tests/roblox.luau'), os.path.join(INV, 'world.luau'), os.path.join(INV, 'fixtures.luau')]:
        shutil.copy(f, work)

def bundle_server(src, work):
    mk = open(os.path.join(TB, 'mkbundle.py'), encoding='utf-8').read()
    old = "src = os.path.normpath(os.path.join(here, '../../../../src'))"
    assert old in mk
    open(os.path.join(work, 'mkbundle_srv.py'), 'w', encoding='utf-8').write(mk.replace(old, 'src = %r' % src))
    subprocess.run(['python3', os.path.join(work, 'mkbundle_srv.py'), work], check=True, stdout=subprocess.DEVNULL)
    for f in [os.path.join(repo, 'tools/tests/roblox.luau'), os.path.join(TB, 'world.luau')]:
        shutil.copy(f, work)

caught = 0
for suite, name, rel, old, new in MUTATIONS:
    kind, test = SUITES[suite]
    work = os.path.join(scratch, 'mutation')
    shutil.rmtree(work, ignore_errors=True)
    os.makedirs(work)
    src = os.path.join(work, 'src')
    shutil.copytree(os.path.join(repo, 'src'), src)
    path = os.path.join(src, rel)
    text = open(path, encoding='utf-8').read()
    assert text.count(old) >= 1, 'mutation target not found (%s): %s' % (name, old)
    open(path, 'w', encoding='utf-8').write(text.replace(old, new, 1))
    (bundle_client if kind == 'cl' else bundle_server)(src, work)
    shutil.copy(test, work)
    r = subprocess.run(['/opt/luau/luau', os.path.basename(test)], cwd=work, capture_output=True, text=True, timeout=900)
    out = r.stdout + r.stderr
    fails = [l for l in out.splitlines() if l.startswith('FAIL')]
    if r.returncode != 0 or fails:
        caught += 1
        print('mutation caught: %s [%s: %d failing checks]' % (name, suite, len(fails)))
    else:
        print('MUTATION SURVIVED: %s [%s]' % (name, suite))
shutil.rmtree(os.path.join(scratch, 'mutation'), ignore_errors=True)
print('%d of %d mutations caught' % (caught, len(MUTATIONS)))
sys.exit(0 if caught == len(MUTATIONS) else 1)
