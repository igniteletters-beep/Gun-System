local SprintModule = {}
SprintModule.__index = SprintModule

local RUN_KEY = Enum.KeyCode.LeftControl
local RUN_SPEED = 24
local WALK_SPEED = 16

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

function SprintModule.new(character)
	local self = setmetatable({}, SprintModule)

	self.character = character
	self.humanoid = character:WaitForChild("Humanoid")
	self.animator = self.humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", self.humanoid)

	self.isSprinting = false
	self.isAiming = false
	self.isReloading = false
	self.runningDisabled = false

	local runAnim = Instance.new("Animation")
	runAnim.AnimationId = "rbxassetid://121077219677311"
	self.runTrack = self.animator:LoadAnimation(runAnim)

	local walkAnim = Instance.new("Animation")
	walkAnim.AnimationId = "rbxassetid://78517189276212"
	self.walkTrack = self.animator:LoadAnimation(walkAnim)

	self:setupInput()
	self:startMonitoring()

	return self
end

function SprintModule:setupInput()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode == RUN_KEY then
			self:toggleSprint()
		end
	end)
end

function SprintModule:toggleSprint()
	if self.runningDisabled then return end
	if self.isAiming or self.isReloading then return end

	self.isSprinting = not self.isSprinting
	self:applyMovementState()
end

function SprintModule:applyMovementState()
	if not self.humanoid then return end

	if self.isAiming or self.isReloading or self.runningDisabled then
		self.humanoid.WalkSpeed = WALK_SPEED
		self:stopRunAnim()
		if not self.walkTrack.IsPlaying then self.walkTrack:Play() end
		return
	end

	if self.isSprinting then
		self.humanoid.WalkSpeed = RUN_SPEED
		self.walkTrack:Stop()
		if not self.runTrack.IsPlaying then self.runTrack:Play() end
	else
		self.humanoid.WalkSpeed = WALK_SPEED
		self:stopRunAnim()
		if not self.walkTrack.IsPlaying then self.walkTrack:Play() end
	end
end

function SprintModule:startMonitoring()
	RunService.Heartbeat:Connect(function()
		if not self.humanoid then return end
		local moving = self.humanoid.MoveDirection.Magnitude > 0
		if not moving then
			self:stopRunAnim()
			self.walkTrack:Stop()
		end
	end)
end

function SprintModule:stopRunAnim()
	if self.runTrack.IsPlaying then
		self.runTrack:Stop()
	end
end

function SprintModule:SetAiming(isAiming)
	self.isAiming = isAiming
	self:applyMovementState()
end

function SprintModule:SetReloading(isReloading)
	self.isReloading = isReloading
	self:applyMovementState()
end

function SprintModule:DisableRunning(state)
	self.runningDisabled = state
	self:applyMovementState()
end

return SprintModule
