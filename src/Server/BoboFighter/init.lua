-[[
    BoboFighter Version 1.6 - Beta
]]

local BoboFighter = setmetatable({
	GlobalExploitData = {},

}, {__tostring = function()
	return "[BoboFighter]: "
end})

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local GroupService = game:GetService("GroupService")

assert(script:FindFirstChild("Settings"), "Settings module not found")
assert(script:FindFirstChild("Constants"), "Constants module not found")

local Settings = require(script.Settings)
local Constants = require(script.Constants)       

local ExploitData = {}
local CachedRegions = {}

local detections = Settings.Detections
local leeways = Settings.Leeways   

local function On_Ground(primaryPart, params)   
	local middleRay = Workspace:Raycast(primaryPart.Position, Vector3.new(0, (-primaryPart.Size.Y / 2) * 4 + .5, 0), params)

	return middleRay or Workspace:Raycast(primaryPart.Position +
		Vector3.new(primaryPart.Size.X / 2, 0, 0), 
		Vector3.new(0, (-primaryPart.Size.Y / 2) * 4 + .5, 0), params)
end

local function In_Water(primaryPart)
	local offset = Vector3.new(1, 5, 1)

	local voxels = Workspace.Terrain:ReadVoxels(
		Region3.new(primaryPart.Position - offset, primaryPart.Position + offset):ExpandToGrid(4),
		4
	)

	return voxels[1][1][1] == Enum.Material.Water
end 

local function Punish(primaryPart, cframe)
	primaryPart:SetNetworkOwner()
	primaryPart.CFrame = cframe
end

-- TODO: A more efficient and less expensive way
local function In_Object(primaryPart)
	local region = CachedRegions[primaryPart.Parent.Name] or Region3.new(primaryPart.Position, primaryPart.Position)
	local part = Workspace:FindPartsInRegion3WithIgnoreList(region, {primaryPart.Parent})[1]

	return part and part.CanCollide and (primaryPart.Position - part.Position).Magnitude 
end

local function Child_Destroyed(child)
	if child.Parent then
		return false
	end

	local _, result = pcall(function() 
		child.Parent = child
	end)

	return result:match("locked")
end

