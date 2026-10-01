-- R42. Studs/second; actual distance depends on gravity and world collisions.
return {
 -- Stable stage IDs: Forest, Desert, Snow, Lava, Crystal, Jungle, Storm.
 -- R122: much more air time, rising with each keeper in the order players meet them (Forest 110 ... Storm 182 up;
 -- peak ~31 to ~84 studs, ~1.1 to ~1.9 s in the air). Sideways speed scaled so players land about as far as before.
 Keeper={{93,110},{103,134},{108,146},{123,158},{106,170},{98,122},{118,182}},
 SpecialKeeper={Horizontal=130,Vertical=200},
 Lightning={Horizontal=135,Vertical=65},
 Bat={Horizontal=88,Vertical=42,Stun=1.20,RecoveryGrace=.65},
 Trail={Width=.12,Lifetime=.22,MinSpeed=12},
}
