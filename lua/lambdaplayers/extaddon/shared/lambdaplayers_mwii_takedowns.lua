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
	        if tkNPC then
	        	self.TakedownNPC = tkNPC
	        	self.TakedownTime = CurTime() + tkNPC.Delay

	        	local tkBD = tkNPC.bd
	        	if IsValid( tkBD ) then
	        		if !game.SinglePlayer() then self.l_BecomeRagdollEntity = tkBD end

		        	net.Start( "lambda_mwii_setplayercolor" )
		        		net.WriteEntity( tkBD )
		        		net.WriteVector( self:GetPlyColor() )
		        	net.Broadcast()

			        local target = self.TakedowningTarget
		        	local finishTime = CurTime() + tkNPC.Delay
			        self:NamedTimer( "MWIITakedown_FollowModel", 0, 0, function()
	        			if self:GetIsDead() or !IsValid( tkBD ) then return true end
	        			
	        			local rootPos = tkBD:GetBonePosition( 0 )
	        			local bdPos = ( rootPos - self:GetUp() * ( self:WorldSpaceCenter():Distance( self:GetPos() ) ) )

			        	trTbl.start = rootPos
			        	trTbl.endpos = bdPos
			        	trTbl.mins = self:OBBMins()
			        	trTbl.maxs = self:OBBMaxs()

			        	trTbl.filter[ 1 ] = self
			        	trTbl.filter[ 2 ] = tkNPC
			        	trTbl.filter[ 3 ] = tkBD
			        	trTbl.filter[ 4 ] = target

			        	self:SetPos( TraceHull( trTbl ).HitPos )
			        	if CurTime() > finishTime then return true end
			        end, true )
	        	end
	        end

	        if isVictim then
		        if random( 1, 100 ) <= self:GetVoiceChance() then
		            self:SimpleTimer( Rand( 0.33, 1.0 ), function() self:PlaySoundFile( self:GetVoiceLine( "panic" ), true ) end )
		        end

		        for _, v in ipairs( GetLambdaPlayers() ) do
		        	if v:GetState() != "Combat" or v:GetEnemy() != self then continue end
		        	v:SetState( "Idle" )
		        	v:SetEnemy( NULL )
		        	v:CancelMovement()
		        end
	        elseif tkNPC then
	        	local target = self.TakedowningTarget
		        local finishTime = CurTime() + tkNPC.Delay
		        
		        self:NamedTimer( "MWIITakedown_Finish", 0, 0, function()
        			if self:GetIsDead() then return true end

		        	local targetDead = ( !self.TakedownIsFinished and IsValid( target ) and ( target.IsLambdaPlayer and target:GetIsDead() or target:IsPlayer() and !target:Alive() ) )
		        	if !targetDead and CurTime() <= finishTime then return end
		        	if targetDead and CurTime() <= finishTime then tkNPC:Finish() end

    				self.l_isfrozen = false
		            self:ClientSideNoDraw( self, false )

		            self.Takedowning = false
		            self.TakedowningTarget = nil

		            local wepNoDraw = self:IsWeaponMarkedNodraw()
		            self:ClientSideNoDraw( self.WeaponEnt, wepNoDraw )
			        self.WeaponEnt:SetNoDraw( wepNoDraw )
			        self.WeaponEnt:DrawShadow( !wepNoDraw )

			        return true
		        end )
	        end

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
		    	OnLambdaTakedown( target, true )
	        end
		end

		local function PreLambdaOnKilled( self, dmginfo )
			if self.Takedowning then 
	        	self.l_isfrozen = false
				if CurTime() <= self.TakedownTime and IsValid( self.TakedownNPC ) then self.TakedownNPC:Finish() end
				self:DrawShadow( false )
			end
			self:l_Takedowns_OldLambdaOnKilled( dmginfo )
		end

		local function LambdaBlankFunction( self ) end

		local function OnInitialize( self )
			self.l_Takedowns_OldLambdaOnKilled = self.LambdaOnKilled
			self.LambdaOnKilled = PreLambdaOnKilled

			self.Takedowning = false
			self.TakedownNPC = NULL
			self.TakedowningTarget = NULL
			self.TakedownTime = CurTime()
			self.l_TakedownCheckTime = CurTime() + Rand( 0.1, 0.25 )
			
			self.GetActiveWeapon = LambdaBlankFunction
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
	        	if LambdaIsValid( ene ) and !ene.Takedowning and ene:Health() > 0 and ( ene:IsPlayer() and ene:Alive() and !ene:HasGodMode() and takedownPlayers:GetBool() or ( ene:IsNPC() or ene:IsNextBot() ) and ( takedownAllNPCs:GetBool() or table_HasValue( takedownedNPCsClassList, ene:GetClass() ) ) ) then
			        local IsDowned = ene:IsDowned()
			        local downBehav = downedBehavior:GetInt()

			        if downBehav == 0 or IsDowned and downBehav != 2 then
				        local isBehind = LambdaIsAtBack( self, ene )
				        if CurTime() > self.l_TakedownCheckTime and ( isBehind and self:IsInRange( ene, 70 ) or IsDowned and self:IsInRange( ene, 32 ) ) then
				        	self:NPC_Takedown( ene )
				        elseif IsDowned or isBehind and ( ene:IsPlayer() and self:IsInRange( ene, 325 ) or ene.IsLambdaPlayer and ( ene:GetState() != "Combat" or ene:GetEnemy() != self ) or ene:IsNPC() and ene.GetEnemy and ene:GetEnemy() != self ) then
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

	       	if CurTime() > self.l_TakedownCheckTime then
	        	self.l_TakedownCheckTime = CurTime() + Rand( 0.1, 0.25 )
	        end
		end

		local function OnCanTarget( self, target )
			if target.Takedowning and !IsValid( target.TakedowningTarget ) then return true end
		end

		local function OnKilled( self, dmginfo )
        	self.l_isfrozen = false

			local target = self.TakedowningTarget
			if IsValid( target ) and target.IsLambdaPlayer then 
        		target.l_isfrozen = false
	            
				target.Takedowning = false
				target.TakedownNPC = NULL
				target.TakedowningTarget = NULL
				target.TakedownTime = CurTime()

				if !target:GetIsDead() then
					if dmginfo:GetAttacker() != self and dmginfo:GetAttacker() != target then
					    if self.AddFriend and random( 1, 100 ) <= 25 then
					        self:AddFriend( dmginfo:GetAttacker() )
					    end

						if random( 1, 100 ) <= self:GetVoiceChance() then
							target:PlaySoundFile( target:GetVoiceLine( "assist" ), true )
						end
					end

					target:ClientSideNoDraw( target, false )
				    
				    local wepNoDraw = target:IsWeaponMarkedNodraw()
			        target:ClientSideNoDraw( target.WeaponEnt, wepNoDraw )
			        target.WeaponEnt:SetNoDraw( wepNoDraw )
			        target.WeaponEnt:DrawShadow( !wepNoDraw )
			    end
			end

			self.Takedowning = false
			self.TakedownNPC = NULL
			self.TakedowningTarget = NULL
			self.TakedownTime = CurTime()
			
			self:SetNWBool( "HeadBlowMWII", false )
		end

		hook.Add( "LambdaOnInitialize", hookName .. "OnInitialize", OnInitialize )
		hook.Add( "LambdaOnThink", hookName .. "OnThink", OnThink )
		hook.Add( "LambdaCanTarget", hookName .. "OnCanTarget", OnCanTarget )
		hook.Add( "LambdaOnKilled", hookName .. "OnKilled", OnKilled )

	end
end

hook.Add( "InitPostEntity", hookName .. "InitializeModule", InitializeModule )