local function HeartbeatUpdate()
	BoboFighter.HeartbeatUpdate = RunService.Heartbeat:Connect(function()
		for _, player in ipairs(Players:GetPlayers()) do
			-- Is player black listed?
			if Settings.BlackListedPlayers[player.UserId] then
				continue
			end

			local exploitData = BoboFighter.GetExploitData(player.Name)

			-- No exploit data?
			if not exploitData then
				return
			end

			local character = player.Character 
			local primaryPart = character.PrimaryPart
			local humanoid = character:FindFirstChildWhichIsA("Humanoid")

			-- No root part or humanoid?
			if not primaryPart or not humanoid then
				continue
			end

			local physicsData = exploitData.PhysicsData

			-- Physics Detections paused or player is seated? 
			if physicsData.PhysicsDetectionsPaused or humanoid.SeatPart then
				-- Update last cframe:
				physicsData.LastCFrame = primaryPart.CFrame
				continue
			end

			local lastCheckDelta = os.clock() - (exploitData.LastCheckCycle or os.clock())
			local canSetNetworkOwner, _ = primaryPart:CanSetNetworkOwnership(), nil

			if not canSetNetworkOwner or humanoid.Health <= 0 then
				physicsData.Died = true
				continue
			end

			-- Server has network ownership?
			if not primaryPart:GetNetworkOwner() and exploitData.TimeSincePunished > 0 then
				-- Has cooldown passed?
				if os.clock() - exploitData.TimeSincePunished >= Settings.CheckCooldown then
					primaryPart:SetNetworkOwner(player)
					physicsData.LastCFrame = primaryPart.CFrame
					exploitData.TimeSincePunished = 0
				else
					continue
				end
			end

			-- Player previously died?
			if physicsData.Died then
				physicsData.Died = false
				-- Update last cframe:
				physicsData.LastCFrame = primaryPart.CFrame
			end

			if detections.NoClip and lastCheckDelta >= Constants.PASSIVE_CHECK_INTERVAL then
				-- Make sure the player wasn't teleported by the server and last cframe exists:
				if (not physicsData.ServerChangedPosition) and physicsData.LastCFrame then
					local ray = Workspace:Raycast(physicsData.LastCFrame.Position, primaryPart.Position - physicsData.LastCFrame.Position, physicsData.RayCastParams)

					-- Player walked through a can collide instance?
					if ray and ray.Instance.CanCollide then
						-- Calculate depth: 
						local depth = math.floor((primaryPart.Position - physicsData.LastCFrame.Position).Magnitude)

						-- Depth greater than leeway?
						if depth >= leeways.NoClipDepth then
							Punish(primaryPart, physicsData.LastCFrame)
							exploitData.TimeSincePunished = os.clock()
							table.insert(exploitData.Detections, ("No Clip | Captured depth: %s"):format(depth))
						end 

					elseif not ray then
						-- Rare case: Player walked through a object very fast
						local depth = In_Object(primaryPart)

						-- Depth greater than leeway?
						if depth and depth >= leeways.NoClipDepth then
							Punish(primaryPart, primaryPart.CFrame * CFrame.new(0, 0, 3))
							exploitData.TimeSincePunished = os.clock()
							exploitData.Flags += 1
							table.insert(exploitData.Detections, ("No Clip | Captured depth: %s"):format(depth))
						end
					end
				end
			end

			if detections.Speed and lastCheckDelta >= Constants.PASSIVE_CHECK_INTERVAL then  
				-- Make sure the player wasn't teleported by the server and last cframe exists:  
				if (not physicsData.ServerChangedPosition) and physicsData.LastCFrame then
					-- Max speed needs to be a significant amount than their walk speed to prevent false positives because of
					-- latency and other internal physics handling:

					local humanoidWalkSpeed = math.floor(humanoid.WalkSpeed)

					-- Only update values when necessary since computation almost every frame can become quite expensive:
					if humanoidWalkSpeed ~= physicsData.WalkSpeed then
						physicsData.WalkSpeed = humanoidWalkSpeed
						physicsData.MaxWalkSpeed = humanoidWalkSpeed + humanoidWalkSpeed / 2 + leeways.Speed
					end

					local averageSpeed = math.floor((primaryPart.Position * Vector3.new(1, 0, 1) - physicsData.LastCFrame.Position * Vector3.new(1, 0, 1)).Magnitude / lastCheckDelta)

					-- Accumulated average speed greater than max jump speed?
					if averageSpeed > physicsData.MaxWalkSpeed then
						Punish(primaryPart, physicsData.LastCFrame)
						exploitData.TimeSincePunished = os.clock()
						exploitData.Flags += 1
						table.insert(exploitData.Detections, ("Speeding | Captured average speed: %s"):format(averageSpeed))
					end
				end
			end

			if detections.VerticalSpeed and lastCheckDelta >= Constants.PASSIVE_CHECK_INTERVAL then  
				-- Make sure player isn't falling from the ground and last cframe exists:  
				if primaryPart.Position.Y >= ((physicsData.LastPositionOnGround and physicsData.LastPositionOnGround.Y) or math.huge) and physicsData.LastCFrame then
					-- Make sure the server didn't change the players position:
					if not physicsData.ServerChangedPosition then 
						-- Calculate max and accumulated jump power:

						local humanoidJumpPower = math.floor(humanoid.JumpPower)

						-- Only update values when necessary since computation almost every frame can become quite expensive:
						if humanoidJumpPower ~= physicsData.JumpPower then
							physicsData.JumpPower = humanoidJumpPower
							physicsData.MaxJumpPower = humanoidJumpPower + humanoidJumpPower / 2 + leeways.VerticalSpeed
						end

						local accumulatedJumpPower = math.floor(((primaryPart.Position - physicsData.LastCFrame.Position) * Vector3.new(0, 1, 0)).Magnitude / lastCheckDelta)	

						-- Accumulated jump power greater than max jump power?
						if accumulatedJumpPower > physicsData.MaxJumpPower then
							Punish(primaryPart, physicsData.LastCFrame)
							exploitData.TimeSincePunished = os.clock()
							exploitData.Flags += 1
							table.insert(exploitData.Detections, ("Vertical Speeding | Captured jump power: %s"):format(accumulatedJumpPower))
						end
					end
				end
			end

			-- Has enough time has passed to update physics data?
			if lastCheckDelta >= Constants.PASSIVE_CHECK_INTERVAL then
				-- Update last position if on ground or in water:
				local onGround = On_Ground(primaryPart, physicsData.RayCastParams)
				local inWater = In_Water(primaryPart)

				if onGround or inWater then
					-- Update last position on ground:
					physicsData.LastPositionOnGround = primaryPart.Position
					physicsData.ServerChangedPosition = primaryPart.Anchored 
				end 

				physicsData.LastCFrame = primaryPart.CFrame
				exploitData.LastCheckCycle = os.clock()
			end
		end
	end)
