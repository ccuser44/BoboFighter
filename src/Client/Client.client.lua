local character = script.Parent
local humanoid = character:WaitForChild("Humanoid")
local primaryPart = character.PrimaryPart or character:WaitForChild("HumanoidRootPart")

-- Stop bouncing when jumping from a high altitude to prevent false positive:

humanoid.StateChanged:Connect(function(oldState, newState)
	if newState == Enum.HumanoidStateType.Landed and math.abs(primaryPart.AssemblyLinearVelocity.Y) > humanoid.JumpPower + humanoid.JumpPower / 2 then
		primaryPart.AssemblyLinearVelocity *= Vector3.new(1, 0, 1)
	end
end)