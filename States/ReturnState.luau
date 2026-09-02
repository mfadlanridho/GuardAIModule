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
	context.humanoid.WalkSpeed = context.moveSpeed
	local targetPos = (context.restPart and context.restPart.Position) or context.startPos
	if targetPos then
		context.humanoid:MoveTo(targetPos)
	end
end

function ReturnState.exit(context: Types.GuardAIContext, toState: string?)
	-- Clean up targets
end

function ReturnState.update(context: Types.GuardAIContext, dt: number, stateTime: number): string?
	local targetPos = (context.restPart and context.restPart.Position) or context.startPos
	if not targetPos then
		return "Idle"
	end

	local dist = (context.primaryPart.Position - targetPos).Magnitude
	if dist <= 4.0 then
		-- Align orientation with rest spot if configured
		if context.restCFrame and context.model then
			context.model:PivotTo(context.restCFrame)
		end

		if typeof(context.onReturnedToPost) == "function" then
			context.onReturnedToPost()
		end
		return "Idle"
	end

	return nil
end

return ReturnState
