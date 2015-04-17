--[[
	Shine screen text rendering client side file.
]]

local DigitalTime = string.DigitalTime
local IsType = Shine.IsType
local SharedTime = Shared.GetTime
local StringFormat = string.format
local TimeToString = string.TimeToString

local Messages = Shine.Map()
Shine.TextMessages = Messages

local StandardFonts = {
	Fonts.kAgencyFB_Small,
	Fonts.kAgencyFB_Medium,
	Fonts.kAgencyFB_Large
}
local HighResFonts = {
	Fonts.kAgencyFB_Medium,
	Fonts.kAgencyFB_Large,
	{ Fonts.kAgencyFB_Huge, 0.6 }
}
local FourKFonts = {
	{ Fonts.kAgencyFB_Huge, 0.6 },
	{ Fonts.kAgencyFB_Huge, 0.8 },
	Fonts.kAgencyFB_Huge
}

local ScreenText = {}
ScreenText.__index = ScreenText

function ScreenText:UpdateText()
	if self.IgnoreFormat then
		self.Obj:SetText( self.Text )
		return
	end

	local TimeConverter = self.Digital and DigitalTime or TimeToString
	self.Obj:SetText( StringFormat( self.Text, TimeConverter( self.Duration ) ) )
end

function ScreenText:End()
	self.LastUpdate = SharedTime() - 1
	self.Duration = 1
end

function ScreenText:Remove()
	Shine.ScreenText.Remove( self.Index )
end

function ScreenText:IsValid()
	return Messages:Get( self.Index ) ~= nil
end

function ScreenText:SetColour( Col )
	self.Colour = Col
	self.Obj:SetColor( Col )
end

function ScreenText:SetText( Text )
	self.Text = Text
	self.Obj:SetText( Text )
end

--[[
	Adds or updates a text label with the given ID and parameters.
]]
function Shine.ScreenText.Add( ID, Params )
	local X = Params.X
	local Y = Params.Y
	local Text = Params.Text
	local Duration = Params.Duration
	local R, G, B = Params.R, Params.G, Params.B
	local Alignment = Params.Alignment
	local FadeIn = Params.FadeIn or 0.5
	local Size = Params.Size or 1
	local IgnoreFormat = Params.IgnoreFormat

	if not Duration then
		IgnoreFormat = true
	end

	local ScrW = Client.GetScreenWidth()
	local ScrH = Client.GetScreenHeight()
	local Font = StandardFonts[ Size ]

	if ScrW > 1920 and ScrW <= 2880 then
		Font = HighResFonts[ Size ]
	elseif ScrW > 2880 then
		Font = FourKFonts[ Size ]
	end

	local ShouldFade = FadeIn > 0.05

	local Time = Shared.GetTime()

	local ScaleVec
	if IsType( Font, "table" ) then
		ScaleVec = Vector( Font[ 2 ], Font[ 2 ], 0 )
		Font = Font[ 1 ]
	else
		ScaleVec = ScrW <= 1920 and GUIScale( Vector( 1, 1, 1 ) ) or Vector( 1, 1, 1 )
	end

	local MessageTable = Messages:Get( ID )
	local GUIObj

	if Alignment == 0 then
		Alignment = GUIItem.Align_Min
	elseif Alignment == 1 then
		Alignment = GUIItem.Align_Center
	else
		Alignment = GUIItem.Align_Max
	end

	if not MessageTable then
		MessageTable = setmetatable( {
			Index = ID
		}, ScreenText )

		Messages:Add( ID, MessageTable )

		GUIObj = GUI.CreateItem()
		GUIObj:SetOptionFlag( GUIItem.ManageRender )
		GUIObj:SetTextAlignmentY( GUIItem.Align_Center )
		GUIObj:SetIsVisible( true )

		MessageTable.Obj = GUIObj
	else
		GUIObj = MessageTable.Obj
	end

	MessageTable.Text = Text
	MessageTable.Colour = Color( R / 255, G / 255, B / 255, ShouldFade and 0 or 1 )
	MessageTable.Duration = Duration
	MessageTable.x = X
	MessageTable.y = Y
	MessageTable.IgnoreFormat = IgnoreFormat

	GUIObj:SetTextAlignmentX( Alignment )
	GUIObj:SetText( IgnoreFormat and Text or StringFormat( Text,
		TimeToString( Duration ) ) )
	GUIObj:SetScale( ScaleVec )
	GUIObj:SetPosition( Vector( ScrW * X, ScrH * Y, 0 ) )
	GUIObj:SetColor( MessageTable.Colour )
	GUIObj:SetFontName( Font )

	if ShouldFade then
		MessageTable.Fading = true
		MessageTable.FadedIn = true
		MessageTable.FadingIn = true
		MessageTable.FadeElapsed = 0
		MessageTable.FadeDuration = FadeIn
	end

	MessageTable.LastUpdate = Time

	return MessageTable
