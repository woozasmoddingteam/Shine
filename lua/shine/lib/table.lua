--[[
	Shine table library.
]]

local pairs = pairs
local Random = math.random
local StringFormat = string.format
local StringRep = string.rep
local TableConcat = table.concat
local TableSort = table.sort

--[[
	Clears a table.
]]
local function TableEmpty( Table )
	for k in pairs( Table ) do
		Table[ k ] = nil
	end
end
table.Empty = TableEmpty

--[[
	Fixes an array with holes in it.
]]
function table.FixArray( Table )
	local Array = {}
	local Largest = 0

	--Get the upper bound key, cannot rely on #Table or table.Count.
	for Key in pairs( Table ) do
		if Key > Largest then
			Largest = Key
		end
	end

	--Nothing to do, it's an empty table.
	if Largest == 0 then return end

	local Count = 0

	--Clear out the table, and store values in order into the array.
	for i = 1, Largest do
		local Value = Table[ i ]

		if Value ~= nil then
			Count = Count + 1

			Array[ Count ] = Value
			Table[ i ] = nil
		end
	end

	--Restore the values to the original table in array form.
	for i = 1, Count do
		Table[ i ] = Array[ i ]
	end
end

--[[
	Shuffles a table randomly.
]]
function table.Shuffle( Table )
	local SortTable = {}
	local NewTable = {}

	local Count = 1

	for Index, Value in pairs( Table ) do
		SortTable[ Value ] = Random()
		
		--Add the value to a new table to get rid of potential holes in the array.
		NewTable[ Count ] = Value
		Count = Count + 1
	end

	--Empty the input table, we're going to repopulate it as an array with no holes.
	TableEmpty( Table )

	TableSort( NewTable, function( A, B )
		return SortTable[ A ] > SortTable[ B ]
	end )

	--Repopulate the input table with our sorted table. This won't have holes.
	for Index, Value in pairs( NewTable ) do
		Table[ Index ] = Value
	end
end

--[[
	Chooses a random entry from the table 
	with each entry having equal probability of being picked.
]]
function table.ChooseRandom( Table )
	local Count = #Table
	local Interval = 1 / Count

	local Rand = Random()
	local InRange = math.InRange

	for i = 1, Count do
		local Lower = Interval * ( i - 1 )
		local Upper = i ~= Count and ( Interval * i ) or 1

		if InRange( Lower, Rand, Upper ) then
			return Table[ i ], i
		end
	end
end

--[[
	Returns the average of the numerical values in the table.
]]
function table.Average( Table )
	local Count = #Table
	
	if Count == 0 then return 0 end
	
	local Sum = 0

	for i = 1, Count do
		Sum = Sum + Table[ i ]
	end

	return Sum / Count
end

local IsType = Shine.IsType

--[[
	Prints a nicely formatted table structure to the console.
]]
function PrintTable( Table, Indent )
	Indent = Indent or 0

	local IndentString = StringRep( "\t", Indent )

	for k, v in pairs( Table ) do
		if IsType( v, "table" ) then
			Print( "%s%s:\n", IndentString, tostring( k ) )
			PrintTable( v, Indent + 2 )
		else
			Print( "%s%s = %s", IndentString, tostring( k ), tostring( v ) )
		end
	end
end

function table.ToString( Table, Indent )
	Indent = Indent or 0
	
	local Strings = {}

	local IndentString = StringRep( "\t", Indent )

	for k, v in pairs( Table ) do
		if IsType( v, "table" ) then
			Strings[ #Strings + 1 ] = StringFormat( "%s%s:", IndentString, tostring( k ) )
			Strings[ #Strings + 1 ] = table.ToString( v, Indent + 2 )
		else
			Strings[ #Strings + 1 ] = StringFormat( "%s%s = %s", IndentString, tostring( k ), tostring( v ) )
		end
	end

	return TableConcat( Strings, "\n" )
end

local function CopyTable( Table, LookupTable )
	if not Table then return nil end
	
	local Copy = {}
	setmetatable( Copy, getmetatable( Table ) )

	for Key, Value in pairs( Table ) do
		if not IsType( Value, "table" ) then
			Copy[ Key ] = Value
		else
			LookupTable = LookupTable or {}
			LookupTable[ Table ] = Copy

			if LookupTable[ Value ] then
				Copy[ Key ] = LookupTable[ Value ]
			else
				Copy[ Key ] = CopyTable( Value, LookupTable )
			end
		end
	end

	return Copy
end
table.Copy = CopyTable

function table.Count( Table )
	local i = 0

	for k in pairs( Table ) do 
		i = i + 1 
	end

	return i
end

function RandomPairs( Table, Desc )
	local Sorted = {}
	local Count = 0

	for Key in pairs( Table ) do
		Count = Count + 1
		Sorted[ Count ] = { Key = Key, Rand = Random() }
	end
	
	if Desc then
		TableSort( Sorted, function( A, B )
			return A.Rand > B.Rand
		end )
	else
		TableSort( Sorted, function( A, B )
			return A.Rand < B.Rand
		end )
	end

	local i = 1

	return function()
		local Key = Sorted[ i ] and Sorted[ i ].Key
		if not Key then return nil end
		
		local Value = Table[ Key ]

		if not Value then
			return nil
		end

		i = i + 1

		return Key, Value
	end
end

function SortedPairs( Table, Desc )
	local Sorted = {}
	local Count = 0

	for Key in pairs( Table ) do
		Count = Count + 1
		Sorted[ Count ] = Key
	end

	if Desc then
		TableSort( Sorted, function( A, B )
			return A > B
		end )
	else
		TableSort( Sorted, function( A, B )
			return A < B
		end )
	end
	
	local i = 1

	return function()
		local Key = Sorted[ i ]
		if not Key then return nil end
		
		local Value = Table[ Key ]

		if not Value then
			return nil
		end

		i = i + 1

		return Key, Value
	end
end
