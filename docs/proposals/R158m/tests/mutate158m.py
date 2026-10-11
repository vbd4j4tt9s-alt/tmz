"""R158m: the break-it-on-purpose table of run_unskippable158m.sh. Each mutation is a (file, [(old, new), ...]) edit of a COPY of the source (never of the checkout), in the
exact text of the shipped modules; the test must FAIL on every one (a mutation that survives means the test does not see that rule).
Usage: python3 mutate158m.py list            the ids, one per line
       python3 mutate158m.py apply ID SRC    applies mutation ID to the src tree SRC, prints its description (exit 1 if the text it edits is not there exactly once)"""
import sys, os

CIN = 'ReplicatedStorage/RarePullCinematic.lua'
CARD = 'ReplicatedStorage/RarePullCard.lua'
RULES = 'ReplicatedStorage/RarePullRules.lua'

M = [
 ('tap_shown', 'a click / tap collects from the first showing of the seed (the owner\'s bug)', CIN, [
  ("if at<collectFrom(run)+M.CollectAfter then return false end", "if at<Rules.ShownAt(run.TL)+M.CollectAfter then return false end")]),
 ('keys_shown', 'Enter / B / R2 after the hit collect from the first showing of the seed', CIN, [
  ("if t<collectFrom(run)+M.CollectAfter then return false end", "if t<shownAt+M.CollectAfter then return false end")]),
 ('collect_api', 'M.Collect() collects whenever the seed is shown', CIN, [
  ("if why=='press'and run.Clock()<collectFrom(run)+M.CollectAfter then return false end", "")]),
 ('from_is_shown', 'CollectFrom is ShownAt again (every gate falls back to the first showing)', CIN, [
  ("local function collectFrom(run)return run.CollectFrom or Rules.CollectFrom(run.TL)end", "local function collectFrom(run)return Rules.ShownAt(run.TL)end")]),
 ('rules_from', 'RarePullRules.CollectFrom answers ShownAt', RULES, [
  ("return math.max(L.ShownAt(tl),tl.FloatEnd or 0)", "return L.ShownAt(tl)")]),
 ('after_zero', 'CollectAfter is 0: the burst-of-clicks rule is gone', CIN, [
  ("M.CollectAfter=.25 --", "M.CollectAfter=0 --")]),
 ('menu_early', 'a menu opening during the animation collects the result (gate and latch both gone)', CIN, [
  ("if now.Menu and not was.Menu and run.Clock()>=collectFrom(run)then return'menu'end", "if now.Menu and not was.Menu then return'menu'end"),
  ("if was0 and not was0.Menu and run.Clock()<collectFrom(run)then", "if false then")]),
 ('hint_shown', 'the collect hint shows from the first showing of the seed', CARD, [
  ("clamp01((t-from-Card.CollectHint)/.3)", "clamp01((t-shown-Card.CollectHint)/.3)")]),
 ('beats_from', 'the waiting beats do not carry the real CollectFrom (a scene\'s hint never comes)', CIN, [
  ("b.Out=M.Forever;b.Length=M.Forever;b.CollectFrom=collectFrom(run)", "b.Out=M.Forever;b.Length=M.Forever")]),
 ('hold_hook', 'the next pack is not held until the next render step', CIN, [
  ("if c:IsA('Tool')then holdNow(run)end", "if c:IsA('Tool')then end")]),
 ('press_route', 'a click on the world collects through the press taker with no gate', CIN, [
  ("else M.Tap(began)end", "else collect(run,'press')end")]),
 ('backdrop_route', 'the story scene\'s full-screen button collects with no gate', CIN, [
  ("local began=run.TapBegan;run.TapBegan=nil;M.Tap(began)end))", "local began=run.TapBegan;run.TapBegan=nil;collect(run,'press')end))")]),
 ('space_route', 'Space / A in a story scene collect with no gate', CIN, [
  ("if M.SkipKeys[k]then M.Skip()else M.Tap(os.clock())end", "if M.SkipKeys[k]then M.Skip()else collect(run,'press')end")]),
 ('click_skips', 'a click skips (R155 undone)', CIN, [
  ("function M.Tap(began)\n local run=current", "function M.Tap(began)\n M.Skip()\n local run=current")]),
 ('skip_dead', 'the SKIP button / its keys no longer skip to the hit', CIN, [
  ("if t<(tl.SkipFrom or math.huge)or t>=hit-.02 then return false end", "do return false end")]),
 ('ladder_skip', 'Common..Mythic grow a SKIP button', RULES, [
  ("Letterbox=tier.Letterbox==true,Quick=quick==true}", "Letterbox=tier.Letterbox==true,Quick=quick==true,SkipFrom=.35}")]),
 ('end_not_collected', 'death / a teleport / a chase / the next pack no longer collect the revealed seed', CIN, [
  ("if run.SawClimax and not run.Collected and not M.NoCollect[reason]then return collect(run,reason)end", "if false then return collect(run,reason)end")]),
 ('end_gated', 'death / a teleport / the next pack wait for CollectFrom like a press', CIN, [
  ("collect=function(run,why)\n if run.Collected or run.Done then return end", "collect=function(run,why)\n if run.Collected or run.Done or run.Clock()<collectFrom(run)then return end")]),
]

def main():
    if len(sys.argv) >= 2 and sys.argv[1] == 'list':
        for m in M: print(m[0])
        return 0
    if len(sys.argv) == 4 and sys.argv[1] == 'apply':
        ident, src = sys.argv[2], sys.argv[3]
        for mid, desc, rel, edits in M:
            if mid != ident: continue
            path = os.path.join(src, rel)
            text = open(path, encoding='utf-8').read()
            for old, new in edits:
                if text.count(old) != 1:
                    sys.stderr.write('mutation %s: %r is in %s %d times (want exactly 1)\n' % (mid, old[:70], rel, text.count(old)))
                    return 1
                text = text.replace(old, new)
            open(path, 'w', encoding='utf-8').write(text)
            print(desc)
            return 0
        sys.stderr.write('no mutation ' + ident + '\n')
        return 1
    sys.stderr.write(__doc__)
    return 2

if __name__ == '__main__':
    sys.exit(main())
