local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local tool = script.Parent
local GUI = player:WaitForChild("PlayerGui"):WaitForChild("GunGUI")
local Frame = GUI:WaitForChild("Frame")
local GunName = Frame:WaitForChild("GunName")
local AmmoLabel = Frame:WaitForChild("Ammo")
local MagCountLabel = Frame:WaitForChild("MagCount")
local AimGUI = player:WaitForChild("PlayerGui"):WaitForChild("Aim")
local Animations = ReplicatedStorage.Assets.Animations.AssultRifle
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
local holdAnim = animator:LoadAnimation(Animations.GunHold)
local shootAnim = animator:LoadAnimation(Animations.GunShoot)
local reloadAnim = animator:LoadAnimation(Animations.GunReload)
local EquipAnimation = animator:LoadAnimation(Animations.GunEquip)
local UnEquipAnimation = animator:LoadAnimation(Animations.GunUnEquip)
local AimAnimation = animator:LoadAnimation(Animations.GunAim)
local GunInspect = animator:LoadAnimation(Animations.GunInspect)
local PlayerModule = player.PlayerScripts:WaitForChild("PlayerModule")
local CameraModule = PlayerModule:WaitForChild("CameraModule")
local MouseLockController = require(CameraModule:WaitForChild("MouseLockController"))
local CameraUtils = require(CameraModule:WaitForChild("CameraUtils"))
local mouseLock = MouseLockController.new()
local sprintController = nil
do
	local ok, Running = pcall(function()
		return require(ReplicatedStorage.Modules:WaitForChild("Running"))
	end)
	if ok and type(Running) == "table" and Running.new then
		local success, inst = pcall(function() return Running.new(character) end)
		if success and inst then sprintController = inst end
	end
end
local config = {
	DamagePerBullet = 6,
	MaxAmmo = 34,
	SpreadAngle = 0,
	MaxTravelDistance = 150,
	BulletsPerShot = 1,
	Auto = true,
	ShotDelay = 0.1
}
local ammo = config.MaxAmmo
local reloading = false
local canShoot = true
local holdingMouse = false
local equipped = false
local aiming = false
local mags = tool:WaitForChild("CurrentMags")
local activeBlockers = {aiming=false, reloading=false}
local normalWalkSpeed = 16
local reducedWalkSpeed = normalWalkSpeed - 7
local sensitivityMultiplier = 0.3
local ShootEvent = ReplicatedStorage.RemoteEvents:WaitForChild("AssultRifleShoot")
local ShotVFX = ReplicatedStorage.Assets.VFX:WaitForChild("Shot")
local recoilAmount = Vector3.new(1,0.3,0)
local recoilRecoverTime = 0.05
local function applyRecoil()
	local cam = workspace.CurrentCamera
	cam.CFrame *= CFrame.Angles(math.rad(recoilAmount.X), math.rad(recoilAmount.Y), 0)
	task.delay(recoilRecoverTime, function()
		cam.CFrame *= CFrame.Angles(math.rad(-recoilAmount.X), math.rad(-recoilAmount.Y), 0)
	end)
end
local function dropMag()
	local mag = tool:FindFirstChild("Mag")
	if not mag then return end
	local dupMag = mag:Clone()
	dupMag.Parent = workspace
	mag.Transparency = 1
	for _, c in ipairs(dupMag:GetDescendants()) do
		if c:IsA("WeldConstraint") then c:Destroy() end
	end
	if dupMag:IsA("BasePart") then
		dupMag.Anchored = false
		dupMag.CanCollide = true
		dupMag.CFrame = mag.CFrame * CFrame.new(0,-0.5,0)
	end
	task.delay(4, function()
		if dupMag then dupMag:Destroy() end
		if mag then mag.Transparency = 0 end
	end)
end
if reloadAnim.GetMarkerReachedSignal then
	reloadAnim:GetMarkerReachedSignal("DropMag"):Connect(function()
		pcall(dropMag)
	end)
