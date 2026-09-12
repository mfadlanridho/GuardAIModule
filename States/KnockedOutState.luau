--!strict
--[[
	KnockedOutState.luau (GuardAIModule)
	Triggered when a Guardian Boss is defeated in combat (HP reaches 0).
	- Freezes all movement, disables flight motors, anchors/drops to floor.
	- Runs a strict 15.0-second knockout timer.
	- Restores 100% HP upon recovery and transitions back to "Return".
--]]

local KNOCKOUT_DURATION = 15.0

local KnockedOutState = {
	name = "KnockedOut",

	canEnter = function(context: any, fromState: string?): (boolean, string?)
		if not context.model or not context.model.Parent then
			return false, "No valid guard model"
		end
		return true, nil
	end,

	enter = function(context: any, fromState: string?)
		context.knockoutStartTime = os.clock()

		local model = context.model
		local primaryPart = context.primaryPart or model.PrimaryPart

		-- 1. Stop movement and disable flight constraints
		if context.stopMovement then
			context.stopMovement()
		end

		if context.alignPosition then
			context.alignPosition.Enabled = false
		end
		if context.alignOrientation then
			context.alignOrientation.Enabled = false
		end

		if primaryPart and primaryPart:IsA("BasePart") then
			primaryPart.AssemblyLinearVelocity = Vector3.zero
			primaryPart.AssemblyAngularVelocity = Vector3.zero
		end

		if context.humanoid then
			context.humanoid.PlatformStand = true
		end

		-- 2. Drop any held egg if carrying one
		if context.retrievedEgg then
			local eggWeld = context.retrievedEgg:FindFirstChild("EggHoldWeld")
			if eggWeld then
				eggWeld:Destroy()
			end
			context.retrievedEgg = nil
		end

		-- 3. Set attributes
		model:SetAttribute("GuardState", "KnockedOut")
		model:SetAttribute("InCombatDuel", false)
		model:SetAttribute("Health", 0)
		model:SetAttribute("KnockoutEndTime", game:GetService("Workspace"):GetServerTimeNow() + KNOCKOUT_DURATION)

		print(string.format("💫 [GuardAI] %s was KNOCKED OUT! Resting for %.1fs...", model.Name, KNOCKOUT_DURATION))
	end,

	exit = function(context: any, toState: string?)
		local model = context.model
		model:SetAttribute("KnockoutEndTime", nil)
		if context.humanoid then
			context.humanoid.PlatformStand = false
		end

		-- Re-enable flight constraints if in Fly mode
		if context.locomotionMode == "Fly" then
			if context.alignPosition then
				context.alignPosition.Enabled = true
			end
			if context.alignOrientation then
				context.alignOrientation.Enabled = true
			end
		end

		-- Restore max health on wake up
		local maxHp = (model:GetAttribute("MaxHealth") :: number?) or 100
		model:SetAttribute("Health", maxHp)

		print(string.format("⚡ [GuardAI] %s recovered from knockout! Transitioning -> %s.", model.Name, tostring(toState)))
	end,

	update = function(context: any): string?
		local model = context.model
		if not model or not model.Parent then
			return "Idle"
		end

		local startTime = context.knockoutStartTime or os.clock()
		local elapsed = os.clock() - startTime

		if elapsed >= KNOCKOUT_DURATION then
			return "Return"
		end

		return nil
	end,
}

return KnockedOutState
