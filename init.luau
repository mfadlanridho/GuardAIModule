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

	local primaryPart = self.primaryPart
	local startPos = primaryPart and primaryPart.Position or Vector3.zero

	local useServerNetwork = if config and config.serverNetworkOwner ~= nil then config.serverNetworkOwner else true

	self.context = {
		model = model,
		primaryPart = primaryPart,
		humanoid = self.humanoid,
		startPos = startPos,
		detectionRadius = config and config.detectionRadius or model:GetAttribute("DetectionRadius") or 40,
		moveSpeed = config and config.moveSpeed or model:GetAttribute("MoveSpeed") or 16,
		attackRadius = config and config.attackRadius or 5.0,
		attackRecoveryTime = config and config.attackRecoveryTime or 0.5,
		displacementThreshold = config and config.displacementThreshold or 6.0,
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
