--!strict
--[[
    GuardAIModule - Types.luau
    Exported type definitions for GuardAI instances, configs, and FSM contexts.
--]]

export type GuardAIConfig = {
	detectionRadius: number?,
	moveSpeed: number?,
	attackRadius: number?,
	attackRecoveryTime: number?,
	platformPart: BasePart?,
	onAttackHit: ((victimModel: Model) -> ())?,
}

export type GuardAIContext = {
	model: Model,
	primaryPart: BasePart,
	humanoid: Humanoid,
	startPos: Vector3,
	detectionRadius: number,
	moveSpeed: number,
	attackRadius: number,
	attackRecoveryTime: number,
	onAttackHit: ((victimModel: Model) -> ())?,
	isPlayerOnPlatform: (player: Player, platform: BasePart?) -> boolean,
	platformPart: BasePart?,
	waypoints: { BasePart },
	currentWaypointIndex: number,
	currentTargetHrp: BasePart?,
	lastTargetTime: number,
	patrolStartTime: number,
	isAttacking: boolean,
	deltaTime: number?,
	isDormant: boolean?,
}

export type GuardAIInstance = {
	model: Model,
	primaryPart: BasePart,
	humanoid: Humanoid,
	context: GuardAIContext,
	stateMachine: any,
	isDestroyed: boolean,
	platformPart: BasePart?,
	heartbeatConn: RBXScriptConnection?,
	touchConn: RBXScriptConnection?,
}

return {}
