if !file.Exists( "autorun/sh_mwii_takedowns.lua", "LUA" ) and !file.Exists( "autorun/sh_mw3_takedowns.lua", "LUA" ) then return end
local hookName = "LambdaMWII_Takedowns_"

local enableTakedowns = CreateLambdaConvar( "lambdaplayers_mwii_takedowns_enabled", 1, true, false, false, "If Lambda Players are allowed to execute takedowns when right behind their targets. Make sure that Lambda Players are registered in the Takedown NPC and Can be Takedowned NPC list", 0, 1, { type = "Bool", name = "Enable Takedowns", category = "MWII - Takedowns" } )
local downedBehavior = CreateLambdaConvar( "lambdaplayers_mwii_takedowns_downedbehavior", 0, true, false, false, "What takedown behavior should Lambda Players use on downed targets: 0 - Treat them as everyone else; 1 - Only takedown downed targets; 2 - Never takedown downed targets", 0, 2, { type = "Slider", decimals = 0, name = "Takedown Behavior On Downed Targets", category = "MWII - Takedowns" } )

local function InitializeModule()
	LambdaMWII_TakedownsInitialized = true

	local IsValid = IsValid
	local net = net

	if ( CLIENT ) then

		net.Receive( "lambdamwii_setplayercolor", function()
			local target = net.ReadEntity()
			if !IsValid( target ) then return end

			local color = net.ReadVector()
			target.GetPlayerColor = function() return color end
		end )

	end

	if ( SERVER ) then

		util.AddNetworkString( "lambdamwii_setplayercolor" )

		local ipairs = ipairs
		local IsSinglePlayer = game.SinglePlayer
		local deg = math.deg
		local acos = math.acos
		local ents_FindByClass = ents.FindByClass
		local ents_Create = ents.Create
		local table_HasValue = table.HasValue
		local TraceHull = util.TraceHull
		local string_StartWith = string.StartWith
		local trTbl = { filter = { NULL, NULL, NULL, NULL } }

		local plyDownedWep = GetConVar( "mwii_revive_canshoot" )
		local npcDownedWep = GetConVar( "mwii_revive_npc_canshoot" )
		local takedownPlayers = GetConVar( "mwii_takedown_npcs_canusetakedowns_players" )
		local takedownAllNPCs = GetConVar( "mwii_takedown_npcs_canusetakedowns_allnpcs" )

		local function OnLambdaTakedown( self, isVictim )
			local tkNPC = nil
			for _, v in ipairs( ents_FindByClass( "mwii_takedown_npc" ) ) do
				if IsValid( v ) and v.NPC == self then tkNPC = v; break end
			end
			if !tkNPC then return end

			local prevWeapon = self.l_Weapon
			self:SwitchWeapon( "none", true )
			self:PreventWeaponSwitch( true )

			self.TakedownNPC = tkNPC
			self.l_isfrozen = true
			self:ClientSideNoDraw( self, true )

			local hiddenChildren = {}
			for _, child in ipairs( self:GetChildren() ) do
				if !IsValid( child ) or child == self.WeaponEnt or child:GetNoDraw() then continue end

				local mdl = child:GetModel()
				if !mdl or mdl == "" then continue end

				self:ClientSideNoDraw( child, true )
				child:SetRenderMode( RENDERMODE_NONE )
				child:DrawShadow( false )
				hiddenChildren[ #hiddenChildren + 1 ] = child
			end

			local tkBD = tkNPC.bd
			if IsValid( tkBD ) then
				self.l_BecomeRagdollEntity = tkBD
				self:GetNW2Entity( "lambda_serversideragdoll", tkBD )

				for _, child in ipairs( hiddenChildren ) do
				    local fakeChild = ents_Create( "base_anim" )
				    fakeChild:SetModel( child:GetModel() )
				    fakeChild:SetPos( tkBD:GetPos() )
				    fakeChild:SetAngles( tkBD:GetAngles() )
				    fakeChild:SetOwner( tkBD )
				    fakeChild:SetParent( tkBD )
				    fakeChild:Spawn()
				    fakeChild:AddEffects( EF_BONEMERGE )
				    tkBD:DeleteOnRemove( fakeChild )
				end

				net.Start( "lambdamwii_setplayercolor" )
					net.WriteEntity( tkBD )
					net.WriteVector( self:GetPlyColor() )
				net.Broadcast()
			end

			if isVictim then
				if LambdaRNG( 100 ) <= ( self:GetVoiceChance() * 2 ) then
					self:SimpleTimer( LambdaRNG( 0.33, 1, true ), function() self:PlaySoundFile( self:GetVoiceLine( "panic" ), false ) end )
				end

				for _, v in ipairs( GetLambdaPlayers() ) do
					if v:GetState() != "Combat" or v:GetEnemy() != self then continue end
					v:SetState( "Idle" )
					v:SetEnemy( NULL )
					v:CancelMovement()
				end
			elseif LambdaRNG( 100 ) <= ( self:GetVoiceChance() * 2 ) then
				self:SimpleTimer( tkNPC.Delay / LambdaRNG( 1.25, 1.5, true ), function()
					if self:IsSpeaking() then return end
					self:PlaySoundFile( self:GetVoiceLine( "kill" ), false ) 
				end )
			end

			local thinkFinishTime = CurTime() + tkNPC.Delay
			local mins, maxs = self:GetCollisionBounds()

			self:NamedTimer( "MWIITakedown_FakeThink", 0, 0, function()
				local tkPartner = ( isVictim and self.TakedownFinisher or !isVictim and self.TakedowningTarget or nil )
				local partnerDead = ( !self.TakedownIsFinished and ( !IsValid( tkPartner ) or tkPartner.IsLambdaPlayer and !tkPartner:Alive() and !tkPartner.Takedowning ) )

				if CurTime() >= thinkFinishTime or !self.Takedowning or !self:Alive() or partnerDead then
					if partnerDead and IsValid( tkNPC ) then tkNPC:Finish() end

					self.l_isfrozen = false
					self.Takedowning = false
					self.TakedowningTarget = nil

					if self:Alive() then
						self:ClientSideNoDraw( self, false )

						self:PreventWeaponSwitch( false )
						self:SwitchWeapon( prevWeapon )

						for _, child in ipairs( hiddenChildren ) do
							if !IsValid( child ) then continue end
							self:ClientSideNoDraw( child, false )
							child:SetRenderMode( RENDERMODE_NORMAL )
							child:DrawShadow( true )
						end
					end

					return true
				end

				if IsValid( tkBD ) then
					local rootPos = tkBD:GetBonePosition( 0 )
					local bdPos = ( rootPos - vector_up * ( self:WorldSpaceCenter():Distance( self:GetPos() ) ) )

					trTbl.start = rootPos
					trTbl.endpos = bdPos
					trTbl.mins, trTbl.maxs = mins, maxs

					trTbl.filter[ 1 ] = self
					trTbl.filter[ 2 ] = tkNPC
					trTbl.filter[ 3 ] = tkBD
					trTbl.filter[ 4 ] = self.TakedowningTarget

					self:SetPos( TraceHull( trTbl ).HitPos )
				end
			end )

			return tkNPC
		end

		local plyMeta = FindMetaTable( "Player" )
		LambdaMWII_OldPlayerTakedown = ( LambdaMWII_OldPlayerTakedown or plyMeta.Takedown )

		function plyMeta:Takedown()
			local trEnt = self:GetEyeTrace().Entity
			if IsValid( trEnt ) and trEnt.IsLambdaPlayer and ( !trEnt:Alive() or ( LambdaTeams and LambdaTeams:AreTeammates( self, trEnt ) or trEnt.IsFriendsWith and trEnt:IsFriendsWith( self ) ) ) then return end

			LambdaMWII_OldPlayerTakedown( self )
			if !self.Takedowning then return end

			local target = self.TakedowningTarget
			if !IsValid( target ) or !target.IsLambdaPlayer then return end

			target.TakedownFinisher = self
			OnLambdaTakedown( target, true )
		end

		local entMeta = FindMetaTable( "Entity" )
		LambdaMWII_OldNPCTakedown = ( LambdaMWII_OldNPCTakedown or entMeta.NPC_Takedown )
		LambdaMWII_OldSetModel = ( LambdaMWII_OldSetModel or entMeta.SetModel )

		function entMeta:NPC_Takedown( ent )
			if IsValid( ent ) and ent.IsLambdaPlayer and ( !ent:Alive() or ( LambdaTeams and LambdaTeams:AreTeammates( self, ent ) or self.IsFriendsWith and self:IsFriendsWith( ent ) ) ) then return end

			LambdaMWII_OldNPCTakedown( self, ent )
			if !self.Takedowning then return end

			if self.IsLambdaPlayer then
				OnLambdaTakedown( self )
			end

			local target = self.TakedowningTarget
			if IsValid( target ) and target.IsLambdaPlayer then
				target.TakedownFinisher = self
				OnLambdaTakedown( target, true )
			end
		end

		function entMeta:SetModel( mdl )
			if !mdl then return end

			if self.Finisher != nil then
				local lambda = self.NPC
			 	if IsValid( lambda ) and lambda.IsLambdaPlayer then
			 		local lambdaMdl = lambda:GetModel()
					if lambdaMdl then mdl = lambdaMdl end
			 	end
			end

			LambdaMWII_OldSetModel( self, mdl )
		end

		local function LambdaBlankFunction( self ) end

		local function OnInitialize( self )
			self.GetActiveWeapon = LambdaBlankFunction
			self.l_TakedownCheckTime = CurTime() + LambdaRNG( 0.1, 0.25, true )
		end

		local onlyFromBack = GetConVar( "mwii_takedown_only_from_back" )
		local function IsAtTargetsBack( self, target )
	        if !IsValid( target ) then return end
	        if self:IsPlayer() and !onlyFromBack:GetBool() then return true end
	        return ( deg( acos( target:GetForward():Angle():Forward():Dot( ( self:GetPos() - target:GetPos() ):GetNormalized() ) ) ) > 100 )
	    end

		local function OnThink( self, wepent, dead )
			if dead then return end

			if self.l_PrevKeepDistance then
				self.l_CombatKeepDistance = self.l_PrevKeepDistance
				self.l_PrevKeepDistance = nil
			end
			if self.l_PrevAttackDistance then
				self.l_CombatAttackRange = self.l_PrevAttackDistance
				self.l_PrevAttackDistance = nil
			end

			if !self.Takedowning and !self:IsDowned() and self:GetState() == "Combat" and enableTakedowns:GetBool() and table_HasValue( takedownNPCsClassList, "npc_lambdaplayer" ) then
				local ene = self:GetEnemy()
				if IsValid( ene ) and !ene.Takedowning and ene:Health() > 0 and ( ( ene.IsLambdaPlayer or ene:IsPlayer() and takedownPlayers:GetBool() ) and ene:Alive() and !ene:HasGodMode() or ( ene:IsNPC() or ene:IsNextBot() and !ene.IsLambdaPlayer ) and ( takedownAllNPCs:GetBool() or table_HasValue( takedownedNPCsClassList, ene:GetClass() ) ) ) and self:IsInRange( ene, 1000 ) then
					local IsDowned = ene:IsDowned()
					local downBehav = downedBehavior:GetInt()
					if downBehav == 0 or downBehav == 1 and IsDowned or downBehav == 2 and !IsDowned then
						local isBehind = IsAtTargetsBack( self, ene )
						if CurTime() >= self.l_TakedownCheckTime and ( isBehind and self:IsInRange( ene, 70 ) or IsDowned and self:IsInRange( ene, 32 ) ) and self:CanSee( ene ) then
							self:NPC_Takedown( ene )
						elseif IsDowned or isBehind and ( ene:IsPlayer() and self:IsInRange( ene, 300 ) or ene.IsLambdaPlayer and ( !ene:InCombat() or ene:GetEnemy() != self ) ) then
							self.l_PrevKeepDistance = self.l_CombatKeepDistance
							self.l_CombatKeepDistance = 0

							local target = ( ene.IsLambdaPlayer and ene:GetEnemy() or NULL )
							if !LambdaIsValid( target ) or !self.IsFriendsWith or !self:IsFriendsWith( target ) or !LambdaTeams or !LambdaTeams:AreTeammates( self, target ) or !IsAtTargetsBack( ene, target ) and !target:IsDowned() then
								if !IsDowned or ene.IsLambdaPlayer and ( !ene:HasLethalWeapon() or !ene:InCombat() or ene:GetEnemy() != self ) or ene:IsPlayer() and !plyDownedWep:GetBool() or ene:IsNPC() and !npcDownedWep:GetBool() then
									self.l_PrevAttackDistance = self.l_CombatAttackRange
									self.l_CombatAttackRange = 0
								end
							end

							self.l_movepos = ( ene:GetPos() - ene:GetForward() * 32 )
						end
					end
				end
			end

			if CurTime() >= self.l_TakedownCheckTime then
				self.l_TakedownCheckTime = CurTime() + LambdaRNG( 0.1, 0.25, true )
			end
		end

		-- Don't target entities that are being takedowned by someone
		local function OnCanTarget( self, target )
			if target.Takedowning and !IsValid( target.TakedowningTarget ) then return true end
		end

		-- Don't change weapons while in takedown
		local function OnCanSwitchWeapon( self, name, data )
			if self.Takedowning then return true end
		end

		local function OnKilled( self, dmginfo )
			self:SimpleTimer( 0.1, function()
				self:SetNWBool( "HeadBlowMWII", false )
			end, true )

			if IsValid( self.TakedownNPC ) then
				self.l_isfrozen = false

				local tkTarget = self.TakedowningTarget
				if LambdaIsValid( tkTarget ) and tkTarget.IsLambdaPlayer then
					local attacker = dmginfo:GetAttacker()
					if attacker != self and attacker != tkTarget then
						if tkTarget.AddFriend and LambdaRNG( 3 ) == 1 then tkTarget:AddFriend( self ) end
						if LambdaRNG( 100 ) <= tkTarget:GetVoiceChance() then tkTarget:PlaySoundFile( tkTarget:GetVoiceLine( "assist" ) ) end
					end
				end
				self.TakedowningTarget = NULL
				self.TakedownFinisher = NULL

				self:SimpleTimer( 0, function() 
					self:SetCollisionGroup( COLLISION_GROUP_IN_VEHICLE )

					if !IsValid( self.TakedownNPC ) then return end
					self.TakedownNPC:Finish() 
					self.TakedownNPC = NULL
					self.Takedowning = false
					self:DrawShadow( false )
				end, true )
			end
		end

		hook.Add( "LambdaOnInitialize", hookName .. "OnInitialize", OnInitialize )
		hook.Add( "LambdaOnThink", hookName .. "OnThink", OnThink )
		hook.Add( "LambdaCanTarget", hookName .. "OnCanTarget", OnCanTarget )
		hook.Add( "LambdaCanSwitchWeapon", hookName .. "CanSwitchWeapon", OnCanSwitchWeapon )
		hook.Add( "LambdaOnKilled", hookName .. "OnKilled", OnKilled )

	end
end

hook.Add( "InitPostEntity", hookName .. "InitializeModule", InitializeModule )
if LambdaMWII_TakedownsInitialized then InitializeModule() end