--!strict
--[[
    GuardAIModule - RetrieveState.luau
    State where the Guard NPC pathfinds to a dropped item on the ground.
    Upon reaching the item, invokes context.onItemReached(item) and transitions to Return state.
--]]

local Types = require(script.Parent.Parent.Types)

local RetrieveState = {}
RetrieveState.name = "Retrieve"

function RetrieveState.canEnter(context: Types.GuardAIContext, fromState: string?): (boolean, string?)
	if not context.targetItem then
		return false, "no_target_item"
	end
	return true, nil
end

function RetrieveState.enter(context: Types.GuardAIContext, fromState: string?)
	context.humanoid.WalkSpeed = context.moveSpeed
	local item = context.targetItem
	if item then
		local pos = if item:IsA("BasePart") then item.Position
			elseif item:IsA("Model") and item.PrimaryPart then item.PrimaryPart.Position
			else nil

		if pos then
			context.humanoid:MoveTo(pos)
		end
	end
end

function RetrieveState.exit(context: Types.GuardAIContext, toState: string?)
	-- Clean up move targets
end

function RetrieveState.update(context: Types.GuardAIContext, dt: number, stateTime: number): string?
	local item = context.targetItem
	if not item or not item.Parent then
		context.targetItem = nil
		return "Return"
	end

	local targetPos = if item:IsA("BasePart") then item.Position
		elseif item:IsA("Model") and item.PrimaryPart then item.PrimaryPart.Position
		else nil

	if not targetPos then
		context.targetItem = nil
		return "Return"
	end

	-- Distance Check
	local dist = (context.primaryPart.Position - targetPos).Magnitude
	if dist <= 5.0 then
		if typeof(context.onItemReached) == "function" then
			context.onItemReached(item)
		end
		context.targetItem = nil
		return "Return"
	end

	return nil
end

return RetrieveState
