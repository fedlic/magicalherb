# Magical Herb Tycoon

Roblox tycoon game built with Luau. Uses Rojo for file sync.

## Project Structure

```
src/
  shared/           -> ReplicatedStorage.Shared
    GameConfig.lua     Master data (seeds, recipes, buildings, upgrades, NPCs)
    RemoteHelper.lua   Remote event/function wrapper
  server/           -> ServerScriptService.Server
    GameServer.server.lua   Main server entry point
    DataManager.lua         Player data persistence (DataStore)
    EconomyManager.lua      Money management (anti-cheat)
    InventoryManager.lua    Inventory/warehouse management
    PlantManager.lua        Planting, growing, watering, harvesting
    ShopManager.lua         Shelf display, NPC selling
    NPCManager.lua          Customer spawning, behavior AI
    UpgradeManager.lua      Equipment upgrades, building expansion
    ProcessingManager.lua   Crafting/recipe system
    BrandManager.lua        Brand identity and reputation
    EventManager.lua        Live events and festivals
    TutorialManager.lua     New player tutorial (DJ Sage)
    StaffManager.lua        NPC staff automation
  client/           -> StarterPlayer.StarterPlayerScripts.Client
    GameClient.client.lua   Main client entry point
    UIController.lua        All game UI (street/neon theme)
    InputHandler.lua        Click/tap input, raycasting
    EffectsManager.lua      Particles, sounds, visual effects
    CameraController.lua    Semi-isometric camera
```

## Setup

1. Install Rojo (VS Code extension or CLI)
2. Run `rojo serve` in this directory
3. Connect from Roblox Studio via Rojo plugin
4. Build 3D models (planters, shelves, buildings, NPCs) in Studio
5. Tag objects with CollectionService: "Planter", "Shelf", "Register", "NPC"

## Architecture Notes

- Server-authoritative: all money, inventory, and game state on server
- Client handles UI, effects, camera, input
- Communication via RemoteEvents/Functions (see RemoteHelper)
- Two module patterns coexist:
  - Dependency injection via init() (EconomyManager, InventoryManager, PlantManager, ShopManager, NPCManager)
  - Direct require() (UpgradeManager, ProcessingManager, BrandManager, EventManager, TutorialManager, StaffManager)
- PlayerData saved to DataStore every 60s and on leave