end
local function refreshSprint()
	if not sprintController then return end
	local anyBlocker = activeBlockers.aiming or activeBlockers.reloading
	pcall(function()
		sprintController:SetAiming(activeBlockers.aiming)
		sprintController:DisableRunning(anyBlocker)
		if sprintController.ForceAnimationUpdate then
			pcall(function() sprintController:ForceAnimationUpdate() end)
		end
	end)
	if anyBlocker then
		humanoid.WalkSpeed = activeBlockers.aiming and reducedWalkSpeed or normalWalkSpeed
	else
		local target = normalWalkSpeed
		if sprintController and sprintController.isSprinting then target = 24 end
		humanoid.WalkSpeed = target
	end
end
local function shoot()
	if not equipped or not canShoot or reloading or ammo <= 0 then return end
	canShoot = false
	ammo -= 1
	AmmoLabel.Text = ammo.."/"..config.MaxAmmo
	shootAnim:Play()
	local handle = tool:FindFirstChild("Handle") or tool:FindFirstChildOfClass("BasePart")
	if not handle then warn("No handle") canShoot=true return end
	local origin = handle.Position + Vector3.new(0,0,0.0015)
	local direction = workspace.CurrentCamera.CFrame.LookVector + Vector3.new(0,0.025,0.0015)
	ShootEvent:FireServer({
		Origin = origin,
		Direction = direction,
		BulletsPerShot = config.BulletsPerShot,
		MaxTravelDistance = config.MaxTravelDistance,
		SpreadAngle = config.SpreadAngle,
		DamagePerBullet = config.DamagePerBullet
	})
	applyRecoil()
	local flash = Instance.new("PointLight")
	flash.Color = Color3.new(1, 0.85, 0.6)
	flash.Brightness = 5
	flash.Range = 10
	flash.Parent = handle
	task.delay(0.05, function() flash:Destroy() end)
	local shell = ReplicatedStorage.Assets.Bullets:FindFirstChild("Ak47Bullet"):Clone()
	shell.PrimaryPart.CFrame = handle.CFrame * CFrame.new(0, 0.1, 0)
	shell.Parent = workspace
	shell.PrimaryPart.Velocity = handle.CFrame.RightVector * 25 + Vector3.new(0, 8, 0)
	game.Debris:AddItem(shell, 2)
	local fx = ShotVFX:Clone()
	fx.Parent = workspace
	fx.Position = handle.Position
	for _, v in ipairs(fx.Main:GetChildren()) do
		if v:IsA("ParticleEmitter") then
			local ok, count = pcall(function() return v:GetAttribute("EmitCount") end)
			if ok and count then v:Emit(count) end
		end
	end
	task.delay(config.ShotDelay, function() canShoot=true end)
end
local reloadThread
local function reload()
	if not equipped or reloading or ammo>=config.MaxAmmo or mags.Value<=0 then return end
	reloading = true
	activeBlockers.reloading = true
	refreshSprint()
	sprintController:SetReloading(true)
	reloadAnim:Play()
	reloadThread = task.spawn(function()
		local length = reloadAnim.Length or 1
		local start = tick()
		while tick()-start < length do
			if not reloading or not equipped then
				reloading=false
				activeBlockers.reloading=false
				refreshSprint()
				return
			end
			task.wait()
		end
		if reloading and equipped then
			ammo = config.MaxAmmo
			AmmoLabel.Text = ammo.."/"..config.MaxAmmo
			if mags.Value>0 then mags.Value -= 1 end
			MagCountLabel.Text = "MAGS: "..mags.Value
			reloading=false
			activeBlockers.reloading=false
			sprintController:SetReloading(false)
			refreshSprint()
		end
	end)
