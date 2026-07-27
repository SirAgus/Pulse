---
version: 1
slug: "sources-dynamicisland-islandview-swift"
primary_target: "Sources/DynamicIsland/IslandView.swift"
related_targets: ["Sources/DynamicIsland/IslandState.swift"]
---

# Pulse island surface

- Scope: the complete compact and expanded native macOS interface in `Sources/DynamicIsland/IslandView.swift`.
- Visitor mode: Operate.
- Audience and job: Mac users checking state or completing a small control action without leaving their primary application.
- Primary task: understand the active mode instantly, take its main action, then return to work.
- Content: current live music, focus, alarm, system, connectivity, notes, clipboard, camera, application, and settings data.
- Constraints: preserve all existing functionality, notch-aware geometry, macOS behavior, user customization, permissions, and semantic states; interface copy may improve.
- Chosen direction: Telemetry Ribbon — a continuous signal path from the physical notch organizes compact state, expansion, navigation, and action.
- Memorable moment: the compact signal line becomes the expanded mode's progress or selection rail without breaking continuity.
- Unresolved: exact final accent defaults remain user-controlled; generated comps determine the clearest dashboard topology.
