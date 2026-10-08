"""R153 track walls: breaks one module inside a test bundle (rs_bundle.luau) in one specific way, so run_track_walls.sh can prove the suite notices it.
Usage: python3 -I mutate_track_walls.py <rs_bundle.luau> <mutation name>      (edits the bundle in place; prints what it did)
       python3 -I mutate_track_walls.py list                                    (one name per line)
Every mutation names the module it edits, the text it replaces and the text that goes in; the text must be there exactly once (a source change that moves it fails loudly)."""
import sys

TW = 'TrackWalls153'
M = {
    # the blocker's inner face is back where the saved barrier's is (1 stud in from the wall's face): the open strip is back
    'ledge': (TW, 'local tin=r.Inner-r.Sign*cfg.Lip', 'local tin=r.Inner+r.Sign*1'),
    # blockers only 60 studs over the wall top: a high fling clears them
    'short': (TW, ' Reach=1000, ', ' Reach=60, '),
    # blockers start above the wall top: a gap a body can slide into
    'floating': (TW, ' Sink=6, ', ' Sink=-3, '),
    # no overlap at the joints between two walls
    'seam': (TW, ' Overlap=.5, ', ' Overlap=0, '),
    # blockers that show
    'visible': (TW, 'p.CastShadow=false;p.Transparency=1', 'p.CastShadow=false;p.Transparency=.5'),
    # blockers that do not collide
    'soft': (TW, 'p.Anchored=true;p.CanCollide=true;', 'p.Anchored=true;p.CanCollide=false;'),
    # blockers that fire Touched
    'touch': (TW, 'p.CanTouch=false;p.CanQuery=true', 'p.CanTouch=true;p.CanQuery=true'),
    # blockers the runner sweep cannot see
    'blind': (TW, 'p.CanTouch=false;p.CanQuery=true', 'p.CanTouch=false;p.CanQuery=false'),
    # blockers that stream out
    'streamed': (TW, 'Enum.ModelStreamingMode.Persistent', 'Enum.ModelStreamingMode.Atomic'),
    # blockers that reach into the track by 2 studs
    'intrude': (TW, 'local tin=r.Inner-r.Sign*cfg.Lip', 'local tin=r.Inner-r.Sign*2'),
    # the fallback moves a body on the first look
    'jumpy': (TW, 'if zone and M.Seen[player]==zone then', 'if zone then'),
    # the fallback also moves bodies that are flying
    'flying': (TW, 'if math.abs(vy)>cfg.RestSpeed then return nil end', ''),
    # the fallback puts the body onto the wall instead of the track
    'wrong_way': (TW, 'local t=zone.Inner-zone.Sign*cfg.Landing', 'local t=zone.Inner+zone.Sign*cfg.Landing'),
    # the fallback does not tell the movement guard
    'unannounced': (TW, "pcall(function()require(script.Parent.MovementGuard).Reset(player,.6)end)", ''),
    # the fallback disturbs the owner's test flight
    'owner_flight': (TW, "and not player:GetAttribute('StudioTestFlying')and not player:GetAttribute('StudioTestNoclip')", ''),
    # the fallback looks every heartbeat
    'per_frame': (TW, 'waited+=dt;if waited<M.Settings.Interval then return end', 'waited+=dt'),
    # MapService no longer builds the blockers
    'unhooked': ('MapService', 'require(script.Parent.TrackWalls153).Apply(mapRoot)', 'local _=0 '),
}
if sys.argv[1] == 'list':
    print('\n'.join(M))
    sys.exit(0)
path, name = sys.argv[1], sys.argv[2]
module, old, new = M[name]
text = open(path, encoding='utf-8').read()
start = text.index('["%s"]=[' % module)
end_marker = text.index('\n["', start + 1) if '\n["' in text[start + 1:] else len(text)
body = text[start:end_marker]
assert body.count(old) == 1, 'mutation %s: target text found %d times in %s' % (name, body.count(old), module)
open(path, 'w', encoding='utf-8').write(text[:start] + body.replace(old, new) + text[end_marker:])
print('mutation %s applied to %s' % (name, module))
