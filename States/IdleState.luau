--!strict
--[[
    IdleState.luau
    Universal Guard AI Idle State.
    Dormant standby state; monitors platform zone entry and vision range scans.
--]]

local Players = game:GetService("Players")

local IdleState = {}
IdleState.name = "Idle"

function IdleState.canEnter(context: any, fromState: string?): (boolean, string?)
	return true, nil
end

function IdleState.enter(context: any, fromState: string?)
	if context.stopMovement then
		context.stopMovement()
	elseif context.humanoid and context.primaryPart then
		context.humanoid:MoveTo(context.primaryPart.Position)
	end

	-- Reorient and lock to canonical resting CFrame inside the submodule
	if context.restCFrame then
		if context.primaryPart then
			context.primaryPart.CFrame = context.restCFrame
		elseif context.model then
			context.model:PivotTo(context.restCFrame)
		end

		if context.alignOrientation and context.alignOrientation.Parent then
			context.alignOrientation.CFrame = context.restCFrame
		end
		if context.alignPosition and context.alignPosition.Parent then
			context.alignPosition.Position = context.restCFrame.Position
		end
	end
end

function IdleState.exit(context: any, toState: string?)
end

function IdleState.update(context: any): string?
	-- Check if engaged in combat duel with a companion
	if context.model and context.model:GetAttribute("InCombatDuel") then
		return "Combat"
	end

	if context.isDormant then
		return nil
	end

	local primaryPart = context.primaryPart
	if not primaryPart then return nil end

	-- Vision scan for nearest player within detection radius
	local nearestHrp: BasePart? = nil
	local shortestDist = context.detectionRadius or 40

	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp then
			local dist = (hrp.Position - primaryPart.Position).Magnitude
			if dist < shortestDist then
				shortestDist = dist
				nearestHrp = hrp
			end
		end
	end

	if nearestHrp then
		context.currentTargetHrp = nearestHrp
		return "Chase"
	end

	-- Transition to Patrol if waypoints exist
	if context.waypoints and #context.waypoints > 0 then
		return "Patrol"
	end

	return nil
end

return IdleState
