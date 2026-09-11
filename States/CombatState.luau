--!strict
--[[
	CombatState.luau (GuardAIModule)
	Dedicated Combat state for Guardians when dueling an active Pet Companion.
	Halts pursuit of the player, anchors attention on the companion duelist,
	and participates in the turn-based duel until disengaged.
--]]

local CombatState = {
	name = "Combat",

	canEnter = function(context: any, fromState: string?): (boolean, string?)
		if not context.model or not context.model.Parent then
			return false, "No valid guard model"
		end
		return true, nil
	end,

	enter = function(context: any, fromState: string?)
		-- Stop active pathfinding/chase movement towards player
		if context.stopMovement then
			context.stopMovement()
		elseif context.humanoid and context.primaryPart then
			context.humanoid:MoveTo(context.primaryPart.Position)
		end

		if context.model and context.model.Parent then
			context.model:SetAttribute("GuardState", "Combat")
		end

		print(string.format("🛡️ [GuardAI] %s entered COMBAT state against companion!", context.model.Name))
	end,

	exit = function(context: any, toState: string?)
		print(string.format("🛡️ [GuardAI] %s exited combat state -> %s.", context.model.Name, tostring(toState)))
	end,

	update = function(context: any): string?
		local model = context.model
		if not model or not model.Parent then
			return "Idle"
		end

		-- Check if duel is still active
		local inDuel = model:GetAttribute("InCombatDuel")
		if not inDuel then
			-- If duel ended, resume chasing player if player target still valid
			if context.currentTargetHrp and context.currentTargetHrp.Parent then
				return "Chase"
			end
			return "Return"
		end

		return nil
	end,
}

return CombatState
