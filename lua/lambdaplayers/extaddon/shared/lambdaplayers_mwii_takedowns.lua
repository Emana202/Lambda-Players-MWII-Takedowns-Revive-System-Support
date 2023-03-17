if !file.Exists( "autorun/sh_mwii_takedowns.lua", "LUA" ) then return end

local hookName = "Lambda_MWII_Takedowns_"

local enableTakedowns = CreateLambdaConvar( "lambdaplayers_mwii_takedowns_enabled", 1, true, false, false, "If Lambda Players are allowed to execute takedowns when right behind their targets. Make sure that Lambda Players are registered in the Takedown NPC and Can be Takedowned NPC list", 0, 1, { type = "Bool", name = "Enable Takedowns", category = "MWII - Takedowns" } )
local downedBehavior = CreateLambdaConvar( "lambdaplayers_mwii_takedowns_downedbehavior", 0, true, false, false, "What takedown behavior should Lambda Players use on downed targets: 0 - Treat them as everyone else; 1 - Only takedown downed targets; 2 - Never takedown downed targets", 0, 2, { type = "Slider", decimals = 0, name = "Takedown Behavior On Downed Targets", category = "MWII - Takedowns" } )

local function InitializeModule()
	local IsValid = IsValid
	local net = net

	if ( CLIENT ) then

		net.Receive( "lambda_mwii_setplayercolor", function()
			local target = net.ReadEntity()
			if !IsValid( target ) then return end

			local color = net.ReadVector()
			target.GetPlayerColor = function() return color end
		end )

	end

	if ( SERVER ) then

		util.AddNetworkString( "lambda_mwii_setplayercolor" )

		local ipairs = ipairs
		local IsSinglePlayer = game.SinglePlayer
		local random = math.random
		local Rand = math.Rand
		local ents_FindByClass = ents.FindByClass
		local ents_Create = ents.Create
		local table_HasValue = table.HasValue
		local TraceHull = util.TraceHull
		local string_StartWith = string.StartWith
		local trTbl = { filter = { NULL, NULL, NULL, NULL } }
		local plyMeta = FindMetaTable( "Player" )
		local entMeta = FindMetaTable( "Entity" )

		local plyDownedWep = GetConVar( "mwii_revive_canshoot" )
		local npcDownedWep = GetConVar( "mwii_revive_npc_canshoot" )
		local takedownPlayers = GetConVar( "mwii_takedown_npcs_canusetakedowns_players" )
		local takedownAllNPCs = GetConVar( "mwii_takedown_npcs_canusetakedowns_allnpcs" )

		local function OnLambdaTakedown( self, isVictim )
			self.l_isfrozen = true
			self:ClientSideNoDraw( self, true )

			self:ClientSideNoDraw( self.WeaponEnt, true )
			self.WeaponEnt:SetNoDraw( true )
			self.WeaponEnt:DrawShadow( false )

			local tkNPC = NULL
			for _, v in ipairs( ents_FindByClass( "mwii_takedown_npc" ) ) do
				if IsValid( v ) and v.NPC == self then tkNPC = v; break end
			end
			
			if !tkNPC then return end
			self.TakedownNPC = tkNPC
			
			local tkBD = tkNPC.bd
			if IsValid( tkBD ) then
				self.l_BecomeRagdollEntity = tkBD

				net.Start( "lambda_mwii_setplayercolor" )
					net.WriteEntity( tkBD )
					net.WriteVector( self:GetPlyColor() )
				net.Broadcast()
			end

			if isVictim then
				if random( 1, 100 ) <= self:GetVoiceChance() then
					self:SimpleTimer( Rand( 0.33, 1.0 ), function() self:PlaySoundFile( self:GetVoiceLine( "panic" ) ) end )
				end

				for _, v in ipairs( GetLambdaPlayers() ) do
					if v:GetState() != "Combat" or v:GetEnemy() != self then continue end
					v:SetState( "Idle" )
					v:SetEnemy( NULL )
					v:CancelMovement()
				end

				local wepent = self:GetWeaponENT()
				if IsValid( tkBD ) and IsValid( wepent ) and !self:IsWeaponMarkedNodraw() then
					local hasMWWep = false
					if !self:IsDowned() then
						for _, ent in ipairs( self:GetChildren() ) do
							if !IsValid( ent ) then continue end 
							local entMdl = ent:GetModel()
							if entMdl and string_StartWith( entMdl, "models/tdmg/wep/" ) then 
								hasMWWep = true 
								break
							end
						end
					end

					if !hasMWWep then
						local fakeWep = ents_Create( "base_anim" )
						fakeWep:SetModel( wepent:GetModel() )
						fakeWep:SetPos( wepent:GetPos() )
						fakeWep:SetAngles( wepent:GetAngles() )
						fakeWep:SetParent( tkBD, wepent:GetParentAttachment() )
						fakeWep:Spawn()
						
						fakeWep:SetModelScale( wepent:GetModelScale() )
						fakeWep:SetSkin( wepent:GetSkin() )
						for _, v in ipairs( wepent:GetBodyGroups() ) do 
							fakeWep:SetBodygroup( v.id, wepent:GetBodygroup( v.id ) )
						end

						fakeWep:SetLocalPos( wepent:GetLocalPos() )
						fakeWep:SetLocalAngles( wepent:GetLocalAngles() )

						fakeWep:SetNW2Vector( "lambda_weaponcolor", wepent:GetNW2Vector( "lambda_weaponcolor" ) )
						if wepent:IsEffectActive( EF_BONEMERGE ) then fakeWep:AddEffects( EF_BONEMERGE ) end
						
						tkBD:DeleteOnRemove( fakeWep )
					end
				end
			elseif random( 1, 100 ) <= self:GetVoiceChance() then
				self:SimpleTimer( tkNPC.Delay / Rand( 1.25, 1.5 ), function()
					if self:IsSpeaking() then return end
					self:PlaySoundFile( self:GetVoiceLine( "kill" ) ) 
				end )
			end

			local thinkFinishTime = CurTime() + tkNPC.Delay
			self:NamedTimer( "MWIITakedown_FakeThink", 0, 0, function()
				local tkPartner = ( isVictim and self.TakedownFinisher or !isVictim and self.TakedowningTarget or nil )
				local partnerDead = ( !self.TakedownIsFinished and ( !IsValid( tkPartner ) or tkPartner.IsLambdaPlayer and !tkPartner:Alive() and !tkPartner.Takedowning ) )

				if CurTime() > thinkFinishTime or !self.Takedowning or !self:Alive() or partnerDead then
					if partnerDead and IsValid( tkNPC ) then tkNPC:Finish() end

					self.l_isfrozen = false
					self.Takedowning = false
					self.TakedowningTarget = nil

					if self:Alive() then
						self:ClientSideNoDraw( self, false )
						
						local wepent = self:GetWeaponENT()
						local wepNoDraw = self:IsWeaponMarkedNodraw()
						self:ClientSideNoDraw( wepent, wepNoDraw )
						wepent:SetNoDraw( wepNoDraw )
						wepent:DrawShadow( !wepNoDraw )
					end

					return true
				end

				if IsValid( tkBD ) then
					local rootPos = tkBD:GetBonePosition( 0 )
					local bdPos = ( rootPos - vector_up * ( self:WorldSpaceCenter():Distance( self:GetPos() ) ) )
					local mins, maxs = self:GetCollisionBounds()

					trTbl.start = rootPos
					trTbl.endpos = bdPos
					trTbl.mins = mins
					trTbl.maxs = maxs

					trTbl.filter[ 1 ] = self
					trTbl.filter[ 2 ] = tkNPC
					trTbl.filter[ 3 ] = tkBD
					trTbl.filter[ 4 ] = self.TakedowningTarget

					self:SetPos( TraceHull( trTbl ).HitPos )
				end
			end )

			return tkNPC
		end

		local oldPlayerTakedown = plyMeta.Takedown
		function plyMeta:Takedown()
			local trEnt = self:GetEyeTrace().Entity
			if IsValid( trEnt ) and trEnt.IsLambdaPlayer and ( !trEnt:Alive() or ( LambdaTeams and LambdaTeams:AreTeammates( self, trEnt ) or trEnt.IsFriendsWith and trEnt:IsFriendsWith( self ) ) ) then return end

			oldPlayerTakedown( self )
			if !self.Takedowning then return end

			local target = self.TakedowningTarget
			if !IsValid( target ) or !target.IsLambdaPlayer then return end

			target.TakedownFinisher = self
			OnLambdaTakedown( target, true )
		end

		local oldNPCTakedown = entMeta.NPC_Takedown
		function entMeta:NPC_Takedown( ent )
			if IsValid( ent ) and ent.IsLambdaPlayer and ( !ent:Alive() or ( LambdaTeams and LambdaTeams:AreTeammates( self, ent ) or self.IsFriendsWith and self:IsFriendsWith( ent ) ) ) then return end

			oldNPCTakedown( self, ent )
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

		local function LambdaBlankFunction( self ) end

		local function OnInitialize( self )
			self.GetActiveWeapon = LambdaBlankFunction
			self.l_TakedownCheckTime = CurTime() + Rand( 0.1, 0.25 )
		end

		local LambdaIsAtBack = plyMeta.IsAtBack
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
				if IsValid( ene ) and !ene.Takedowning and ene:Health() > 0 and ( ( ene.IsLambdaPlayer or ene:IsPlayer() and takedownPlayers:GetBool() ) and ene:Alive() and !ene:HasGodMode() or ( ene:IsNPC() or ene:IsNextBot() and !ene.IsLambdaPlayer ) and ( takedownAllNPCs:GetBool() or table_HasValue( takedownedNPCsClassList, ene:GetClass() ) ) ) then
					local IsDowned = ene:IsDowned()
					local downBehav = downedBehavior:GetInt()
					if downBehav == 0 or downBehav == 1 and IsDowned or downBehav == 2 and !IsDowned then
						local isBehind = LambdaIsAtBack( self, ene )
						if CurTime() > self.l_TakedownCheckTime and ( isBehind and self:IsInRange( ene, 70 ) or IsDowned and self:IsInRange( ene, 32 ) ) and self:CanSee( ene ) then
							self:NPC_Takedown( ene )
						elseif IsDowned or isBehind and ( ene:IsPlayer() and self:IsInRange( ene, 300 ) or ene.IsLambdaPlayer and ( !ene:InCombat() or ene:GetEnemy() != self ) ) then
							self.l_PrevKeepDistance = self.l_CombatKeepDistance
							self.l_CombatKeepDistance = 0

							local target = ( ene.IsLambdaPlayer and ene:GetEnemy() or NULL )
							if !LambdaIsValid( target ) or !self.IsFriendsWith or !self:IsFriendsWith( target ) or !LambdaTeams or !LambdaTeams:AreTeammates( self, target ) or !LambdaIsAtBack( ene, target ) and !target:IsDowned() then
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

			if CurTime() > self.l_TakedownCheckTime then
				self.l_TakedownCheckTime = CurTime() + Rand( 0.1, 0.25 )
			end
		end

		-- Don't target entities that are being takedowned by someone
		local function OnCanTarget( self, target )
			if target.Takedowning and !IsValid( target.TakedowningTarget ) then return true end
		end

		-- Don't change weapons while in takedown
		local function OnCanSwitchWeapon( self, name, data )
			if self.IsTakedowning then return true end
		end

		local function OnKilled( self, dmginfo )
			self:SetNWBool( "HeadBlowMWII", false )

			if IsValid( self.TakedownNPC ) then
				self.l_isfrozen = false

				local tkTarget = self.TakedowningTarget
				if LambdaIsValid( tkTarget ) and tkTarget.IsLambdaPlayer then
					local attacker = dmginfo:GetAttacker()
					if attacker != self and attacker != tkTarget then
						if tkTarget.AddFriend and random( 1, 100 ) <= 33 then tkTarget:AddFriend( self ) end
						if random( 1, 100 ) <= tkTarget:GetVoiceChance() then tkTarget:PlaySoundFile( tkTarget:GetVoiceLine( "assist" ) ) end
					end
				end
				self.TakedowningTarget = NULL
				self.TakedownFinisher = NULL

				self:SimpleTimer( 0, function() 
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