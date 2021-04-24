return {
    Detections = {
        Speed = true, -- Teleporting on the X and Z axis, High speeds on the X and Z axis
        VerticalSpeed = true, -- High Jumps, High Speed on the Y axis, Teleporting on the Y axis
        NoClip = true, -- Walking through can collide objects
        CollisionThroughCanCollideObjects = false, -- Player walking through can collideable objects, doesn't account for gravity / body mover!


		-- Non physics related detections:
        MultiToolEquip = true, -- Multiple tools equipped at the same time
        InvalidToolDrop = true, -- Dropping tools with CanBeDropped set to false 
        GodMode = true -- Deleting humanoid on the server and creating a new humanoid on the client
    },

    -- List of user id's that will be black listed (won't be detected)
    BlackListedPlayers = {
        --[[  
            125390463, -- SilentsReplacement
            263490634, -- Bobo Fin
        ]]

    },

    Leeways = {
        -- Lower leeways than these may result in false positives! You're encouraged to test them out though and see 
        -- which one is best suited for your game

        Speed = 4, -- Additional amount of speed a player can gain exceeding their walk speed
        VerticalSpeed = 4, -- Additional amount of vertical speed a player can gain exceeding the limit their jump power
		-- is capable of + accounting for gravity
        NoClipDepth = 3, -- Max depth a player can walk through an can collide on instance
    },

    CheckCooldown = 5, -- When a player is teleported back, this will be the delay until the anti exploit starts checking again
}
