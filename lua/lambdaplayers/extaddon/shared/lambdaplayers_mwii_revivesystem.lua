if !file.Exists( "autorun/sh_mwii_survivor.lua", "LUA" ) and !file.Exists( "autorun/sh_mw3_survivor.lua", "LUA" ) then return end
local hookName = "LambdaMWII_ReviveSystem_"

local enableDowning 		= CreateLambdaConvar( "lambdaplayers_mwii_revivesystem_enabledowning", 1, true, false, false, "If Lambda Players can be downed if they reach zero health", 0, 1, { type = "Bool", name = "Enable Downing", category = "MWII - Revive System" } )
local downChance 			= CreateLambdaConvar( "lambdaplayers_mwii_revivesystem_downchance", 100, true, false, false, "The chance a Lambda Player will get downed instead of dying", 0, 100, { type = "Slider", decimals = 0, name = "Chance To Be Downed", category = "MWII - Revive System" } )
local downedOnce 			= CreateLambdaConvar( "lambdaplayers_mwii_revivesystem_downedonce", 1, true, false, false, "If Lambda Players can be downed only one time", 0, 1, { type = "Bool", name = "Downed Only Once", category = "MWII - Revive System" } )
local enableReviving 		= CreateLambdaConvar( "lambdaplayers_mwii_revivesystem_enablereviving", 1, true, false, false, "If Lambda Players can revive downed players other Lambda Players if they're friends or are in the same team", 0, 1, { type = "Bool", name = "Enable Reviving", category = "MWII - Revive System" } )
local enableSelfReviving 	= CreateLambdaConvar( "lambdaplayers_mwii_revivesystem_enableselfreviving", 1, true, false, false, "If Lambda Players can self-revive themself if they are in safe position", 0, 1, { type = "Bool", name = "Enable Self-Reviving", category = "MWII - Revive System" } )
local enableWeapons 		= CreateLambdaConvar( "lambdaplayers_mwii_revivesystem_enableweapons", 1, true, false, false, "If Lambda Players can use and attack with their weapons when downed", 0, 1, { type = "Bool", name = "Enable Weapon Usage", category = "MWII - Revive System" } )
local useSpecifiedWeapon 	= CreateLambdaConvar( "lambdaplayers_mwii_revivesystem_usespecificweapon", 1, true, false, false, "If Lambda Player should only use weapon specified in the Downed Weapon option if weapon usage is allowed", 0, 1, { type = "Bool", name = "Use Specific Weapon Only", category = "MWII - Revive System" } )
local forcedWeapon 			= CreateLambdaConvar( "lambdaplayers_mwii_revivesystem_forceweapon", "pistol", true, false, false, "The weapon Lambda Player will be forced to use when currenly downed. 'Use Specific Weapon Only' should be enabled to work", 0, 1, { type = "Combo", options = _LAMBDAWEAPONCLASSANDPRINTS, name = "Downed Weapon", category = "MWII - Revive System" } )
local plysCanRevive 		= CreateLambdaConvar( "lambdaplayers_mwii_revivesystem_playerscanrevive", 1, true, false, false, "If real players can revive downed Lambda Players", 0, 1, { type = "Bool", name = "Players Can Revive Lambdas", category = "MWII - Revive System" } )
local ignoreDowned 			= CreateLambdaConvar( "lambdaplayers_mwii_revivesystem_ignoredownedenemies", 0, true, false, false, "If Lambda Players should ignore enemies that are currenly downed", 0, 1, { type = "Bool", name = "Ignore Downed Enemies", category = "MWII - Revive System" } )
local bystandersRevive 		= CreateLambdaConvar( "lambdaplayers_mwii_revivesystem_bystandersrevive", 1, true, false, false, "If Lambda Players that are not friends or teammates with their revive target but are not aggresive in their personality can still revive them", 0, 1, { type = "Bool", name = "Friendly Bystanders Can Revive", category = "MWII - Revive System" } )

