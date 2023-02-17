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
		local table_HasValue = table.HasValue
		local TraceHull = util.TraceHull
		local trTbl = { filter = { NULL, NULL, NULL, NULL } }
		local plyMeta = FindMetaTable( "Player" )
		local entMeta = FindMetaTable( "Entity" )

		local plyDownedWep = GetConVar( "mwii_revive_canshoot" )
		local npcDownedWep = GetConVar( "mwii_revive_npc_canshoot" )
		local takedownPlayers = GetConVar( "mwii_takedown_npcs_canusetakedowns_players" )
		local takedownAllNPCs = GetConVar( "mwii_takedown_npcs_canusetakedowns_allnpcs" )
		local serverRagdolls = GetConVar( "lambdaplayers_lambda_serversideragdolls" )

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
        		if !IsSinglePlayer() or serverRagdolls:GetBool() then self.l_BecomeRagdollEntity = tkBD end

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

        		local wepent = self.WeaponEnt
		        if IsValid( tkBD ) and IsValid( wepent ) and !self:IsWeaponMarkedNodraw() then
			        local hasMWWep = false
		        	if !self:IsDowned() then
			        	for _, ent in ipairs( self:GetChildren() ) do
			        		if !IsValid( ent ) then continue end 
			        		local entMdl = ent:GetModel()
			        		if entMdl and string.StartWith( entMdl, "models/tdmg/wep/" ) then 
			        			hasMWWep = true 
			        			break
			        		end
			        	end
			        end

		        	if !hasMWWep then
		        		local fakeWep = ents.Create( "base_anim" )
		        		fakeWep:SetModel( wepent:GetModel() )
		        		fakeWep:SetPos( wepent:GetPos() )
		        		fakeWep:SetAngles( wepent:GetAngles() )
				        fakeWep:SetParent( tkBD, wepent:GetParentAttachment() )
				        fakeWep:Spawn()
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
	        	local tkPartner = ( isVictim and self.TakedownFinisher or self.TakedowningTarget )
	        	local partnerDead = ( !self.TakedownIsFinished and ( !IsValid( tkPartner ) or tkPartner.IsLambdaPlayer and !tkPartner:Alive() ) )

				if CurTime() > thinkFinishTime or !self.Takedowning or !self:Alive() or partnerDead then
    				if partnerDead then tkNPC:Finish() end

    				self.l_isfrozen = false
		            self.Takedowning = false
		            self.TakedowningTarget = nil

		            if self:Alive() then
		            	self:ClientSideNoDraw( self, false )
			            
			            local wepNoDraw = self:IsWeaponMarkedNodraw()
			            self:ClientSideNoDraw( self.WeaponEnt, wepNoDraw )
				        self.WeaponEnt:SetNoDraw( wepNoDraw )
				        self.WeaponEnt:DrawShadow( !wepNoDraw )
				    end

			        return true
	        	end

				if IsValid( tkBD ) then
        			local rootPos = tkBD:GetBonePosition( 0 )
        			local bdPos = ( rootPos - self:GetUp() * ( self:WorldSpaceCenter():Distance( self:GetPos() ) ) )

		        	trTbl.start = rootPos
		        	trTbl.endpos = bdPos
		        	trTbl.mins = self:OBBMins()
		        	trTbl.maxs = self:OBBMaxs()

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
		local function OnThink( self, wepent )
	        if self.l_PrevKeepDistance then
	            self.l_CombatKeepDistance = self.l_PrevKeepDistance
	            self.l_PrevKeepDistance = nil
	        end
	        if self.l_PrevAttackDistance then
	            self.l_CombatAttackRange = self.l_PrevAttackDistance
	            self.l_PrevAttackDistance = nil
	        end

	        if enableTakedowns:GetBool() and self:GetState() == "Combat" and !self:IsDowned() and !self.Takedowning and table_HasValue( takedownNPCsClassList, "npc_lambdaplayer" ) then
	        	local ene = self:GetEnemy()
	        	if IsValid( ene ) and !ene.Takedowning and ene:Health() > 0 and ( ( ene.IsLambdaPlayer or ene:IsPlayer() and takedownPlayers:GetBool() ) and ene:Alive() and !ene:HasGodMode() or ( ene:IsNPC() or ene:IsNextBot() and !ene.IsLambdaPlayer ) and ( takedownAllNPCs:GetBool() or table_HasValue( takedownedNPCsClassList, ene:GetClass() ) ) ) then
			        local IsDowned = ene:IsDowned()
			        local downBehav = downedBehavior:GetInt()

			        if downBehav == 0 or downBehav == 1 and IsDowned or downBehav == 2 and !IsDowned then
				        local isBehind = LambdaIsAtBack( self, ene )
				        if CurTime() > self.l_TakedownCheckTime and ( isBehind and self:IsInRange( ene, 70 ) or IsDowned and self:IsInRange( ene, 32 ) ) and self:CanSee( ene ) then
				        	self:NPC_Takedown( ene )
				        else
				        	local eneTarget = ( ene.GetEnemy and ene:GetEnemy() or NULL )
				        	
				        	if IsDowned or isBehind and ( ( ene:IsPlayer() and self:IsInRange( ene, 325 ) or ene.IsLambdaPlayer and ( !ene:InCombat() or eneTarget != self ) or eneTarget != self ) and ( !self.IsFriendsWith or !self.IsFriendsWith( eneTarget ) ) and ( !LambdaTeams or !LambdaTeams:AreTeammates( self, eneTarget ) ) ) then
				                self.l_PrevKeepDistance = self.l_CombatKeepDistance
				                self.l_CombatKeepDistance = 0

				                if !IsDowned or ene.IsLambdaPlayer and ( !ene:HasLethalWeapon() or ene:GetState() != "Combat" or ene:GetEnemy() != self ) or ene:IsPlayer() and !plyDownedWep:GetBool() or ene:IsNPC() and !npcDownedWep:GetBool() then
					                self.l_PrevAttackDistance = self.l_CombatAttackRange
					                self.l_CombatAttackRange = 0
					            end

				                self.l_movepos = ( ene:GetPos() - ene:GetForward() * 32 )
				            end
			        	end
			        end
	        	end
	        end

	       	if CurTime() > self.l_TakedownCheckTime then
	        	self.l_TakedownCheckTime = CurTime() + Rand( 0.1, 0.25 )
	        end
		end

		local function OnCanTarget( self, target )
			if target.Takedowning and !IsValid( target.TakedowningTarget ) then return true end
		end

		local function OnKilled( self, dmginfo )
			self:SetNWBool( "HeadBlowMWII", false )
			self:RemoveNamedTimer( "MWIITakedown_FakeThink" )

			if IsValid( self.TakedownNPC ) then
				local tkTarget = self.TakedowningTarget
				if LambdaIsValid( tkTarget ) and tkTarget.IsLambdaPlayer then
					local attacker = dmginfo:GetAttacker()
					if attacker != self and attacker != target then
					    if self.AddFriend and random( 1, 100 ) <= 33 then self:AddFriend( attacker ) end
						if random( 1, 100 ) <= self:GetVoiceChance() then attacker:PlaySoundFile( attacker:GetVoiceLine( "assist" ) ) end
					end
				end
				self.TakedowningTarget = NULL

				local tkFinisher = self.TakedownFinisher
				if IsValid( tkFinisher ) then tkFinisher.TakedownIsFinished = true end
				self.TakedownFinisher = NULL

				self.TakedownNPC:Finish()
				self.TakedownNPC = NULL

	        	self.l_isfrozen = false
				self:DrawShadow( false )

				self.Takedowning = false
				self.WasTakedowning = false
			end
		end

		hook.Add( "LambdaOnInitialize", hookName .. "OnInitialize", OnInitialize )
		hook.Add( "LambdaOnThink", hookName .. "OnThink", OnThink )
		hook.Add( "LambdaCanTarget", hookName .. "OnCanTarget", OnCanTarget )
		hook.Add( "LambdaOnKilled", hookName .. "OnKilled", OnKilled )

	end
end

hook.Add( "InitPostEntity", hookName .. "InitializeModule", InitializeModule )