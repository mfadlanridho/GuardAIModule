--!strict
--[[
    GuardAIModule - ReturnState.luau
    State where the Guard NPC pathfinds back to its start position (nest/post).
    Upon reaching startPos, invokes context.onReturnedToPost() and transitions back to Idle state.
--]]

local Types = require(script.Parent.Parent.Types)

local ReturnState = {}
ReturnState.name = "Return"

function ReturnState.canEnter(context: Types.GuardAIContext, fromState: string?): (boolean, string?)
	return true, nil
end

function ReturnState.enter(context: Types.GuardAIContext, fromState: string?)
	local targetPos = (context.restCFrame and context.restCFrame.Position) or (context.restPart and context.restPart.Position) or context.startPos
	if targetPos then
		if context.locomotionMode == "Fly" and context.setMoveTarget then
			local flyTarget = (context.restCFrame and context.restCFrame.Position) or (targetPos + Vector3.new(0, context.hoverAltitude or 3.5, 0))
			context.setMoveTarget(flyTarget, targetPos)
		elseif context.setMoveTarget then
			context.setMoveTarget(targetPos, nil)
		else
			context.humanoid.WalkSpeed = context.moveSpeed
			context.humanoid:MoveTo(targetPos)
		end
	end
end

function ReturnState.exit(context: Types.GuardAIContext, toState: string?)
	if context.stopMovement then
		context.stopMovement()
	end
end

function ReturnState.update(context: Types.GuardAIContext, dt: number, stateTime: number): string?
	local targetPos = (context.restCFrame and context.restCFrame.Position) or (context.restPart and context.restPart.Position) or context.startPos
	if not targetPos then
		return "Idle"
	end

	local dist = (context.primaryPart.Position - targetPos).Magnitude

	if context.locomotionMode == "Fly" and context.setMoveTarget then
		local flyTarget = (context.restCFrame and context.restCFrame.Position) or (targetPos + Vector3.new(0, context.hoverAltitude or 3.5, 0))
		-- On final approach (< 12 studs), steer orientation towards resting CFrame
		local lookTarget = targetPos
		if dist < 12.0 and context.restCFrame then
			lookTarget = context.primaryPart.Position + context.restCFrame.LookVector
		end
		context.setMoveTarget(flyTarget, lookTarget)
	end

	if dist <= 4.0 then
		if context.stopMovement then
			context.stopMovement()
		end

		-- Cleanly snap to canonical resting CFrame
		if context.restCFrame then
			if context.primaryPart then
				context.primaryPart.CFrame = context.restCFrame
			elseif context.model then
				context.model:PivotTo(context.restCFrame)
			end
		end

		if typeof(context.onReturnedToPost) == "function" then
			context.onReturnedToPost()
		end
		return "Idle"
	end

	return nil
end

return ReturnState
