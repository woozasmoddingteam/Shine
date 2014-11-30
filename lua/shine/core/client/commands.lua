--[[
	Client side commands handling.
]]

local Notify = Shared.Message
local setmetatable = setmetatable
local StringFormat = string.format
local Traceback = debug.traceback
local type = type
local xpcall = xpcall

--[[
	Command object.
	Stores the console command and the function to run when these commands are used.
]]
local CommandMeta = {}
CommandMeta.__index = CommandMeta

--[[
	Adds a parameter to a command. This defines what an argument should be parsed into.
]]
function CommandMeta:AddParam( Table )
	Shine.Assert( type( Table ) == "table",
		"Bad argument #1 to AddParam, table expected, got %s", type( Table ) )

	local Args = self.Arguments
	Args[ #Args + 1 ] = Table
end

--[[
	Creates a command object. 
	The object stores the console command and the function to run.
	It can also have parameters added to it to pass to its function.
]]
local function Command( ConCommand, Function )
	return setmetatable( {
		ConCmd = ConCommand,
		Func = Function,
		Arguments = {}
	}, CommandMeta )
end

local HookedCommands = {}

local ClientCommands = {}
Shine.ClientCommands = ClientCommands

--[[
	Registers a Shine client side command.
	Inputs: Console command to assign, function to run.
]]
function Shine:RegisterClientCommand( ConCommand, Function )
	self.Assert( type( ConCommand ) == "string",
		"Bad argument #1 to RegisterClientCommand, string expected, got %s", type( ConCommand ) )
	self.Assert( type( Function ) == "function",
		"Bad argument #2 to RegisterClientCommand, function expected, got %s", type( Function ) )

	local CmdObj = Command( ConCommand, Function )

	ClientCommands[ ConCommand ] = CmdObj

	if not HookedCommands[ ConCommand ] then
		Event.Hook( "Console_"..ConCommand, function( ... )
			return Shine:RunClientCommand( ConCommand, ... )
		end )

		HookedCommands[ ConCommand ] = true
	end

	return CmdObj
end

function Shine:RemoveClientCommand( ConCommand )
	ClientCommands[ ConCommand ] = nil
end

local ParamTypes = Shine.CommandUtil.ParamTypes
local ParseParameter = Shine.CommandUtil.ParseParameter

local function OnError( Error )
	local Trace = Traceback()

	Shine:DebugPrint( "Error: %s.\n%s", true, Error, Trace )
	Shine:AddErrorReport( StringFormat( "Client command error: %s.", Error ), Trace )
end

--[[
	Executes a client side Shine command. Should not be called directly.
	Inputs: Console command to run, string arguments passed to the command.
]]
function Shine:RunClientCommand( ConCommand, ... )
	local Command = ClientCommands[ ConCommand ]
	if not Command or Command.Disabled then return end

	local Args = { ... }

	local ParsedArgs = {}
	local ExpectedArgs = Command.Arguments
	local ExpectedCount = #ExpectedArgs

	for i = 1, ExpectedCount do
		local CurArg = ExpectedArgs[ i ]

		ParsedArgs[ i ] = ParseParameter( nil, Args[ i ], CurArg )

		--Specifically check for nil (boolean argument could be false).
		if ParsedArgs[ i ] == nil and not CurArg.Optional then
			Notify( StringFormat( CurArg.Error or "Incorrect argument #%s to %s, expected %s.",
				i, ConCommand, CurArg.Type ) )

			return
		end

		if CurArg.Type == "string" and CurArg.TakeRestOfLine then
			if i == ExpectedCount then
				ParsedArgs[ i ] = self.CommandUtil.BuildLineFromArgs( CurArg, ParsedArgs[ i ],
					Args, i )
			else
				error( "Take rest of line called on function expecting more arguments!" )
			end
		end
	end

	--Run the command with the parsed arguments we've gathered.
	local Success = xpcall( Command.Func, OnError, unpack( ParsedArgs ) )

	if not Success then
		Shine:DebugPrint( "An error occurred when running the command: '%s'.", true, ConCommand )
	end
end
