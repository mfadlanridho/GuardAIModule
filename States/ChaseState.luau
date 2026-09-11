--!strict
--[[
    ChaseState.luau
    Universal Guard AI Chase State.
    Pursues target player calling native Humanoid:MoveTo().
--]]

local Players = game:GetService("Players")

local ChaseState = {
	name = "Chase",

	canEnter = function(context: any, fromState: string?): (boolean, string?)
		return context.currentTargetHrp ~= nil, "no_target"
	end,

	enter = function(context: any, fromState: string?)
		context.lastTargetTime = os.clock()
		if context.humanoid then
			context.humanoid.WalkSpeed = (context.moveSpeed or 16) + 2
		end
	end,

	exit = function(context: any, toState: string?)
		-- Instantly cancel active chase navigation when exiting Chase state
		if context.stopMovement then
			context.stopMovement()
		elseif context.humanoid and context.primaryPart then
			context.humanoid:MoveTo(context.primaryPart.Position)
		end
	end,

	update = function(context: any): string?
		-- Check if engaged in combat duel with a companion
		if context.model and context.model:GetAttribute("InCombatDuel") then
			return "Combat"
		end

		local primaryPart = context.primaryPart
		local humanoid = context.humanoid
		local targetHrp = context.currentTargetHrp

		if not primaryPart or not humanoid or not targetHrp or not targetHrp.Parent or not targetHrp:IsDescendantOf(workspace) then
			context.currentTargetHrp = nil
			return "Patrol"
		end

		-- Validate that target player is strictly standing inside the platform floor boundary
		local targetPlayer = Players:GetPlayerFromCharacter(targetHrp.Parent)
		if targetPlayer and context.isPlayerOnPlatform then
			if not context.isPlayerOnPlatform(targetPlayer, context.platformPart) then
				context.currentTargetHrp = nil
				return "Patrol"
			end
		end

		local dist = (targetHrp.Position - primaryPart.Position).Magnitude

		-- Check for attack distance
		if dist <= (context.attackRadius or 5.0) then
			return "Attack"
		end

		-- Check for target escape (> detectionRadius + 20 or 3s loss)
		local maxDist = (context.detectionRadius or 40) + 20
		if dist > maxDist then
			if (os.clock() - context.lastTargetTime) > 3.0 then
				context.currentTargetHrp = nil
				return "Patrol"
			end
		else
			context.lastTargetTime = os.clock()
		end

		-- Throttled Pursuit Movement with Target Displacement Thresholding
		local now = os.clock()
		if not context.lastMoveToTime or (now - context.lastMoveToTime) >= 0.15 then
			context.lastMoveToTime = now

			local threshold = context.displacementThreshold or 0.5
			local targetPos = targetHrp.Position
			local lastPos = context.lastPathTargetPos

			local displacement = if lastPos then (targetPos - lastPos).Magnitude else math.huge

			if displacement >= threshold then
				context.lastPathTargetPos = targetPos
				if context.locomotionMode == "Fly" then
					local flightPos = targetPos + Vector3.new(0, context.hoverAltitude or 3.5, 0)
					if context.setMoveTarget then
						context.setMoveTarget(flightPos, targetPos)
					end
				else
					if context.setMoveTarget then
						context.setMoveTarget(targetPos, nil)
					else
						humanoid:MoveTo(targetPos)
					end
				end
			end
		end

		return nil
	end,
}

return ChaseState
