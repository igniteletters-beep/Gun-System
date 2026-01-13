local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local ShotGunEvent = RemoteEvents:WaitForChild("ShotGunShoot")
local PistolEvent = RemoteEvents:WaitForChild("PistolShoot")
local AssultRifleEvent = RemoteEvents:WaitForChild("AssultRifleShoot")

local ShotVFX = ReplicatedStorage.Assets.VFX:WaitForChild("Shot")

local function applySpread(direction, spreadAngle)
	if spreadAngle <= 0 then return direction.Unit end
	local theta = math.random() * 2 * math.pi
	local phi = math.random() * spreadAngle

	local up = Vector3.new(0, 1, 0)
	if math.abs(direction:Dot(up)) > 0.999 then
		up = Vector3.new(1, 0, 0)
	end
	local right = direction:Cross(up).Unit
	local newUp = right:Cross(direction).Unit

	return (direction * math.cos(phi)
		+ right * math.sin(phi) * math.cos(theta)
		+ newUp * math.sin(phi) * math.sin(theta)).Unit
end

local function createServerBullet(origin, target, hitCallback)
	local bullet = Instance.new("Part")
	bullet.Shape = Enum.PartType.Ball
	bullet.Material = Enum.Material.SmoothPlastic
	bullet.Color = Color3.new(0, 0, 0)
	bullet.Size = Vector3.new(0.2, 0.2, 0.2)
	bullet.Anchored = true
	bullet.CanCollide = false
	bullet.CFrame = CFrame.new(origin)
	bullet.Parent = Workspace

	local dir = (target - origin).Unit
	local distance = (target - origin).Magnitude
	local speed = 1000
	local traveled = 0

	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		local move = speed * dt
		traveled += move
		local newPos = bullet.Position + dir * move

		local ray = Ray.new(bullet.Position, dir * move)
		local hitPart, hitPos, normal = Workspace:FindPartOnRay(ray)
		if hitPart then
			bullet.Position = hitPos
			pcall(function() hitCallback(hitPart, hitPos, normal) end)
			bullet:Destroy()
			conn:Disconnect()
			return
		end

		bullet.Position = newPos

		if traveled >= distance then
			bullet:Destroy()
			conn:Disconnect()
		end
	end)
end

local function createImpactEffect(hitPos, normal)
	local holePart = Instance.new("Part")
	holePart.Size = Vector3.new(0.5, 0.5, 0.05)
	holePart.Anchored = true
	holePart.CanCollide = false
	holePart.Transparency = 1
	holePart.CanQuery = false

	holePart.CFrame = CFrame.new(hitPos + normal * 0.002, hitPos + normal)
	holePart.Parent = workspace

	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.AlwaysOnTop = false
	surfaceGui.Face = Enum.NormalId.Front
	surfaceGui.LightInfluence = 1
	surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surfaceGui.PixelsPerStud = 50
	surfaceGui.Adornee = holePart
	surfaceGui.Parent = holePart
	surfaceGui.MaxDistance = 150

	local img1 = Instance.new("ImageLabel")
	img1.Size = UDim2.new(1, 0, 1, 0)
	img1.BackgroundTransparency = 1
	img1.Image = "rbxassetid://6904702445"
	img1.ZIndex = 1
	img1.Parent = surfaceGui

	local img2 = Instance.new("ImageLabel")
	img2.Size = UDim2.new(1, 0, 1, 0)
	img2.BackgroundTransparency = 1
	img2.Image = "rbxassetid://16694810795"
	img2.ImageTransparency = 0.15
	img2.ZIndex = 2
	img2.Parent = surfaceGui

	local randomRot = math.random(-25, 25)
	holePart.CFrame *= CFrame.Angles(0, 0, math.rad(randomRot))

	local fx = ReplicatedStorage.Assets.VFX:WaitForChild("Shot").Main:Clone()
	fx.Parent = holePart
	fx.WorldPosition = holePart.Position
	for _, v in ipairs(fx:GetChildren()) do
		if v:IsA("ParticleEmitter") then
			v:Emit(10)
		end
	end

	game:GetService("Debris"):AddItem(holePart, 10)
	game:GetService("Debris"):AddItem(fx, 3)
end

local function handleBulletFired(player, data)
	if not player or not player.Character then return end

	local tool = player.Character:FindFirstChildOfClass("Tool")
	if not tool then return end
	local handle = tool:FindFirstChild("Handle") or tool:FindFirstChildOfClass("BasePart")
	if not handle then return end
	local origin = handle.Position

	local bullets = data.BulletsPerShot or 1
	local spreadAngle = math.rad(data.SpreadAngle or 0)
	local maxDist = data.MaxTravelDistance or 100
	local damage = data.DamagePerBullet or 10

	for i = 1, bullets do
		local dir = (data.Direction).Unit
		dir = applySpread(dir, spreadAngle)

		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = {player.Character}
		params.IgnoreWater = true

		local result = workspace:Raycast(origin, dir * maxDist, params)
		local hitPart, hitPos, hitNormal

		if result then
			hitPart = result.Instance
			hitPos = result.Position
			hitNormal = result.Normal
		else
			hitPos = origin + dir * maxDist
		end

		createServerBullet(origin, hitPos)

		if hitPart and hitPart.Parent then
			local humanoid =
				hitPart.Parent:FindFirstChildOfClass("Humanoid") or
				(hitPart.Parent.Parent and hitPart.Parent.Parent:FindFirstChildOfClass("Humanoid"))

			if humanoid and humanoid ~= player.Character:FindFirstChildOfClass("Humanoid") then
				local multiplier = 1
				local name = hitPart.Name
				if name == "Head" then multiplier = 2
				elseif name == "Torso" or name == "UpperTorso" or name == "LowerTorso" then
					multiplier = 1.3
				end
				humanoid:TakeDamage(damage * multiplier)
			else
				if hitPart:IsDescendantOf(workspace) and hitPart.Parent == workspace then
					createImpactEffect(hitPos, hitNormal)
				end
			end
		end
	end
end

ShotGunEvent.OnServerEvent:Connect(handleBulletFired)
PistolEvent.OnServerEvent:Connect(handleBulletFired)
AssultRifleEvent.OnServerEvent:Connect(handleBulletFired)
