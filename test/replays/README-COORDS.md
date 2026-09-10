# Where the controls actually are

Replay coordinates are the PROJECT viewport, about **1080 x 2338**: the project's
1080 width with the height pulled out to the phone's shape by
`stretch/aspect="expand"`. Movie Maker ignores `--resolution`, so these are not
460x996 coordinates and writing them as such makes every tap miss while the run
films perfectly, which reads as a broken game rather than a broken coordinate.

Derived from the offsets in `src/game/hud.gd`, which are the same numbers that
decide the hit boxes, because each control handles its own input:

| Control | Rect | Centre |
|---|---|---|
| D-pad | x 372..708, y 1962..2298 | **540, 2130** |
| UPLINK | x 824..1040, y 1962..2090 | **932, 2026** |
| LAMP | x 824..1040, y 2110..2238 | **932, 2174** |
| LOAD (opens the manifest) | x 820..1060, y 104..176 | **940, 140** |
| Manifest CLOSE | x 40..1040, y 2170..2290 | **540, 2230** |

The d-pad is absolute: press offset from its centre and the direction is the
bearing of the offset, snapped to eight. So "hold down" is the pad centre plus
about 100 px of y, not the bottom of the pad.