end

function BoboFighter.Connect()
	if detections.VerticalSpeed or detections.NoClip or detections.Speed then
		-- Start heartbeat update:
		HeartbeatUpdate()
	end

	local function CharacterAdded(player, character)
		local exploitData = BoboFighter.GetExploitData(player.Name) 

		-- Create raycast params:
		local rayCastParams = RaycastParams.new()
		rayCastParams.FilterDescendantsInstances = {character}
		rayCastParams.IgnoreWater = true

		local primaryPart = character.PrimaryPart or character:WaitForChild("HumanoidRootPart", 15)
		local humanoid = character:FindFirstChildWhichIsA("Humanoid") or character:WaitForChild("Humanoid", 15)

		-- Create exploit data if not created:
		if not exploitData then
			BoboFighter.GlobalExploitData[player.Name] = setmetatable({
				PhysicsData = {
					LastCFrame = nil,
					LastPositionOnGround = nil,
					Died = false,
					ServerChangedPosition = false,
					RayCastParams = rayCastParams,
					DetectionsPaused = false,
					JumpPower = nil,
					MaxJumpPower = nil,
					WalkSpeed = nil,
					MaxJumpSpeed = nil,
				},

				Detections = {},
				Flags = 0,
				LastCheckCycle = os.clock(),
				LastCheckTime = 0,
				TimeSincePunished = 0,
				HeartbeatConnection = nil

			}, {__index = ExploitData})
		end 

		exploitData = BoboFighter.GlobalExploitData[player.Name]

		local physicsData = exploitData.PhysicsData

		-- Create a new thread to yield:
		if not primaryPart then
			coroutine.wrap(function()
				-- Wait for the primary part:
				while not primaryPart do
					primaryPart = character:GetPropertyChangedSignal("PrimaryPart"):Wait() 
				end
			end)()
		end

		-- Only listen to scripted positional changes if physics detections are turned on in the first place:
		if detections.Fly or detections.Speed or detections.NoClip then  
			primaryPart:GetPropertyChangedSignal("CFrame"):Connect(function()
				physicsData.ServerChangedPosition = true
			end)

			primaryPart:GetPropertyChangedSignal("Position"):Connect(function()
				physicsData.ServerChangedPosition = true
			end)
		end

		if detections.InvalidToolDrop or detections.GodMode or detections.PreventHatDrop then
			character.ChildRemoved:Connect(function(child)
				if child:IsA("Accoutrement") and detections.InvalidHatDrop and child.Parent == Workspace then
					-- Make sure the accoutrement wasn't destroyed from the server:
					if not Child_Destroyed(child) then
						RunService.Heartbeat:Wait()
						child.Parent = character
					end
				end

				if detections.GodMode and child:IsA("Humanoid") then
					-- Make sure the humanoid wasn't destroyed from the server:
					if not Child_Destroyed(child) then
						RunService.Heartbeat:Wait()
						child.Parent = character
					end
				end

				-- Make sure the child is a tool and isn't a part of the player's backpack:
				if (not child:IsA("BackpackItem")) or child.Parent == player.Backpack then
					return
				end

				if detections.InvalidToolDrop then
					-- Can the tool be dropped?
					if child.CanBeDropped then
						return
					end

					-- Make sure the tool wasn't destroyed from the server:
					if not Child_Destroyed(child) then
						RunService.Heartbeat:Wait()
						child.Parent = character
					end
				end
			end)
		end 

		if detections.MultiToolEquip then
			character.ChildAdded:Connect(function(child)
				if not child:IsA("BackpackItem") then
					return
				end

				-- Count number of tools:
				local toolCount = 0

				for _, child in ipairs(character:GetChildren()) do
					if child:IsA("BackpackItem") then
						toolCount += 1

						-- Player has equiped more than 1 tool?
						if toolCount > 1 then
							RunService.Heartbeat:Wait()
							child.Parent = player:FindFirstChildOfClass("Backpack") or Instance.new("Backpack", player)
						end
					end 
				end
			end)
		end

		-- Update ray cast params and physics data:
		physicsData.RayCastParams = rayCastParams

		local humanoidWalkSpeed = math.floor(humanoid.WalkSpeed)
		local humanoidJumpPower = math.floor(humanoid.JumpPower)

		if physicsData.JumpPower ~= humanoidJumpPower then
			physicsData.MaxJumpPower = humanoid.JumpPower + humanoid.JumpPower / 2 + leeways.VerticalSpeed
			physicsData.JumpPower = humanoidJumpPower
		end

		if physicsData.WalkSpeed ~= humanoidWalkSpeed then
			physicsData.MaxWalkSpeed = humanoid.JumpPower + humanoid.JumpPower / 2 + leeways.VerticalSpeed
			physicsData.WalkSpeed = humanoidWalkSpeed
		end
	end

	local GotGroupOwnerId = 0
	coroutine.wrap(xpcall)(function()
		if game.CreatorType == Enum.CreatorType.Group then
			GroupedId = GroupService:GetGroupInfoAsync(game.CreatorId).Owner.Id
		end
	end, warn)

	local function PlayerAdded(player)
		if 
			Settings.IgnoreOwners == true and (game.CreatorId == player.UserId and game.CreatorType == Enum.CreatorType.User or game.CreatorType == Enum.CreatorType.Group and GotGroupOwnerId == player.UserId)
			or Settings.IgnoreAdmins and (
			_G.Adonis and _G.Adonis.CheckAdmin and _G.Adonis.CheckAdmin(player)
			or _G.HDAdminMain and _G.HDAdminMain:GetModule("API") and _G.HDAdminMain:GetModule("API"):GetRank(player) > (_G.HDAdminMain:GetModule("API"):GetRankId("nonadmins") or 0)
			or _G.CommanderAPI and _G.CommanderAPI.checkAdmin and _G.CommanderAPI.checkAdmin:Invoke(player))
		then
			return	
		end


		-- Reliable way of firing CharacterAdded event properly:
		CharacterAdded(player, player.Character or player.CharacterAdded:Wait())

		player.CharacterAdded:Connect(function(character)
			CharacterAdded(player, character)
		end)
	end

	local function PlayerRemoved(player)
		local exploitData = BoboFighter.GetExploitData(player.Name)

		if not exploitData then
			return
		end

		CachedRegions[player.Name] = nil
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
	self.PhysicsData.PhysicsDetectionsPaused = true
end

function ExploitData:Start()
	self.PhysicsData.PhysicsDetectionsPaused = false
end

function BoboFighter.GetExploitData(user)
	return BoboFighter.GlobalExploitData[user]
end

function BoboFighter.Disconnect()
	if not BoboFighter.HeartbeatConnection then
		return warn(("%s No current connections"):format(tostring(BoboFighter)))
	end

	BoboFighter.HeartbeatConnection:Disconnect()
end

return BoboFighter
