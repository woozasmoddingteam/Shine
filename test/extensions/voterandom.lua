--[[
	Shuffling logic tests.
]]

local UnitTest = Shine.UnitTest

local VoteShuffle = Shine.Plugins.voterandom
if not VoteShuffle then
	Shine:LoadExtension( "voterandom" )
	VoteShuffle = Shine.Plugins.voterandom
end

if not VoteShuffle then return end

UnitTest:Test( "AssignPlayers", function( Assert )
	local TeamMembers = {
		{
			1, 2, 3
		},
		{
			4, 5, 6
		}
	}

	local TeamSkills = {
		{
			Average = 1000,
			Total = 3000,
			Count = 3
		},
		{
			Average = 750,
			Total = 2250,
			Count = 3
		}
	}

	local SortTable = {
		{
			Player = {},
			Skill = 1500
		},
		{
			Player = {},
			Skill = 1000
		}
	}

	local Count, NumTargets = 2, 2

	VoteShuffle:AssignPlayers( TeamMembers, SortTable, Count, NumTargets, TeamSkills )

	-- Should place 1500 player on lower skill team.
	Assert:Equals( 3750, TeamSkills[ 2 ].Total )
	Assert:Equals( 4, TeamSkills[ 2 ].Count )
	Assert:Equals( 3750 / 4, TeamSkills[ 2 ].Average )

	Assert:Equals( 4000, TeamSkills[ 1 ].Total )
	Assert:Equals( 4, TeamSkills[ 1 ].Count )
	Assert:Equals( 4000 / 4, TeamSkills[ 1 ].Average )
end, nil, 100 )

UnitTest:Test( "PerformSwap", function( Assert )
	local TeamMembers = {
		{
			1, 2, 3
		},
		{
			4, 5, 6
		}
	}

	local TeamSkills = {
		{
			Average = 1000,
			Total = 3000,
			Count = 3
		},
		{
			Average = 750,
			Total = 2250,
			Count = 3
		}
	}

	local SwapData = {
		BestPlayers = {
			5, 1
		},
		Indices = {
			1, 2
		},
		Totals = {
			2750, 2500
		},
		BestDiff = 0
	}

	VoteShuffle:PerformSwap( TeamMembers, TeamSkills, SwapData )

	Assert:ArrayEquals( { 5, 2, 3 }, TeamMembers[ 1 ] )
	Assert:ArrayEquals( { 4, 1, 6 }, TeamMembers[ 2 ] )

	Assert:Equals( 2750, TeamSkills[ 1 ].Total )
	Assert:Equals( 2500, TeamSkills[ 2 ].Total )
end )

UnitTest:Test( "PerformSwap with uneven teams", function( Assert )
	local TeamMembers = {
		{
			1, 2, 3
		},
		{
			4, 5
		}
	}

	local TeamSkills = {
		{
			Average = 1000,
			Total = 3000,
			Count = 3
		},
		{
			Average = 750,
			Total = 1500,
			Count = 2
		}
	}

	local SwapData = {
		BestPlayers = {
			nil, 1
		},
		Indices = {
			1, 3
		},
		Totals = {
			2000, 2500
		},
		BestDiff = 0
	}

	local Changed, LargerTeam, LesserTeam = VoteShuffle:PerformSwap( TeamMembers, TeamSkills, SwapData, 1, 2 )

	Assert:Truthy( Changed )
	Assert:Equals( 2, LargerTeam )
	Assert:Equals( 1, LesserTeam )

	Assert:ArrayEquals( { 2, 3 }, TeamMembers[ 1 ] )
	Assert:ArrayEquals( { 4, 5, 1 }, TeamMembers[ 2 ] )

	Assert:Equals( 2000, TeamSkills[ 1 ].Total )
	Assert:Equals( 2, TeamSkills[ 1 ].Count )

	Assert:Equals( 2500, TeamSkills[ 2 ].Total )
	Assert:Equals( 3, TeamSkills[ 2 ].Count )
end )

UnitTest:Test( "OptimiseTeams", function( Assert )
	local Skills = {
		2000, 2000, 1000,
		1000, 1000, 1000
	}

	local function RankFunc( Player )
		return Skills[ Player ]
	end

	local TeamMembers = {
		{
			1, 2, 3
		},
		{
			4, 5, 6
		}
	}

	local TeamSkills = {
		{
			Average = 5000 / 3,
			Total = 5000,
			Count = 3
		},
		{
			Average = 1000,
			Total = 3000,
			Count = 3
		}
	}

	VoteShuffle.Config.IgnoreCommanders = false
	VoteShuffle.Config.UseStandardDeviation = true

	VoteShuffle:OptimiseTeams( TeamMembers, RankFunc, TeamSkills )

	-- Final team layout should be:
	-- 2000, 1000, 1000
	-- 2000, 1000, 1000
	Assert:Equals( 4000, TeamSkills[ 1 ].Total )
	Assert:Equals( 4000, TeamSkills[ 2 ].Total )
end, nil, 100 )

UnitTest:Test( "OptimiseTeams with uneven teams", function( Assert )
	local Skills = {
		2000, 2000, 1000,
		1000, 1000
	}

	local function RankFunc( Player )
		return Skills[ Player ]
	end

	local TeamMembers = {
		{
			1, 2, 3
		},
		{
			4, 5
		}
	}

	local TeamSkills = {
		{
			Average = 5000 / 3,
			Total = 5000,
			Count = 3
		},
		{
			Average = 1000,
			Total = 2000,
			Count = 2
		}
	}

	VoteShuffle.Config.IgnoreCommanders = false
	VoteShuffle.Config.UseStandardDeviation = true

	VoteShuffle:OptimiseTeams( TeamMembers, RankFunc, TeamSkills )

	-- Final team layout should be:
	-- 2000, 1000, 1000
	-- 2000, 1000
	Assert:Equals( 4000, TeamSkills[ 1 ].Total )
	Assert:Equals( 3, TeamSkills[ 1 ].Count )
	Assert:Equals( 3000, TeamSkills[ 2 ].Total )
	Assert:Equals( 2, TeamSkills[ 2 ].Count )
end, nil, 100 )