local function InitializeModule()
	LambdaMWII_ReviveSystemInitialized = true

	local IsValid = IsValid
	local ipairs = ipairs
	local FrameTime = FrameTime
	local GetConVar = GetConVar
	local reviveEnemies

	if ( CLIENT ) then

		local LocalPlayer = LocalPlayer
		local surface = surface
		local ScrW = ScrW
		local ScrH = ScrH
		local SimpleText = draw.SimpleText
		local min = math.min
		local TraceLine = util.TraceLine
		local iconTrTbl = { filter = function( ent ) if ent:IsWorld() then return true end end }
		local headOffset = Vector( 0, 0, 20 )
		local table_Copy = table.Copy
		local table_ClearKeys = table.ClearKeys

	    local rev_mat = Material( "tdmg/hud/revive.png" )
	    local blood_mat = Material( "tdmg/hud/bloodoverlay.png" )
	    local color_grey1 = Color( 220, 220, 220 )
	    local color_grey2 = Color( 40, 40, 40, 150 )

	    local reviceIcon = GetConVar( "mwii_revive_icon_enable" )

		local function OnHUDPaint()
			if !plysCanRevive:GetBool() then return end

			local ply = LocalPlayer()
			local plyEye = ply:EyePos()
			
			reviveEnemies = reviveEnemies or GetConVar( "mwii_revive_enemy" )
			local revEnemies = reviveEnemies:GetBool()

			if reviceIcon:GetBool() then
		        for _, ent in ipairs( GetLambdaPlayers() ) do
		            if !ent:IsBeingDrawn() or ent:GetIsDead() or !ent:GetNWBool( "Downed" ) then continue end
		            if !revEnemies and LambdaTeams and LambdaTeams:AreTeammates( ply, ent ) == false then continue end

		            local iconPos = ent:WorldSpaceCenter()
		            local headBone = ent:LookupBone( "ValveBiped.Bip01_Head1" )
		            if headBone then iconPos = ent:GetBonePosition( ent:LookupBone( "ValveBiped.Bip01_Head1" ) ) + headOffset end

		            iconTrTbl.start = plyEye
		            iconTrTbl.endpos = iconPos
		            if TraceLine( iconTrTbl ).Hit then continue end

		            iconPos = iconPos:ToScreen()
	                surface.SetDrawColor( 255, 255, 255 )
	                surface.SetMaterial( rev_mat )
	                surface.DrawTexturedRect( iconPos.x - 16, iconPos.y - 16, 32, 32 )
		        end
		    end
			
	    	if !ply:Alive() or ply:IsDowned() then return end

	        local tr = ply:GetEyeTrace()
	        local ent = tr.Entity
	        local w, h = ( ScrW() / 2 ), ( ScrH() / 2 )

	        if LambdaIsValid( ent ) and ent.IsLambdaPlayer and ent:GetNWBool( "Downed" ) and ply:EyePos():DistToSqr( tr.HitPos ) < 5000 and ( revEnemies or LambdaTeams and LambdaTeams:AreTeammates( ply, ent ) != false ) then
	            if ply:KeyDown( IN_USE ) then
	                SimpleText( "Revive Progress", "TDMG_SmallFont1", w, h + 100, color_grey1, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM )
	                
	                surface.SetDrawColor( color_grey2 )
	                surface.DrawRect( w - 100, h + 110, 200, 24 )

	                local reviveProgress = ent:GetNW2Float( "lambdamwii_reviveprogress", 0 )
	                surface.SetDrawColor(color_grey1)
	                surface.DrawRect( w - 98, h + 112, 196 * ( min( reviveProgress, 1 ) / 1 ), 20 )
	            else
	                SimpleText( "Press E to revive", "TDMG_SmallFont1", w, h + 115, color_grey1, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM )
	            end
	        end
		end

		hook.Add( "HUDPaint", hookName .. "OnHUDPaint", OnHUDPaint )

	end

	if ( SERVER ) then

		local random = math.random
		local Rand = math.Rand
		local min = math.min
		local table_Empty = table.Empty
		local player_GetAll = player.GetAll
		local GetLambdaPlayers = GetLambdaPlayers
		local ignorePlys = GetConVar( "ai_ignoreplayers" )

		local plyMeta = FindMetaTable( "Player" )
		local GetMovingDirection = plyMeta.MovingDirection

		local reviveHealth = GetConVar( "mwii_revive_health" )
		local reviveTime = GetConVar( "mwii_revive_time" )
		local reviveHPTimer = GetConVar( "mwii_revive_hptimer" )
		local physUpdateTime = GetConVar( "lambdaplayers_lambda_physupdatetime" )

		local downedCollMins = Vector( -26, -16, 0 )
		local downedCollMaxs = Vector( 38, 16, 24 )

		local function OnServerThink()
			if plysCanRevive:GetBool() then
				reviveEnemies = reviveEnemies or GetConVar( "mwii_revive_enemy" )
				local revEnemies = reviveEnemies:GetBool()

				for _, ply in ipairs( player_GetAll() ) do
					if !ply:Alive() or ply:IsDowned() or !ply:KeyDown( IN_USE ) then continue end

					local tr = ply:GetEyeTrace()
					local ent = tr.Entity

					if LambdaIsValid( ent ) and ent.IsLambdaPlayer and ent:IsDowned() and ply:EyePos():DistToSqr( tr.HitPos ) < 5000 and ( revEnemies or LambdaTeams and LambdaTeams:AreTeammates( ply, ent ) != false ) then
						ent:SetNWEntity( "Reviver", ply )
						ent.l_DownedReviver = ply
						ply.RevivingThatEntity = ent
					end
				end
			end

			for _, ply in ipairs( GetLambdaPlayers() ) do
		        if ply:GetIsDead() or !ply:IsDowned() then continue end
		        local reviver = ply.l_DownedReviver

	        	if LambdaIsValid( reviver ) then
					if !ply.Takedowning and ( !reviver:IsPlayer() or reviver:KeyDown( IN_USE ) and reviver:GetEyeTrace().Entity == ply ) then
	                    if reviver:IsPlayer() then
	                        reviver:SetActiveWeapon(nil)
	                        
	                        if !reviver.RevivingTarget then
	                            reviver:SetSVAnimation( "laststand_startrevive" )
	                            reviver.RevivingTarget = true
	                        end
	                    end

					    ply.l_moveWaitTime = CurTime() + 0.1
	                    ply:SetNW2Float( "lambdamwii_reviveprogress", ply:GetNW2Float( "lambdamwii_reviveprogress", 0 ) + ( FrameTime() / 3 ) )
	                else
	                    if reviver:IsPlayer() and reviver.RevivingTarget then
	                        if !reviver.Takedowning then reviver:SetSVAnimation( "" ) end
	                        reviver.RevivingTarget = false
	                    end
	                   	
						reviver = NULL
						ply.l_DownedReviver = reviver
						ply:SetNWEntity( "Reviver", reviver )
					end
				end

	    		if ply.l_IsSelfReviving then
	                ply:SetNW2Float( "lambdamwii_reviveprogress", ply:GetNW2Float( "lambdamwii_reviveprogress", 0 ) + ( FrameTime() / 5.5 ) )
	        	elseif !LambdaIsValid( reviver ) then
	                ply:SetNW2Float( "lambdamwii_reviveprogress", 0 )
	        	end

	        	if ply:GetNW2Float( "lambdamwii_reviveprogress", 0 ) >= 1.0 then
					ply:SetHealth( 25 )

			        ply:SetRunSpeed( ply.l_PreDownedData[ "RunSpeed" ] )
			        ply:SetWalkSpeed( ply.l_PreDownedData[ "WalkSpeed" ] )
			        ply:SetCrouchSpeed( ply.l_PreDownedData[ "CrouchSpeed" ] )

					ply.Downed = false
					ply:SetNWBool( "Downed", false )
				    
				    table_Empty( ply.l_PreDownedData )

					local standTime = ply:SetSequence( ply:LookupSequence( "laststand_standup" ) )
					ply:ResetSequenceInfo()
					ply:SetCycle( 0 )

		    		ply:CancelMovement()
					ply.l_moveWaitTime = CurTime() + standTime
					ply:SimpleTimer( standTime, function() ply.l_UpdateAnimations = true end )

					ply:SwitchWeapon( "none" )
					local wepDelay = Rand( 0.33, 0.8 )
					local curCooldown = ply.l_WeaponUseCooldown
					ply.l_WeaponUseCooldown = ( CurTime() <= curCooldown and curCooldown + wepDelay or CurTime() + wepDelay )
		            
		            if LambdaIsValid( reviver ) then
		            	if ply.AddFriend and random( 3 ) != 1 then ply:AddFriend( reviver ) end

		            	if reviver:IsPlayer() then
		                    reviver:SetSVAnimation( "" )
		                    reviver.RevivingTarget = false
		                end

						ply:LookTo( reviver, 1.0 )
						ply:SimpleTimer( ( standTime / random( 4 ) ), function() ply:PlaySoundFile( ply:GetVoiceLine( "assist" ) ) end )
		            end

		            ply.l_DownedReviver = NULL
					ply:SetNWEntity( "Reviver", NULL )
				end
			end
		end

		hook.Add( "Think", hookName .. "OnServerThink", OnServerThink )

		-- HACK: Since revive system uses eye traces to check reviver is looking at its target,
		-- Override the return trace table with our own
		local eyeTrTbl = { Entity = NULL }
		local function OnGetEyeTrace( self )
			if self:GetState() == "ReviveFriend" and LambdaIsValid( self.l_ReviveTarget ) and self:IsInRange( self.l_ReviveTarget, 40 ) then 
				eyeTrTbl.Entity = self.l_ReviveTarget
				return eyeTrTbl
			end
			return self:l_ReviveSystem_OldGetEyeTrace()
		end

		-- HACK: Don't play taunts if we are currenly downed
		local function OnPlayGestureAndWait( self, id, speed )
			if self:IsDowned() then return end
			self:l_ReviveSystem_OldPlayGestureAndWait( id, speed )
		end

		local reviveTbl = { run = true, tol = 40 }
		local function LambdaReviveFriend( self )
			local revTarget = self.l_ReviveTarget
			if !LambdaIsValid( revTarget ) or revTarget.Takedowning or !revTarget:IsDowned() then
				self:SetState( "Idle" )
				return
			end

			local reviver = revTarget.l_DownedReviver
			if LambdaIsValid( reviver ) and reviver != self then
				self:SetState( "Idle" )
				return
			end

			if self:IsInRange( revTarget, 40 ) and self:CanSee( revTarget ) then
				self.l_UpdateAnimations = false
				revTarget.l_DownedReviver = self
				revTarget:SetNWEntity( "Reviver", self )

				self:SetSequence( self:LookupSequence( "laststand_startrevive" ) )
				self:ResetSequenceInfo()
				self:SetCycle( 0 )
				
				while ( LambdaIsValid( self.l_ReviveTarget ) and self.l_ReviveTarget:GetNW2Float( "lambdamwii_reviveprogress", 0 ) < 1.0 ) do
					if self.Takedowning or self:IsDowned() or self:GetState() != "ReviveFriend" and !self:InCombat() then break end
					if self:InCombat() and self:GetEnemy().GetEnemy and self:GetEnemy():GetEnemy() == self and self:CanSee( self:GetEnemy() ) then break end
					
					revTarget = self.l_ReviveTarget
					if revTarget.Takedowning or !revTarget:IsDowned() or !self:IsInRange( revTarget, 40 ) or revTarget.l_DownedReviver != self then break end
					
					self:LookTo( self.l_ReviveTarget:WorldSpaceCenter(), 1.0 )
					coroutine.yield()
				end

				self.l_UpdateAnimations = true
				if self:GetState() == "ReviveFriend" then self:SetState( "Idle" ) end
				if IsValid( self.l_ReviveTarget ) then 
					self.l_ReviveTarget.l_DownedReviver = NULL
					self.l_ReviveTarget:SetNWEntity( "Reviver", NULL ) 
				end

				return
			end

			self:MoveToPos( revTarget, reviveTbl )
		end

		local function LambdaBlankFunction( self ) end
		local function LambdaBlankReturnTrueFunction( self ) return true end
		local function LambdaBlankReturnFalseFunction( self ) return false end

		local function OnInitialize( self )
			self.l_ReviveSystem_OldGetEyeTrace = self.GetEyeTrace
			self.GetEyeTrace = OnGetEyeTrace

			self.l_ReviveSystem_OldPlayGestureAndWait = self.PlayGestureAndWait
			self.PlayGestureAndWait = OnPlayGestureAndWait

			self.ReviveFriend = LambdaReviveFriend

			self.SetSVAnimation = LambdaBlankFunction
			self.GetActiveWeapon = LambdaBlankFunction
			self.SetActiveWeapon = LambdaBlankFunction
			self.KeyDown = LambdaBlankReturnTrueFunction

			self.l_Downer = NULL
			self.l_IsSelfReviving = false
			self.AlreadyWasDowned = false
			self.l_UpdateDownedAnimations = true
			self.DownedTime = CurTime()
			self.DownedEnt = self
			self.l_ReviveTarget = NULL
			self.l_DownedReviver = NULL
			self.Reviving = true
			self.NextHPTimePain = CurTime()
			self.l_ReviveTargetsCheckTime = CurTime() + 1.0
			self.l_PreDownedData = {}
			self:SetNW2Float( "lambdamwii_reviveprogress", 0 )
		end

		local function OnThink( self, wepent, dead )
	        if dead then return end
			
			if self.l_PrevAttackDistance then
	            self.l_CombatAttackRange = self.l_PrevAttackDistance
	            self.l_PrevAttackDistance = nil
	        end

	        if self:IsDowned() then
	        	local reviver = self.l_DownedReviver
	        	if !LambdaIsValid( reviver ) then 
	        		local ene = self:GetEnemy()
					local canSelfRevive = ( enableSelfReviving:GetBool() and self.l_UpdateDownedAnimations and !self.Takedowning and ( !self:InCombat() or ene.IsLambdaPlayer and ( !ene:InCombat() or ene:GetEnemy() != self ) or !self:IsInRange( ene, 1000 ) or !self:CanSee( ene ) ) and ( !self:IsPanicking() or !LambdaIsValid( self.l_RetreatTarget ) or !self:IsInRange( self.l_RetreatTarget, 1000 ) and !self:CanSee( self.l_RetreatTarget ) ) )
	        		if !self.l_IsSelfReviving then self.l_IsSelfReviving = ( random( 100 ) == 1 and canSelfRevive ) end

	        		if self.l_IsSelfReviving and canSelfRevive then
					    self.l_moveWaitTime = CurTime() + 0.1
		                self.l_PrevAttackDistance = self.l_CombatAttackRange
		                self.l_CombatAttackRange = 0
		        	elseif self.l_IsSelfReviving then 
		        		self.l_IsSelfReviving = false
		        		if self:InCombat() and !self:HasLethalWeapon() then
		        			self:SwitchToLethalWeapon()
		        		end
		        	end

					if !reviveHPTimer:GetBool() then
						if !self.l_IsSelfReviving and CurTime() > self.DownedTime then
							self:Kill()
						end
					elseif CurTime() > self.NextHPTimePain and reviveHPTimer:GetBool() then
	                    self.NextHPTimePain = CurTime() + 1
	                    self:TakeDamage( reviveHealth:GetInt() / reviveTime:GetFloat() )
	                end
	        	end

	            if self:GetNW2Float( "lambdamwii_reviveprogress", 0 ) < 1 then
	            	local forceWep = forcedWeapon:GetString()
	            	if self.l_IsSelfReviving or !enableWeapons:GetBool() or useSpecifiedWeapon:GetBool() and self.l_Weapon != forceWep and !self:CanEquipWeapon( forceWep ) then
	            		if self.l_Weapon != "none" and self.l_Weapon != "physgun" then
							self:SwitchWeapon( "none" )
						end
					elseif useSpecifiedWeapon:GetBool() and self.l_Weapon != forceWep and self:CanEquipWeapon( forceWep ) then
						self:SwitchWeapon( forceWep )
					end

	        		if CurTime() > self.l_nextphysicsupdate then
		                local phys = self:GetPhysicsObject()
		                if self:WaterLevel() == 0 then
		                    phys:SetPos( self:GetPos() )
		                    phys:SetAngles( self:GetAngles() )
		                else
		                    phys:UpdateShadow( self:GetPos(), self:GetAngles(), 0 )
		                end

		                self:SetCollisionBounds( downedCollMins, downedCollMaxs )
	        			self.l_nextphysicsupdate = ( CurTime() + physUpdateTime:GetFloat() )
	        		end

		        	if self.l_UpdateDownedAnimations then
			        	local downAnim = "laststand_idle"

						if self.l_IsSelfReviving then
			        		downAnim = "laststand_selfrevive"
			        	else
							if self:IsOnGround() and !self.loco:GetVelocity():IsZero() then downAnim = "laststand_crawl_" .. GetMovingDirection( self ) end

							local hType = self.l_HoldType
							if hType != "normal" and hType != "passive" and hType != "fist" then downAnim = downAnim .. "_wep" end
			        	end

						downAnim = self:LookupSequence( downAnim )
						if self:GetSequence() != downAnim or self:IsSequenceFinished() then
							self:ResetSequenceInfo()
							self:SetCycle( 0 )
						end
						self:SetSequence( downAnim )
					end
				end
	        elseif CurTime() > self.l_ReviveTargetsCheckTime then 
	    		local ene = self:GetEnemy()

	    		if ( !self:InCombat() or random( 3 ) == 1 and !self:CanSee( ene ) or ene.IsLambdaPlayer and ( !ene:InCombat() or ene:GetEnemy() != self ) or ene.GetEnemy and ene:GetEnemy() != self ) and !self:IsPanicking() and self:GetState() != "ReviveFriend" and enableReviving:GetBool() then
	        		local canRescueNeutrals = ( bystandersRevive:GetBool() and self:GetState() != "FindTarget" and random( 100 ) > self:GetCombatChance() and random( 2 ) == 1 )
	        		local revTarget = self:GetClosestEntity( nil, 2000, function( ent )
	        			if ( !ent.IsLambdaPlayer or ent:GetIsDead() ) and ( !ent:IsPlayer() or !ent:Alive() or ignorePlys:GetBool() ) or ent.Takedowning or !ent:IsDowned() or LambdaIsValid( ent.l_DownedReviver or ent:GetNWEntity( "Reviver" ) ) or !self:CanSee( ent ) then return false end
	        			if canRescueNeutrals and ent.l_Downer != self and ( !LambdaTeams or LambdaTeams:AreTeammates( self, ent ) == nil ) and ( !self.IsFriendsWith or !self:IsFriendsWith( ent ) ) then return true end
	    				if LambdaTeams and LambdaTeams:AreTeammates( self, ent ) then return true end
	        			if self.IsFriendsWith and self:IsFriendsWith( ent ) then return true end
	        		end )

	        		if IsValid( revTarget ) then
	        			if !self:InCombat() and random( 100 ) <= self:GetVoiceChance() then
	        				self:PlaySoundFile( self:GetVoiceLine( "witness" ) )
	        			end

	        			self.l_ReviveTarget = revTarget
	        			self:SetState( "ReviveFriend" )
	        			self:CancelMovement()
	        		end
	        	end

	    		self.l_ReviveTargetsCheckTime = CurTime() + 1.0
	        end
		end

		-- If Friends or Team module is installed, go to one of my teammates so that they can revive us
		local function OnBeginMove( self, movePos, onNavmesh )
			if self:IsDowned() then
				local teammates = self:FindInSphere( nil, 1500, function( ent )
	    			if ( !ent.IsLambdaPlayer or ent:GetIsDead() ) and ( !ent:IsPlayer() or !ent:Alive() or ignorePlys:GetBool() ) or ent.Takedowning or ent:IsDowned() then return false end
	    			if LambdaTeams and LambdaTeams:AreTeammates( self, ent ) then return true end
	    			if self.IsFriendsWith and self:IsFriendsWith( ent ) then return true end
				end )
				if #teammates > 0 then
					self:RecomputePath( teammates[ random( #teammates ) ] )
				end
			end
		end

		-- Don't produce footsteps while downed
		local function OnFootStep( self, pos, matType )
			if self:IsDowned() then return true end
		end

		-- Can't jump while downed
		local function OnJump( self )
			if self:IsDowned() then return true end
		end

		local function OnCanTarget( self, target )
			if target:IsDowned() and ignoreDowned:GetBool() then return true end
			if self:IsDowned() and ( target.IsLambdaPlayer and target.l_ReviveTarget == self or !self:HasLethalWeapon() ) then return true end
		end

		-- Don't  switchweapons if we are downed and either we are dissallowed to or if are restricted to specific weapon
		local function OnCanSwitchWeapon( self, wepName, wepTbl )
			if self:IsDowned() and wepName != "none" and wepName != "physgun" then 
				if self.l_IsSelfReviving or !enableWeapons:GetBool() or useSpecifiedWeapon:GetBool() and forcedWeapon:GetString() != wepName then 
					return true 
				end
			end
		end

		local function OnPreKilled( self, dmginfo, silent )
			if silent or self:IsDowned() or self.Takedowning or self.AlreadyWasDowned and downedOnce:GetBool() or dmginfo:IsExplosionDamage() or !enableDowning:GetBool() or random( 100 ) > downChance:GetInt() then return end

			self:SetHealth( reviveHealth:GetInt() )
			self:GodEnable()
			self:SimpleTimer( 0.5, function() self:GodDisable() end, true )

			self.l_PreDownedData[ "RunSpeed" ] = self:GetRunSpeed()
			self.l_PreDownedData[ "WalkSpeed" ] = self:GetWalkSpeed()
			self.l_PreDownedData[ "CrouchSpeed" ] = self:GetCrouchSpeed()

			self:CancelMovement()
			self:SetRunSpeed( 25 )
			self:SetCrouchSpeed( 25 )
			self:SetWalkSpeed( 25 )

			local wepDelay = Rand( 0.33, 0.8 )
			local curCooldown = self.l_WeaponUseCooldown
			self.l_WeaponUseCooldown = ( CurTime() <= curCooldown and curCooldown + wepDelay or CurTime() + wepDelay )

			self:RemoveAllGestures()
			self.l_UpdateAnimations = false
			
			local fallTime = self:SetSequence( self:LookupSequence( "laststand_down" ) )
			self:ResetSequenceInfo()
			self:SetCycle( 0 )
			
			self.l_moveWaitTime = CurTime() + fallTime

			self.l_UpdateDownedAnimations = false
			self:SimpleTimer( fallTime, function() self.l_UpdateDownedAnimations = true end )

			local attacker = dmginfo:GetAttacker()
			local useWeapons = enableWeapons:GetBool()

			if self:GetIsReloading() and useWeapons and useSpecifiedWeapon:GetBool() then
				self:RemoveNamedTimer( "Reload" )
				self.l_Clip = self.l_MaxClip
				self:SetIsReloading( false )
			end

			self:SimpleTimer( fallTime / random( 4 ), function() 
				if self:IsPanicking() then return end

				if !useWeapons then self:RetreatFrom( attacker, 30 ) end
				self:PlaySoundFile( self:GetVoiceLine( "panic" ) ) 
			end )

			if ignoreDowned:GetBool() then
				if LambdaIsValid( attacker ) and attacker.IsLambdaPlayer and attacker:InCombat() and attacker:GetEnemy() == self then
					attacker:OnOtherKilled( self, dmginfo )
				end
				
				for _, v in ipairs( GetLambdaPlayers() ) do
					if v != self and v != attacker and v:InCombat() and v:GetEnemy() == self then
						v:SetState( "Idle" )
						v:SetEnemy( NULL )
						v:CancelMovement()
					end
				end
			end

			self.Downed = true
			self.AlreadyWasDowned = true
			self.l_Downer = dmginfo:GetAttacker()
			self.NextHPTimePain = CurTime() + 1.0
			self.DownedTime = CurTime() + reviveTime:GetFloat()
			
			self:SetNWBool( "Downed", true )
			self:SetNW2Float( "lambdamwii_reviveprogress", 0 )

			return true
		end

		local function OnKilled( self, dmginfo )
	        self.AlreadyWasDowned = false
			if !self:IsDowned() then return end

	        self:SetRunSpeed( self.l_PreDownedData[ "RunSpeed" ] )
	        self:SetWalkSpeed( self.l_PreDownedData[ "WalkSpeed" ] )
	        self:SetCrouchSpeed( self.l_PreDownedData[ "CrouchSpeed" ] )

			self.Downed = false
			self:SetNWBool( "Downed", false )

		    table_Empty( self.l_PreDownedData )
		end

		-- Prevents Lambdas from spawning healthkits and armor to heal themselves
		local function OnChangeState( self, oldState, newState )
			if self:IsDowned() and ( newState == "HealUp" or newState == "ArmorUp" ) then return true end
		end

		hook.Add( "LambdaOnInitialize", hookName .. "OnInitialize", OnInitialize )
		hook.Add( "LambdaOnThink", hookName .. "OnThink", OnThink )
		hook.Add( "LambdaOnBeginMove", hookName .. "OnBeginMove", OnBeginMove )
		hook.Add( "LambdaFootStep", hookName .. "OnFootStep", OnFootStep )
		hook.Add( "LambdaOnJump", hookName .. "OnJump", OnJump )
		hook.Add( "LambdaCanTarget", hookName .. "OnCanTarget", OnCanTarget )
		hook.Add( "LambdaCanSwitchWeapon", hookName .. "CanSwitchWeapon", OnCanSwitchWeapon )
		hook.Add( "LambdaOnPreKilled", hookName .. "OnPreKilled", OnPreKilled )
		hook.Add( "LambdaOnKilled", hookName .. "OnKilled", OnKilled )
		hook.Add( "LambdaOnChangeState", hookName .. "OnChangeState", OnChangeState )

	end
end

hook.Add( "InitPostEntity", hookName .. "InitializeModule", InitializeModule )
if LambdaMWII_ReviveSystemInitialized then InitializeModule() end