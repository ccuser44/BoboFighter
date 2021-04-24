--[[

    BoboFighter Version 1.4 - Beta

    Hacky support for high speed server sided body movers to prevent false positives:

    Make sure to pause the anti exploit for the player by simply getting 
    their exploit data via BoboFighter.GetExploitData(playerName) and 
    calling Pause
]]

local BoboFighter = {
	GlobalExploitData = {},
}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

assert(script:FindFirstChild("Settings"), "Settings module not found")
assert(script:FindFirstChild("Constants"), "Constants module not found")

local Settings = require(script.Settings)
local Constants = require(script.Constants)       

local ExploitData = {}
local detections = Settings.Detections
local leeways = Settings.Leeways   

local function On_Ground(primaryPart, params)
	local topLeft = Workspace:Raycast(primaryPart.Position + Vector3.new(primaryPart.Size.X / 2, primaryPart.Size.Y / 2, -primaryPart.Size.Z / 2), Vector3.new(0, -(primaryPart.Size.Y / 2 * 4 + .1), 0), params)
	local bottomLeft = Workspace:Raycast(primaryPart.Position + Vector3.new(-primaryPart.Size.X / 2, primaryPart.Size.Y / 2 , -primaryPart.Size.Z / 2), Vector3.new(0, -(primaryPart.Size.Y / 2 * 4 + .1), 0), params)
	local topRight = Workspace:Raycast(primaryPart.Position + Vector3.new(primaryPart.Size.X / 2, primaryPart.Size.Y / 2 , primaryPart.Size.Z / 2), Vector3.new(0, -(primaryPart.Size.Y / 2 * 4 + .1), 0), params)
	local bottomRight = Workspace:Raycast(primaryPart.Position + Vector3.new(-primaryPart.Size.X / 2, primaryPart.Size.Y / 2 , primaryPart.Size.Z / 2), Vector3.new(0, -(primaryPart.Size.Y / 2 * 4 + .1 ), 0), params)

	local instances = {
		topLeft and topLeft.Instance or nil,
		bottomLeft and bottomLeft.Instance or nil,
		topRight and topRight.Instance or nil, 
		bottomLeft and bottomLeft.Instance or nil,
		bottomRight and bottomRight.Instance or nil
	}

	local onGround = #instances > 0
	local walkAble = {}

	for _, instance in ipairs(instances) do
		if not instance.CanCollide then
			table.insert(walkAble, false)
		end
	end

	-- Are all 4 rays hitting an can collide false object?
	walkAble = not (#walkAble == #instances)

	return onGround, walkAble 
end

local function In_Water(primaryPart)
	local offset = Vector3.new(1, 5, 1)

	local voxels = Workspace.Terrain:ReadVoxels(
		Region3.new(primaryPart.Position - offset, primaryPart.Position + offset):ExpandToGrid(4),
		4
	)

	return voxels[1][1][1] == Enum.Material.Water
end 

local function Punish(primaryPart, cf)
	primaryPart:SetNetworkOwner()
	primaryPart.CFrame = cf
end

-- TODO: A more efficient and less expensive way
local function In_Object(primaryPart)
	local region = Region3.new(primaryPart.Position, primaryPart.Position)
	local partsInRegion = Workspace:FindPartsInRegion3WithIgnoreList(region, {primaryPart.Parent})

	local depth = (partsInRegion[1] and partsInRegion[1].CanCollide) and (primaryPart.Position - partsInRegion[1].Position).Magnitude
	return depth
end

local function Child_Destroyed(child)
	if child.Parent then
		return false
	end

	local _, result = pcall(function() 
		child.Parent = child
	end)

	return result:match("locked") ~= nil
end

function ExploitData:_HeartBeatUpdate(dt)
	local physicsData = self.PhysicsData
	local lastCheckCycleDt = time() - (self.LastCheckCycle or time())
	
	local primaryPart = self.Character.PrimaryPart or self.Character:WaitForChild("HumanoidRootPart", 15)
	local humanoid = self.Character:FindFirstChildWhichIsA("Humanoid") or self.Character:WaitForChild("Humanoid", 15)
	local canSetNetworkOwner, _ = primaryPart and primaryPart:CanSetNetworkOwnership(), nil

	-- No physics detections? 
	if not (detections.Fly or detections.NoClip or detections.Speed) then
		self.HeartbeatConnection:Disconnect()
		return
	end

	-- Detections paused?
	if self.Paused then
		physicsData.LastCFrame = primaryPart.CFrame
		physicsData.LastPositionOnGround = primaryPart.Position
		return
	end
	
	-- Don't do physics detections if the humanoid is seated:
	if humanoid.SeatPart then
		-- Only update physics data:
		physicsData.LastCFrame = primaryPart.CFrame
		physicsData.LastPositionOnGround = primaryPart.Position
		return
	end
	
	-- Server has network ownership of the primary part? If so, wait until the cooldown has passed:
	if canSetNetworkOwner and primaryPart:GetNetworkOwner() ~= self.Player and self.TimeSincePunished > 0 then
		if time() - self.TimeSincePunished >= Settings.CheckCooldown then
			primaryPart:SetNetworkOwner(self.Player)
			physicsData.LastCFrame = primaryPart.CFrame
			self.TimeSincePunished = 0
		else
			return
		end
		
	-- If network owner ship can't be accessed for the primary part or the player died or 
	-- primary part not found
	elseif not canSetNetworkOwner or humanoid.Health <= 0 or not primaryPart then
		return
	end

	-- Make it harder for exploiters to rubber band their humanoid property values
	-- Make sure that the server didn't change any humanoid property values to prevent bugs:
	if not self.ServerChangedHumanoidProperty then
		humanoid.WalkSpeed += Constants.SMALL_DECIMAL
		humanoid.WalkSpeed -= Constants.SMALL_DECIMAL
		humanoid.JumpHeight += Constants.SMALL_DECIMAL
		humanoid.JumpHeight -= Constants.SMALL_DECIMAL
		humanoid.JumpPower += Constants.SMALL_DECIMAL
		humanoid.JumpPower -= Constants.SMALL_DECIMAL
		humanoid.Health += Constants.SMALL_DECIMAL
		humanoid.Health -= Constants.SMALL_DECIMAL
		humanoid.MaxHealth += Constants.SMALL_DECIMAL
		humanoid.MaxHealth -= Constants.SMALL_DECIMAL
		humanoid.HipHeight += Constants.SMALL_DECIMAL
		humanoid.HipHeight -= Constants.SMALL_DECIMAL
		humanoid.MaxSlopeAngle += Constants.SMALL_DECIMAL
		humanoid.MaxSlopeAngle -= Constants.SMALL_DECIMAL
	end

	self.ServerChangedHumanoidProperty = false

	if detections.NoClip and lastCheckCycleDt >= Constants.PASSIVE_CHECK_INTERVAL then
		if (not self.ServerChangedPosition) and physicsData.LastCFrame then
			local ray = Workspace:Raycast(physicsData.LastCFrame.Position, primaryPart.Position - physicsData.LastCFrame.Position, self.RayCastParams)

			-- Player walked through a can collide instance?
			if ray and ray.Instance.CanCollide then
				-- Calculate depth: 
				local depth = math.floor((primaryPart.Position - physicsData.LastCFrame.Position).Magnitude)
				
				-- Depth greater than leeway?
				if depth >= leeways.NoClipDepth then
					Punish(primaryPart, physicsData.LastCFrame)
					self.TimeSincePunished = time()
					table.insert(self.Detections, ("No Clip | Captured depth: %s"):format(depth))
				end 

			elseif not ray then
				-- Rare case: Player walked through a object fast
				local depth = In_Object(primaryPart)
				
				-- Depth greater than leeway?
				if depth and depth >= leeways.NoClipDepth then
					Punish(primaryPart, primaryPart.CFrame * CFrame.new(0, 0, 3))
					self.TimeSincePunished = time()
					table.insert(self.Detections, ("No Clip | Captured depth: %s"):format(depth))
				end
			end
		end
	end

	if detections.Speed and lastCheckCycleDt >= Constants.PASSIVE_CHECK_INTERVAL then    
		if (not self.ServerChangedPosition) and physicsData.LastCFrame then
			-- Make sure player wasn't hit by a fast moving object:
			if humanoid:GetState() ~= Enum.HumanoidStateType.Ragdoll then 
				-- Max speed needs to be a significant amount than their walk speed to prevent false positives because of
				-- latency and other internal physics handling:
				local maxSpeed = humanoid.WalkSpeed + (humanoid.WalkSpeed / 2) + leeways.Speed
				local averageSpeed = math.floor((primaryPart.Position * Vector3.new(1, 0, 1) - physicsData.LastCFrame.Position * Vector3.new(1, 0, 1)).Magnitude / lastCheckCycleDt)

				-- Accumulated average speed greater than max jump speed?
				if averageSpeed > maxSpeed then
					Punish(primaryPart, physicsData.LastCFrame)
					self.TimeSincePunished = time()
					table.insert(self.Detections, ("Speeding | Captured average speed: %s"):format(averageSpeed))
				end
			end
		end
	end

	if detections.VerticalSpeed and lastCheckCycleDt >= Constants.PASSIVE_CHECK_INTERVAL then  
		-- Make sure player isn't falling from the ground:  
		if primaryPart.Position.Y >= ((physicsData.LastPositionOnGround and physicsData.LastPositionOnGround.Y) or math.huge) and physicsData.LastCFrame then
			-- Make sure player wasn't hit by a fast moving object:
			if humanoid:GetState() ~= Enum.HumanoidStateType.Ragdoll then 
				-- Calculate max and accumulated jump power:
				local maxJumpPower = humanoid.JumpPower + (humanoid.JumpPower / 2) + leeways.VerticalSpeed
				local accumulatedJumpPower = math.floor(((primaryPart.Position - physicsData.LastCFrame.Position) * Vector3.new(0, 1, 0)).Magnitude / lastCheckCycleDt)	

				-- Accumulated jump power greater than max jump power?
				if accumulatedJumpPower > maxJumpPower then
					Punish(primaryPart, physicsData.LastCFrame)
					self.TimeSincePunished = time()
					table.insert(self.Detections, ("Vertical Speeding | Captured jump power: %s"):format(accumulatedJumpPower))
				end
			end
		end
	end

	-- Update last position if on ground or in water:
	local onGround, walkAble = On_Ground(primaryPart, self.RayCastParams)
	local inWater = In_Water(primaryPart)

	if onGround or inWater then
		-- TODO: Add Body mover and gravity support:
		-- Player is somehow moving through a can collide false object:
		if (detections.CollisionThroughCanCollideObjects and not walkAble) and onGround then
			primaryPart:SetNetworkOwner()
			self.TimeSincePunished = time()
		end
		
		-- Update last position on ground:
		physicsData.LastPositionOnGround = primaryPart.Position
		self.ServerChangedPosition = primaryPart.Anchored 
	end 
	
	-- Enough time has passed to update last position?
	if lastCheckCycleDt >= Constants.PASSIVE_CHECK_INTERVAL then
		physicsData.LastCFrame = primaryPart.CFrame
		self.LastCheckCycle = time()
	end
end

function BoboFighter.Connect()
	local function CharacterAdded(player, character)
		local exploitDataFound = BoboFighter.GlobalExploitData[player.Name] ~= nil

		-- Create raycast params:
		local rayCastParams = RaycastParams.new()
		rayCastParams.FilterDescendantsInstances = {character}
		rayCastParams.IgnoreWater = true

		-- Create exploit data if not created:
		if not exploitDataFound then
			BoboFighter.GlobalExploitData[player.Name] = setmetatable({
				PhysicsData = {
					LastCFrame = nil,
					LastPositionOnGround = nil,
				},
				
				Player = player,
				Character = character,
				Detections = {},
				LastCheckCycle = time(),
				ServerChangedPosition = false,
				LastSpeedCheck = 0,
				RayCastParams = rayCastParams,
				TimeSincePunished = 0,
				HeartbeatConnection = nil

			}, {__index = ExploitData})
		end 

		local exploitData = BoboFighter.GlobalExploitData[player.Name]
		local primaryPart = character.PrimaryPart or character:WaitForChild("HumanoidRootPart", 15)
		local humanoid = character:FindFirstChildWhichIsA("Humanoid") or character:WaitForChild("Humanoid", 15)

		-- Update character and ray cast params:
		exploitData.Character = character
		exploitData.RayCastParams = rayCastParams

		-- Only listen to scripted positional changes if physics detections are turned on in the first place:
		if detections.Fly or detections.Speed or detections.NoClip then 
			primaryPart:GetPropertyChangedSignal("CFrame"):Connect(function()
				exploitData.ServerChangedPosition = true
			end)

			primaryPart:GetPropertyChangedSignal("Position"):Connect(function()
				exploitData.ServerChangedPosition = true
			end)

			humanoid.Changed:Connect(function()
				exploitData.ServerChangedHumanoidProperty = true
			end)
		end

		-- Make sure heartbeat connection doesn't exist already:
		if not exploitData.HeartbeatConnection then
			exploitData.HeartbeatConnection = RunService.Heartbeat:Connect(function(dt)
				exploitData:_HeartBeatUpdate(dt)
			end)
		end

		if detections.InvalidToolDrop or detections.GodMode then
			character.ChildRemoved:Connect(function(child)
				if exploitData.Paused then
					return
				end

				if detections.GodMode and child:IsA("Humanoid") then
					if not Child_Destroyed(child)  then
						RunService.Heartbeat:Wait()
						child.Parent = character
					end
				end

				if detections.InvalidToolDrop and child:IsA("Tool") then
					if child.CanBeDropped then
						return
					end

					if child:IsA("Tool") and not Child_Destroyed(child) then
						RunService.Heartbeat:Wait()
						child.Parent = character
					end
				end
			end)
		end 

		if detections.MultiToolEquip then
			character.ChildAdded:Connect(function(child)
				if exploitData.Paused then
					return
				end

				if child:IsA("Tool") then
					-- Count number of tools:
					local toolCount = 0

					for _, child in ipairs(character:GetChildren()) do
						if child:IsA("Tool") then
							toolCount += 1

							-- Player has equiped more than 1 tool?
							if toolCount > 1 then
								RunService.Heartbeat:Wait()
								child.Parent = player.Backpack
							end
						end 
					end
				end
			end)
		end
	end

	local function PlayerAdded(player)
		-- Reliable way of firing CharacterAdded event properly:
		CharacterAdded(player, player.Character or player.CharacterAdded:Wait())

		player.CharacterAdded:Connect(function(character)
			CharacterAdded(player, character)
		end)
	end

	local function PlayerRemoved(player)
		local exploitData = BoboFighter.GetExploitData(player.Name)
		-- No exploit data?
		if not exploitData then
			return
		end

		exploitData.HeartbeatConnection:Disconnect()
		BoboFighter.GlobalExploitData[player.Name] = nil
	end

	Players.PlayerAdded:Connect(PlayerAdded)
	Players.PlayerRemoving:Connect(PlayerRemoved)

	-- Capture current players:
	for _, player in ipairs(Players:GetPlayers()) do
		coroutine.wrap(PlayerAdded)(player)
	end
end

function ExploitData:Pause()
	self.Paused = true
end

function ExploitData:Start()
	self.Paused = false
end

function BoboFighter.GetExploitData(user)
	return BoboFighter.GlobalExploitData[user]
end

function BoboFighter:Disconnect()
	for user, _ in pairs(BoboFighter.GlobalExploitData) do
		BoboFighter.GlobalExploitData[user].HeartbeatConnection:Disconnect()
		BoboFighter.GlobalExploitData[user] = nil
	end
end

return BoboFighter