end

--[[
	Changes the text of a text label.
]]
function Shine.ScreenText.SetText( ID, Text )
	local MessageTable = Messages:Get( ID )
	if not MessageTable then return end

	MessageTable.Text = Text
	MessageTable.Obj:SetText( Text )
end

--[[
	Immediately removes a text label.
]]
function Shine.ScreenText.Remove( ID )
	local Message = Messages:Get( ID )
	if not Message then return end

	GUI.DestroyItem( Message.Obj )
	Messages:Remove( ID )
end

--[[
	Sets a text label to fade out from now. Looks better than removing.
]]
function Shine.ScreenText.End( ID )
	local MessageTable = Messages:Get( ID )
	if not MessageTable then return end

	MessageTable:End()
end

--SUPER DUPER DEPRECATED! Use Shine.ScreenText.Add( ID, Params ), and save yourself function argument hell.
function Shine:AddMessageToQueue( ID, X, Y, Text, Duration, R, G, B, Alignment, Size, FadeIn, IgnoreFormat )
	self.ScreenText.Add( ID, {
		X = X, Y = Y,
		Text = Text,
		Duration = Duration,
		R = R, G = G, B = B,
		Alignment = Alignment,
		Size = Size,
		FadeIn = FadeIn,
		IgnoreFormat = IgnoreFormat
	} )
end

local function UpdateMessage( Index, Message, Time )
	if not Message.LastUpdate then
		Message.LastUpdate = Time
	end

	if Message.LastUpdate + 1 > Time then return end

	if Message.Duration then
		Message.Duration = Message.Duration - 1
	end

	Message.LastUpdate = Message.LastUpdate + 1
	Message:UpdateText()

	if Message.Think then
		Message:Think()
	end

	if Message.Duration == 0 then
		Message.FadingIn = false
		Message.Fading = true
		Message.FadeElapsed = 0
		Message.FadeDuration = 1
	end

	if Message.Duration == -1 then
		Shine.ScreenText.Remove( Index )
	end
end

local function ProcessQueue( Time )
	for Index, Message in Messages:Iterate() do
		UpdateMessage( Index, Message, Time )
	end
end

--Not the lifeform...
local function ProcessFades( DeltaTime )
	for Index, Message in Messages:Iterate() do
		if Message.Fading then
			local In = Message.FadingIn

			Message.FadeElapsed = Message.FadeElapsed + DeltaTime

			if Message.FadeElapsed >= Message.FadeDuration then
				Message.Fading = false

				Message.Colour.a = In and 1 or 0

				Message.Obj:SetColor( Message.Colour )
			else
				local Progress = Message.FadeElapsed / Message.FadeDuration
				local Alpha = 1 * ( In and Progress or ( 1 - Progress ) )

				Message.Colour.a = Alpha

				Message.Obj:SetColor( Message.Colour )
			end
		end
	end
end

--DEPRECATED! Use Shine.ScreenText.Remove( Index )
function Shine:RemoveMessage( Index )
	self.ScreenText.Remove( Index )
end

--DEPRECATED! Use Shine.ScreenText.End( Index )
function Shine:EndMessage( Index )
	self.ScreenText.End( Index )
end

Shine.Hook.Add( "Think", "ScreenText", function( DeltaTime )
	local Time = SharedTime()

	ProcessQueue( Time )
	ProcessFades( DeltaTime )
end )

Client.HookNetworkMessage( "Shine_ScreenText", function( Message )
	Shine.ScreenText.Add( Message.ID, Message )
end )

Client.HookNetworkMessage( "Shine_ScreenTextUpdate", function( Message )
	Shine.ScreenText.SetText( Message.ID, Message.Text )
end )

Client.HookNetworkMessage( "Shine_ScreenTextRemove", function( Message )
	Shine.ScreenText.End( Message.ID )
end )
