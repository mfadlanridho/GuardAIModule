--!nonstrict
--[[
    GuardAIModule (init.luau)
    Modular, standalone OOP Humanoid Guard AI engine.
    Drives NPC navigation using native Humanoid:MoveTo() and a 4-state Finite State Machine.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Types = require(script.Types)

export type GuardAIConfig = Types.GuardAIConfig
export type GuardAIContext = Types.GuardAIContext
export type GuardAIInstance = Types.GuardAIInstance

-- Dependency Resolution
local function resolvePackage(packageName: string): ModuleScript?
	local submodulesFolder = ReplicatedStorage:FindFirstChild("Submodules")
	if submodulesFolder and submodulesFolder:FindFirstChild(packageName) then
		return submodulesFolder:FindFirstChild(packageName) :: ModuleScript?
	end

	local packagesFolder = ReplicatedStorage:FindFirstChild("Packages") or script.Parent
	return packagesFolder:FindFirstChild(packageName) :: ModuleScript?
end

local stateMachineScript = resolvePackage("StateMachineModule") or (ReplicatedStorage:FindFirstChild("Submodules") and ReplicatedStorage.Submodules:FindFirstChild("StateMachineModule")) or ReplicatedStorage:WaitForChild("Packages"):WaitForChild("StateMachineModule")
local StateMachine = require(stateMachineScript :: ModuleScript)

local loggerScript = resolvePackage("LoggerModule")
local log = if loggerScript then require(loggerScript :: ModuleScript).create("Combat") else function(msg: string) print(msg) end

local StatesFolder = script:WaitForChild("States")
local IdleState = require(StatesFolder:WaitForChild("IdleState") :: ModuleScript)
local PatrolState = require(StatesFolder:WaitForChild("PatrolState") :: ModuleScript)
local ChaseState = require(StatesFolder:WaitForChild("ChaseState") :: ModuleScript)
local AttackState = require(StatesFolder:WaitForChild("AttackState") :: ModuleScript)
local RetrieveState = require(StatesFolder:WaitForChild("RetrieveState") :: ModuleScript)
local ReturnState = require(StatesFolder:WaitForChild("ReturnState") :: ModuleScript)

local GuardAI = {}
GuardAI.__index = GuardAI

-- Strict Spatial Footprint Check: Exact physical bounds of platform floor
local function isPlayerOnPlatform(player: Player, platform: BasePart?): boolean
	if not platform then return true end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then return false end

	local relPos = platform.CFrame:PointToObjectSpace(hrp.Position)
	local halfSize = platform.Size * 0.5
	return math.abs(relPos.X) <= halfSize.X 
	   and math.abs(relPos.Z) <= halfSize.Z 
	   and relPos.Y >= -4 and relPos.Y <= halfSize.Y + 15
end

function GuardAI.new(model: Model, config: GuardAIConfig?): GuardAIInstance
	local self = setmetatable({}, GuardAI) :: any
	self.model = model
	
	-- Ensure Humanoid instance exists
	local humanoid = model:FindFirstChildWhichIsA("Humanoid")
	if not humanoid then
		humanoid = Instance.new("Humanoid")
		humanoid.Name = "Humanoid"
		humanoid.Parent = model
	end
	self.humanoid = humanoid :: Humanoid

	-- Hide Roblox Default Healthbar & Nametag
	self.humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	self.humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff

	self.primaryPart = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildWhichIsA("BasePart")
	self.isDestroyed = false

	-- Resolve Platform Part
	local resolvedPlatform: BasePart? = config and config.platformPart
	if not resolvedPlatform then
		local attrPart = model:GetAttribute("PlatformPart")
		if typeof(attrPart) == "Instance" and attrPart:IsA("BasePart") then
			resolvedPlatform = attrPart
		elseif model.Parent and model.Parent:IsA("Model") then
			local floor = model.Parent:FindFirstChild("PlatformFloor")
			if floor and floor:IsA("BasePart") then
				resolvedPlatform = floor
			else
				resolvedPlatform = model.Parent:FindFirstChildWhichIsA("BasePart")
			end
		end
	end
	self.platformPart = resolvedPlatform

	-- Resolve Waypoints Folder if present inside Platform model
	local waypointsList = {}
	local parentModel = model.Parent
	local waypointsFolder = (model:FindFirstChild("Waypoints") or (parentModel and parentModel:FindFirstChild("Waypoints"))) :: Instance?
	if waypointsFolder then
		for _, child in ipairs(waypointsFolder:GetChildren()) do
			if child:IsA("BasePart") then
				table.insert(waypointsList, child)
			end
		end
	end

	-- Resolve Rest Spot / Guard Post Part
	local resolvedRestPart: BasePart? = config and config.restPart
	if not resolvedRestPart then
		local childSpot = model:FindFirstChild("RestSpot") or model:FindFirstChild("GuardSpot")
		if childSpot and childSpot:IsA("BasePart") then
			resolvedRestPart = childSpot
		elseif childSpot and childSpot:IsA("ObjectValue") and childSpot.Value and childSpot.Value:IsA("BasePart") then
			resolvedRestPart = childSpot.Value :: BasePart
		end
	end

	local primaryPart = self.primaryPart
	local startPos = if resolvedRestPart then resolvedRestPart.Position else (primaryPart and primaryPart.Position or Vector3.zero)
	local restCFrame = if resolvedRestPart then resolvedRestPart.CFrame else (primaryPart and primaryPart.CFrame or nil)

	local useServerNetwork = if config and config.serverNetworkOwner ~= nil then config.serverNetworkOwner else true

	local locomotionMode: "Walk" | "Fly" = (config and config.locomotionMode) or model:GetAttribute("LocomotionMode") or "Walk"
	local hoverAltitude = config and config.hoverAltitude or model:GetAttribute("HoverAltitude") or 3.5
	local flightSpeed = config and config.flightSpeed or model:GetAttribute("FlightSpeed") or (config and config.moveSpeed) or model:GetAttribute("MoveSpeed") or 16
	local turnResponsiveness = config and config.turnResponsiveness or 20

	-- Resolve or create flight constraints if in Fly mode
	local alignPos: AlignPosition? = nil
	local alignOrient: AlignOrientation? = nil
	if locomotionMode == "Fly" and primaryPart then
		local rootAtt = primaryPart:FindFirstChild("RootAttachment") :: Attachment?
		if not rootAtt then
			rootAtt = Instance.new("Attachment")
			rootAtt.Name = "RootAttachment"
			rootAtt.Parent = primaryPart
		end

		alignPos = primaryPart:FindFirstChild("FlightAlignPosition") :: AlignPosition?
		if not alignPos then
			alignPos = Instance.new("AlignPosition")
			alignPos.Name = "FlightAlignPosition"
			alignPos.Mode = Enum.PositionAlignmentMode.OneAttachment
			alignPos.Attachment0 = rootAtt
			alignPos.MaxForce = 1000000
			alignPos.MaxVelocity = flightSpeed
			alignPos.Responsiveness = 15
			alignPos.Position = primaryPart.Position
			alignPos.Enabled = false
			alignPos.Parent = primaryPart
		end

		alignOrient = primaryPart:FindFirstChild("FlightAlignOrientation") :: AlignOrientation?
		if not alignOrient then
			alignOrient = Instance.new("AlignOrientation")
			alignOrient.Name = "FlightAlignOrientation"
			alignOrient.Mode = Enum.OrientationAlignmentMode.OneAttachment
			alignOrient.Attachment0 = rootAtt
			alignOrient.MaxTorque = 1000000
			alignOrient.Responsiveness = turnResponsiveness
			alignOrient.CFrame = primaryPart.CFrame
			alignOrient.Enabled = false
			alignOrient.Parent = primaryPart
		end
	end

	local setMoveTarget = function(targetPos: Vector3, lookAtPos: Vector3?, overrideSpeed: number?)
		if locomotionMode == "Fly" then
			if alignPos and alignOrient then
				alignPos.Enabled = true
				alignOrient.Enabled = true
				self.humanoid.PlatformStand = true
				alignPos.MaxVelocity = overrideSpeed or flightSpeed
				alignPos.Position = targetPos
				if lookAtPos and primaryPart then
					local flatDir = Vector3.new(lookAtPos.X - primaryPart.Position.X, 0, lookAtPos.Z - primaryPart.Position.Z)
					if flatDir.Magnitude > 0.1 then
						alignOrient.CFrame = CFrame.lookAt(primaryPart.Position, primaryPart.Position + flatDir)
					end
				elseif primaryPart then
					local moveDir = targetPos - primaryPart.Position
					if moveDir.Magnitude > 0.1 then
						alignOrient.CFrame = CFrame.lookAt(primaryPart.Position, primaryPart.Position + Vector3.new(moveDir.X, 0, moveDir.Z))
					end
				end
			end
		else
			self.humanoid.WalkSpeed = overrideSpeed or (config and config.moveSpeed or 16)
			self.humanoid:MoveTo(targetPos)
		end
	end

	local stopMovement = function()
		if locomotionMode == "Fly" then
			if alignPos and primaryPart then
				alignPos.Position = primaryPart.Position
			end
		else
			if primaryPart then
				self.humanoid:MoveTo(primaryPart.Position)
			end
		end
	end

	self.context = {
		model = model,
		primaryPart = primaryPart,
		humanoid = self.humanoid,
		locomotionMode = locomotionMode,
		hoverAltitude = hoverAltitude,
		flightSpeed = flightSpeed,
		turnResponsiveness = turnResponsiveness,
		alignPosition = alignPos,
		alignOrientation = alignOrient,
		setMoveTarget = setMoveTarget,
		stopMovement = stopMovement,
		startPos = startPos,
		restPart = resolvedRestPart,
		restCFrame = restCFrame,
		detectionRadius = config and config.detectionRadius or model:GetAttribute("DetectionRadius") or 40,
		moveSpeed = config and config.moveSpeed or model:GetAttribute("MoveSpeed") or 16,
		attackRadius = config and config.attackRadius or 5.0,
		attackRecoveryTime = config and config.attackRecoveryTime or 0.5,
		displacementThreshold = config and config.displacementThreshold or model:GetAttribute("DisplacementThreshold") or 0.5,
		serverNetworkOwner = useServerNetwork,
		onAttackHit = config and config.onAttackHit,
		onItemReached = config and config.onItemReached,
		onReturnedToPost = config and config.onReturnedToPost,
		targetItem = nil,
		isPlayerOnPlatform = isPlayerOnPlatform,
		platformPart = resolvedPlatform,
		waypoints = waypointsList,
		currentWaypointIndex = 1,
		currentTargetHrp = nil,
		lastPathTargetPos = nil,
		lastTargetTime = 0,
		patrolStartTime = os.clock(),
		isAttacking = false,
	}

	self:init()
	return self
end

function GuardAI:init()
	if not self.primaryPart then return end

	-- Lock Server Network Ownership for Anti-Exploit Security (if enabled)
	if self.context.serverNetworkOwner and self.primaryPart:IsA("BasePart") and RunService:IsServer() then
		pcall(function()
			self.primaryPart:SetNetworkOwner(nil)
		end)
	end

	-- Touch listener for direct physical contact
	self.touchConn = self.primaryPart.Touched:Connect(function(hit)
		local character = hit.Parent
		if not character then return end
		local player = Players:GetPlayerFromCharacter(character)
		if player and self.context.onAttackHit then
			log(string.format("[GuardAI] %s physical touch hit on player %s!", self.model.Name, player.Name))
			self.context.onAttackHit(character)
		end
	end)

	-- Initialize FSM StateMachine with generic states
	self.stateMachine = StateMachine.new(function(oldState, newState)
		log(string.format("[GuardAI] %s transitioned: %s -> %s", self.model.Name, tostring(oldState), tostring(newState)))
		if newState and self.model and self.model.Parent then
			self.model:SetAttribute("GuardState", newState)
		end
	end)

	self.stateMachine:registerState(IdleState)
	self.stateMachine:registerState(PatrolState)
	self.stateMachine:registerState(ChaseState)
	self.stateMachine:registerState(AttackState)
	self.stateMachine:registerState(RetrieveState)
	self.stateMachine:registerState(ReturnState)

	-- Start FSM in Patrol State
	self.stateMachine:setState("Patrol", self.context)

	-- Main Heartbeat Loop executing FSM state updates
	self.heartbeatConn = RunService.Heartbeat:Connect(function(dt)
		if self.isDestroyed or not self.primaryPart or not self.primaryPart.Parent then
			self:destroy()
			return
		end

		self.context.deltaTime = dt
		self.stateMachine:update(self.context, dt)
	end)
end

function GuardAI:destroy()
	self.isDestroyed = true
	if self.heartbeatConn then
		self.heartbeatConn:Disconnect()
		self.heartbeatConn = nil
	end
	if self.touchConn then
		self.touchConn:Disconnect()
		self.touchConn = nil
	end
end

return GuardAI
