--!strict
--[[
    AttackState.luau
    Universal Guard AI Attack State.
    Executes attack lunge movement and calls onAttackHit callback.
--]]

local AttackState = {
	name = "Attack",

	canEnter = function(context: any, fromState: string?): (boolean, string?)
		return true, nil
	end,

	enter = function(context: any, fromState: string?)
		context.isAttacking = true

		task.spawn(function()
			local primaryPart = context.primaryPart
			local targetHrp = context.currentTargetHrp

			if primaryPart and targetHrp and targetHrp.Parent then
				-- Attack Lunge forward towards target
				local attackDir = (targetHrp.Position - primaryPart.Position).Unit
				if context.locomotionMode == "Fly" and context.setMoveTarget then
					local diveSpeed = (context.flightSpeed or context.moveSpeed or 16) * 1.5
					context.setMoveTarget(targetHrp.Position + Vector3.new(0, 1.0, 0), targetHrp.Position, diveSpeed)
				elseif context.humanoid then
					context.humanoid:MoveTo(primaryPart.Position + (attackDir * 3))
				end

				-- Invoke Attack Callback
				if context.onAttackHit then
					context.onAttackHit(targetHrp.Parent)
				end
			end

			task.wait(context.attackRecoveryTime or 0.5)
			context.isAttacking = false
		end)
	end,

	exit = function(context: any, toState: string?)
	end,

	update = function(context: any): string?
		if not context.isAttacking then
			return "Chase"
		end
		return nil
	end,
}

return AttackState
