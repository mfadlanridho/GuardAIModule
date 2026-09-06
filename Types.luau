--!strict
--[[
    GuardAIModule - Types.luau
    Exported type definitions for GuardAI instances, configs, and FSM contexts.
--]]

export type GuardAIConfig = {
	locomotionMode: ("Walk" | "Fly")?,
	hoverAltitude: number?,
	flightSpeed: number?,
	turnResponsiveness: number?,
	detectionRadius: number?,
	moveSpeed: number?,
	attackRadius: number?,
	attackRecoveryTime: number?,
	displacementThreshold: number?,
	serverNetworkOwner: boolean?,
	platformPart: BasePart?,
	restPart: BasePart?,
	restCFrame: CFrame?,
	onAttackHit: ((victimModel: Model) -> ())?,
	onItemReached: ((targetItem: Instance) -> ())?,
	onReturnedToPost: (() -> ())?,
}

export type GuardAIContext = {
	model: Model,
	primaryPart: BasePart,
	humanoid: Humanoid,
	locomotionMode: "Walk" | "Fly",
	hoverAltitude: number,
	flightSpeed: number,
	turnResponsiveness: number,
	alignPosition: AlignPosition?,
	alignOrientation: AlignOrientation?,
	setMoveTarget: (targetPos: Vector3, lookAtPos: Vector3?, overrideSpeed: number?) -> (),
	stopMovement: () -> (),
	startPos: Vector3,
	restPart: BasePart?,
	restCFrame: CFrame?,
	detectionRadius: number,
	moveSpeed: number,
	attackRadius: number,
	attackRecoveryTime: number,
	displacementThreshold: number,
	serverNetworkOwner: boolean,
	onAttackHit: ((victimModel: Model) -> ())?,
	onItemReached: ((targetItem: Instance) -> ())?,
	onReturnedToPost: (() -> ())?,
	targetItem: Instance?,
	isPlayerOnPlatform: (player: Player, platform: BasePart?) -> boolean,
	platformPart: BasePart?,
	waypoints: { BasePart },
	currentWaypointIndex: number,
	currentTargetHrp: BasePart?,
	lastPathTargetPos: Vector3?,
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
