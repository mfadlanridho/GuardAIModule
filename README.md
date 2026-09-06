# GuardAIModule

Modular, zero-lock-in Guard AI engine for Roblox. Driven by `StateMachineModule` with 6 built-in states: **Idle**, **Patrol**, **Chase**, **Attack**, **Retrieve**, and **Return**.

Supports **Dual-Mode Locomotion**:
- **`"Walk"` (Default):** Native ground-based navigation using `Humanoid:MoveTo()`.
- **`"Fly"`:** 3D aerial navigation using Roblox physics constraints (`AlignPosition` + `AlignOrientation`), perfect for floating bosses, mages, and spirits with zero ground-collision dependencies.

---

## 📦 Installation & Submodule Usage

Add `GuardAIModule` to your project's `packages/` directory via Git Submodule:

```bash
git submodule add https://github.com/mfadlanridho/GuardAIModule.git packages/GuardAIModule
```

---

## 🚀 Quick Start

### 1. Ground-Walking Guard (Default)
```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuardAI = require(ReplicatedStorage.Packages.GuardAIModule)

local guardInstance = GuardAI.new(workspace.GuardNPC, {
    locomotionMode = "Walk", -- default
    moveSpeed = 16,
    detectionRadius = 40,
    attackRadius = 5,
    onAttackHit = function(victimCharacter)
        print("Guard hit player:", victimCharacter.Name)
    end,
})
```

### 2. Flying / Hovering Boss Guard
```luau
local guardInstance = GuardAI.new(workspace.FlyingBoss, {
    locomotionMode = "Fly",
    flightSpeed = 26,         -- max aerial glide speed
    hoverAltitude = 4.0,      -- height above target player (studs)
    turnResponsiveness = 20,  -- angular banking speed
    attackRadius = 6,
    onAttackHit = function(victimCharacter)
        print("Boss dive-hit player:", victimCharacter.Name)
    end,
})
```

---

## ⚙️ Configuration Parameters (`GuardAIConfig`)

| Parameter | Type | Default | Description |
| :--- | :--- | :---: | :--- |
| `locomotionMode` | `"Walk" \| "Fly"` | `"Walk"` | Locomotion driver. `"Walk"` uses `Humanoid:MoveTo()`; `"Fly"` uses `AlignPosition`. |
| `hoverAltitude` | `number` | `3.5` | Hover height above targets when `locomotionMode = "Fly"`. |
| `flightSpeed` | `number` | `moveSpeed` | Maximum aerial travel speed (studs/s). |
| `turnResponsiveness` | `number` | `20` | Angular turning responsiveness on `AlignOrientation`. |
| `moveSpeed` | `number` | `16` | Base walk or travel speed. |
| `detectionRadius` | `number` | `40` | Proximity detection radius for scanning players. |
| `attackRadius` | `number` | `5.0` | Distance threshold to transition into `AttackState`. |
| `attackRecoveryTime` | `number` | `0.5` | Delay (seconds) before returning to chase after an attack. |
| `displacementThreshold`| `number`| `0.5` | Minimum target movement distance before recalculating path. |
| `serverNetworkOwner` | `boolean` | `true` | Locks `PrimaryPart` network ownership to server (`nil`). |
| `restPart` | `BasePart?` | `nil` | Guard post part to return to upon retreating. |
| `onAttackHit` | `(Model) -> ()` | `nil` | Callback invoked when attack lunge lands. |
| `onItemReached` | `(Instance) -> ()` | `nil` | Callback invoked when reaching a dropped item in `RetrieveState`. |
| `onReturnedToPost` | `() -> ()` | `nil` | Callback invoked when returning to rest post in `ReturnState`. |

---

## 🔁 State Machine Lifecycle

```
             ┌───────────────────────────────────────────────────────┐
             │                                                       ▼
      [ IdleState ] ──► [ PatrolState ] ──(Theft / Detected)──► [ ChaseState ]
             ▲                                                       │
             │ (Returned)                                (In range)  ▼
      [ ReturnState ] ◄──(Item reached)── [ RetrieveState ] ◄── [ AttackState ]
             ▲                                   │
             └──────────(Safe Zone / Loss)───────┘
```

1. **IdleState**: Standby dormant state resting at spawn post.
2. **PatrolState**: Patrols between waypoint parts in a platform `Waypoints` folder.
3. **ChaseState**: Pursues players (running along ground in Walk mode, gliding through air in Fly mode).
4. **AttackState**: Lunges / dive-attacks forward, invokes `onAttackHit`, and applies recovery delay.
5. **RetrieveState**: Aggro shifts to a dropped item; paths / swoops down to pick it up.
6. **ReturnState**: Navigates / glides along an aerial arc back to post, aligns orientation, and sleeps.

---

## 📄 License
MIT
MIT
