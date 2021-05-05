# [BoboFighter](https://devforum.roblox.com/t/bobofighter-performant-server-sided-anti-exploit/1185012) 
A roblox server sided anti exploit capable of handling common exploits smoothly. Performance friendly, and reserves resources. The point of this anti exploit is to stop common exploits
reliably with minimum performance impact, and rarely cause any false positive related problems.

---

## Quick Start 
For quick setup *without Rojo*, grab the Roblox model and insert it to your game. Then simply, place it in ServerScriptService. It also comes with a client script 15 which is to stop bouncing when jumping from a high altitude, place that in StarterCharacterScripts.

## Performance Testing 
These are the performance results of **BoboFighter and Hexolus**:

Hexolus: `2 - 3%` script activity (4 player test)
BoboFighter: `0 - 0.5%` script activity (4 player test)

Hexolus: `4 - 5.5%` script activity (8 player test)
BoboFighter: `0.5 - .7%` script activity (8 player test)

---

## Supported Detections 
* No clipping
* Walking through can collide objects [Doesn’t support body mover / gravity]
* High Speed (Y axis)
* High Speed / Teleportation (X and Z axis)
* Multi tool equip
* Invalid tool deletion
* God mode

## Future Updates 
* Flight detection
* Low gravity detection
* Body mover support
* More reliability

---


```
                                         BoboFighter is licenced under the
                                                   Apache License
                                             Version 2.0, January 2004
                                          http://www.apache.org/licenses/
```