end
local conns = {}
tool.Equipped:Connect(function(mouse)
	EquipAnimation:Play()
	equipped=true
	Frame.Visible=true
	GunName.Text=tool.Name
	AmmoLabel.Text=ammo.."/"..config.MaxAmmo
	MagCountLabel.Text="MAGS: "..mags.Value
	holdAnim:Play()
	AimGUI.Enabled=true
	UserInputService.MouseIconEnabled=false
	mouseLock.preventUnlock=true
	mouseLock.enabled=true
	mouseLock.boundKeys={}
	if not mouseLock:GetIsMouseLocked() then mouseLock:OnMouseLockToggled() end
	local rotateBind = RunService.RenderStepped:Connect(function()
		if mouseLock:GetIsMouseLocked() then
			local root = character:FindFirstChild("HumanoidRootPart")
			local cam = workspace.CurrentCamera
			if root and cam then
				local rootPos=root.Position
				local lookVector=Vector3.new(cam.CFrame.LookVector.X,0,cam.CFrame.LookVector.Z)
				if lookVector.Magnitude>0 then
					lookVector=lookVector.Unit
					root.CFrame=CFrame.new(rootPos, rootPos+lookVector)
					cam.CFrame=cam.CFrame+cam.CFrame.RightVector*2
				end
			end
		end
	end)
	table.insert(conns, rotateBind)
	local mdown = mouse.Button1Down:Connect(function()
		if not equipped then return end
		holdingMouse=true
		if config.Auto then
			task.spawn(function()
				while holdingMouse and canShoot and equipped do
					shoot()
					task.wait(config.ShotDelay)
				end
			end)
		else shoot() end
	end)
	local mup = mouse.Button1Up:Connect(function() holdingMouse=false end)
	table.insert(conns, mdown)
	table.insert(conns, mup)
	local inputBegan = UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.KeyCode==Enum.KeyCode.R and equipped then
			reload()
		end
		if input.KeyCode==Enum.KeyCode.E and equipped then
			GunInspect:Play()
			GunInspect.Stopped:Wait()
		end
		if input.UserInputType==Enum.UserInputType.MouseButton2 and equipped then
			aiming=true
			AimAnimation:Play()
			activeBlockers.aiming=true
			sprintController:SetAiming(true)
			refreshSprint()
			if CameraUtils.SetMouseSensitivityMultiplier then pcall(function() CameraUtils.SetMouseSensitivityMultiplier(sensitivityMultiplier) end) end
			if CameraUtils.SetSensitivityMultiplier then pcall(function() CameraUtils.SetSensitivityMultiplier(sensitivityMultiplier) end) end
			local tween=TweenService:Create(workspace.CurrentCamera,TweenInfo.new(0.15,Enum.EasingStyle.Sine,Enum.EasingDirection.Out),{FieldOfView=30})
			tween:Play()
		end
	end)
	local inputEnded = UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType==Enum.UserInputType.MouseButton2 and equipped then
			aiming=false
			AimAnimation:Stop()
			activeBlockers.aiming=false
			sprintController:SetAiming(false)
			refreshSprint()
			if CameraUtils.SetMouseSensitivityMultiplier then pcall(function() CameraUtils.SetMouseSensitivityMultiplier(1) end) end
			if CameraUtils.SetSensitivityMultiplier then pcall(function() CameraUtils.SetSensitivityMultiplier(1) end) end
			local tween=TweenService:Create(workspace.CurrentCamera,TweenInfo.new(0.15,Enum.EasingStyle.Sine,Enum.EasingDirection.Out),{FieldOfView=70})
			tween:Play()
		end
	end)
	table.insert(conns,inputBegan)
	table.insert(conns,inputEnded)
end)
tool.Unequipped:Connect(function()
	UnEquipAnimation:Play()
	equipped=false
	reloading=false
	aiming=false
	activeBlockers.aiming=false
	activeBlockers.reloading=false
	if reloadThread then pcall(function() task.cancel(reloadThread) end) end
	refreshSprint()
	for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
	conns={}
	mouseLock.preventUnlock=false
	mouseLock.boundKeys={Enum.KeyCode.LeftShift,Enum.KeyCode.RightShift}
	if mouseLock:GetIsMouseLocked() then mouseLock:OnMouseLockToggled() end
	UserInputService.MouseIconEnabled=true
	Frame.Visible=false
	AimGUI.Enabled=false
	holdAnim:Stop()
	shootAnim:Stop()
	reloadAnim:Stop()
	holdingMouse=false
	humanoid.WalkSpeed=normalWalkSpeed
	pcall(function() workspace.CurrentCamera.FieldOfView=70 end)
	if CameraUtils.SetMouseSensitivityMultiplier then pcall(function() CameraUtils.SetMouseSensitivityMultiplier(1) end) end
	if CameraUtils.SetSensitivityMultiplier then pcall(function() CameraUtils.SetSensitivityMultiplier(1) end) end
end)
