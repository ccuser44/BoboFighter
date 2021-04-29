local character = script.Parent
local humanoid = character:FindFirstChildWhichIsA("Humanoid") or character:WaitForChild("Humanoid", 15)
local primaryPart = character.PrimaryPart or character:WaitForChild("HumanoidRootPart")

humanoid.StateChanged:Connect(function(oldState, newState)
	if newState == Enum.HumanoidStateType.Landed and math.abs(primaryPart.AssemblyLinearVelocity.Y) > humanoid.JumpPower + humanoid.JumpPower / 2 then
		primaryPart.AssemblyLinearVelocity *= Vector3.new(1, 0, 1)
	end

	-- Rag doll check:
	if newState == Enum.HumanoidStateType.Ragdoll then
		primaryPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
	end
end)
