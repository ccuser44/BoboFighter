# BoboFighter

A server sided anti exploit capable of handling common exploits smoothly. Performance friendly, and reserves resources. 

### Current Supported Detections

- No clipping
- Walking through can collide objects [Doesn't support body mover / gravity]
- High Speed (Y axis)
- High Speed / Teleportation (X and Z axis)
- Multi tool equip
- Invalid tool deletion
- God mode

### Future Updates

- Flight detection
- Low gravity detection
- Body mover support
- More reliability

### Intended behaviour

The anti exploit doesn't handle any physics detections if:

- The player is seated
- The player was teleported by the server
- The player was flinged / (hit by a fast moving object)

False positives rarely should be a problem, make sure to adjust the leeways found in the Settings module to best suit your game!

### Caveats

- Lack of high speed server sided body mover support 
