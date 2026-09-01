# GuardAIModule

Modular, zero-lock-in Humanoid Guard AI engine for Roblox. Driven by `StateMachineModule` with 4 default states: **Idle**, **Patrol**, **Chase**, and **Attack**.

---

## 📦 Installation & Submodule Usage

Add `GuardAIModule` to your project's `packages/` directory via Git Submodule:

```bash
git submodule add https://github.com/mfadlanridho/GuardAIModule.git packages/GuardAIModule
```

---

## 🚀 Quick Start

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")

local GuardAI = require(Packages:WaitForChild("GuardAIModule"))

-- Bind GuardAI to an NPC model in Workspace
local guardInstance = GuardAI.new(workspace.GuardNPC, {
    moveSpeed = 16,
    detectionRadius = 40,
    attackRadius = 5,
    onAttackHit = function(victimCharacter)
        print("Guard hit player:", victimCharacter.Name)
    end,
})
```

---

## 🔁 State Machine Lifecycle

```
 [ IdleState ] ──► [ PatrolState ] ──(Player detected)──► [ ChaseState ] ──(In range)──► [ AttackState ]
                        ▲                                       │
                        └─────────────(Player exited)───────────┘
```

1. **IdleState**: Standby state scanning for nearby players.
2. **PatrolState**: Patrols between waypoint parts in a platform `Waypoints` folder using `Humanoid:MoveTo()`.
3. **ChaseState**: Pursues players within platform boundaries. Instantly cancels and returns to Patrol if the player jumps off the platform.
4. **AttackState**: Lunges towards target, invokes `onAttackHit`, and applies recovery delay.

---

## 📄 License
MIT
