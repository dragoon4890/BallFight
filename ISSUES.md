# Issues Log

## [FIXED] Multiplayer Camera & Control Not Working for Client

### Symptoms
- Client had no camera visibility after joining
- Host controlled both cameras
- Mouse capture affected all instances

### Root Cause
Authority was set **after** `_ready()` executed.

**Broken code:**
```gdscript
add_child(player)                    # _ready() runs here
player.set_multiplayer_authority(id) # Authority set AFTER
```

When `_ready()` ran, `is_multiplayer_authority()` returned `false` for everyone because the node didn't know its owner yet.

### Fix
Set authority **before** adding to tree:

```gdscript
player.set_multiplayer_authority(id)  # Set authority FIRST
add_child(player)                     # THEN add to tree
```

### File Changed
- `scripts/network_manager.gd` - `spawn_player()` function

### Lesson
Always set `set_multiplayer_authority()` **before** `add_child()` so `_ready()` can correctly determine ownership.
