local hookName = "Lambda_MWII_ReviveSystem_"

local enableDowning = CreateLambdaConvar( "lambdaplayers_mwii_revivesystem_enabledowning", 1, true, false, false, "If Lambda Players can be downed if they reach zero health", 0, 1, { type = "Bool", name = "Enable Downing", category = "MWII - Revive System" } )
local downChance = CreateLambdaConvar( "lambdaplayers_mwii_revivesystem_downchance", 100, true, false, false, "The chance a Lambda Player will get downed instead of dying", 0, 100, { type = "Slider", decimals = 0, name = "Chance To Be Downed", category = "MWII - Revive System" } )
local downedOnce = CreateLambdaConvar( "lambdaplayers_mwii_revivesystem_downedonce", 1, true, false, false, "If Lambda Players can be downed only one time", 0, 1, { type = "Bool", name = "Downed Only Once", category = "MWII - Revive System" } )
local enableReviving = CreateLambdaConvar( "lambdaplayers_mwii_revivesystem_enablereviving", 1, true, false, false, "If Lambda Players can revive downed players other Lambda Players if they're friends or are in the same team", 0, 1, { type = "Bool", name = "Enable Reviving", category = "MWII - Revive System" } )
local enableSelfReviving = CreateLambdaConvar( "lambdaplayers_mwii_revivesystem_enableselfreviving", 1, true, false, false, "If Lambda Players can self-revive themself if they are in safe position", 0, 1, { type = "Bool", name = "Enable Self-Reviving", category = "MWII - Revive System" } )
local enableWeapons = CreateLambdaConvar( "lambdaplayers_mwii_revivesystem_enableweapons", 1, true, false, false, "If Lambda Players can use and attack with their weapons when downed", 0, 1, { type = "Bool", name = "Enable Weapon Usage", category = "MWII - Revive System" } )
local useSpecifiedWeapon = CreateLambdaConvar( "lambdaplayers_mwii_revivesystem_usespecificweapon", 1, true, false, false, "If Lambda Player should only use weapon specified in the Downed Weapon option if weapon usage is allowed", 0, 1, { type = "Bool", name = "Use Specific Weapon Only", category = "MWII - Revive System" } )
local forcedWeapon = CreateLambdaConvar( "lambdaplayers_mwii_revivesystem_forceweapon", "pistol", true, false, false, "The weapon Lambda Player will be forced to use when currenly downed. 'Use Specific Weapon Only' should be enabled to work", 0, 1, { type = "Combo", options = _LAMBDAWEAPONCLASSANDPRINTS, name = "Downed Weapon", category = "MWII - Revive System" } )
local plysCanRevive = CreateLambdaConvar( "lambdaplayers_mwii_revivesystem_playerscanrevive", 1, true, false, false, "If real players can revive downed Lambda Players", 0, 1, { type = "Bool", name = "Players Can Revive Lambdas", category = "MWII - Revive System" } )
local ignoreDowned = CreateLambdaConvar( "lambdaplayers_mwii_revivesystem_ignoredownedenemies", 0, true, false, false, "If Lambda Players should ignore enemies that are currenly downed", 0, 1, { type = "Bool", name = "Ignore Downed Enemies", category = "MWII - Revive System" } )
local bystandersRevive = CreateLambdaConvar( "lambdaplayers_mwii_revivesystem_bystandersrevive", 1, true, false, false, "If Lambda Players that are not friends or teammates with their revive target but are not aggresive in their personality can still revive them", 0, 1, { type = "Bool", name = "Friendly Bystanders Can Revive", category = "MWII - Revive System" } )

local function InitializeModule()
	if !istable( COD ) then return end

	local IsValid = IsValid
	local ipairs = ipairs
	local FrameTime = FrameTime

	local reviveEnemies = GetConVar( "mwii_revive_enemy" )

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
		    local plyTeam = ply:GetInfo( "lambdaplayers_teams_myteam" )
			local revEnemies = reviveEnemies:GetBool()
			local plyEye = ply:EyePos()

			if reviceIcon:GetBool() then
		        for _, v in ipairs( GetLambdaPlayers() ) do
		            if !v:IsBeingDrawn() or v:GetIsDead() or !v:GetNWBool( "Downed" ) then continue end
		            if !revEnemies and plyTeam != "" and v.l_Team and v.l_Team != plyTeam then continue end

		            local iconPos = v:WorldSpaceCenter()
		            local headBone = v:LookupBone( "ValveBiped.Bip01_Head1" )
		            if headBone then iconPos = v:GetBonePosition( v:LookupBone( "ValveBiped.Bip01_Head1" ) ) + headOffset end

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

            if LambdaIsValid( ent ) and ent.IsLambdaPlayer and ent:GetNWBool( "Downed" ) and ply:EyePos():DistToSqr( tr.HitPos ) < 5000 and ( reviveEnemies:GetBool() or plyTeam == "" or !ent.l_Team or plyTeam == ent.l_Team ) then
                if ply:KeyDown( IN_USE ) then
                    SimpleText( "Revive Progress", "TDMG_SmallFont1", w, h + 100, color_grey1, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM )
                    revtime = revtime + ( FrameTime() / 3 )
                    surface.SetDrawColor( color_grey2 )
                    surface.DrawRect( w - 100, h + 110, 200, 24 )

                    surface.SetDrawColor(color_grey1)
                    surface.DrawRect( w - 98, h + 112, 196 * ( min( revtime, 1 ) / 1 ), 20 )
                else
                    SimpleText( "Press E to revive", "TDMG_SmallFont1", w, h + 115, color_grey1, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM )
                    revtime = 0
                end
            else
            	revtime = 0
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
		local plyMeta = FindMetaTable( "Player" )
		local ignorePlys = GetConVar( "ai_ignoreplayers" )

		local reviveEnabled = GetConVar( "mwii_revive_enable" )
		local reviveHealth = GetConVar( "mwii_revive_health" )
		local reviveTime = GetConVar( "mwii_revive_time" )
		local reviveHPTimer = GetConVar( "mwii_revive_hptimer" )

		local function OnServerThink()
			if !plysCanRevive:GetBool() then return end
			
			for _, ply in ipairs( player_GetAll() ) do
            	if !ply:Alive() or ply:IsDowned() or !ply:KeyDown( IN_USE ) then continue end

	            local tr = ply:GetEyeTrace()
	            local ent = tr.Entity
	            local plyTeam = ply:GetInfo( "lambdaplayers_teams_myteam" )

	            if ent.IsLambdaPlayer and ent:IsDowned() and ply:EyePos():DistToSqr( tr.HitPos ) < 5000 and ( reviveEnemies:GetBool() or ( plyTeam == "" or !ent.l_Team or plyTeam != ent.l_Team ) and ( ent:GetNW2String( "lambda_state" ) != "Combat" or ent:GetEnemy() != ply ) ) then
                    ent:SetNWEntity( "Reviver", ply )
                    ply.RevivingThatEntity = ent
                end
			end
		end

		hook.Add( "Think", hookName .. "OnServerThink", OnServerThink )

		local function OnSetState( self, state )
			if self:IsDowned() and ( state == "HealUp" or state == "ArmorUp" ) then return end
			self:l_ReviveSystem_OldSetState( state )
		end

		local eyeTrTbl = { Entity = NULL }
		local function OnGetEyeTrace( self )
			if self:GetState() == "ReviveFriend" and LambdaIsValid( self.l_ReviveTarget ) and self:IsInRange( self.l_ReviveTarget, 40 ) then 
				eyeTrTbl.Entity = self.l_ReviveTarget
				return eyeTrTbl
			end
			return self:l_ReviveSystem_OldGetEyeTrace()
		end

		local function OnPlayGestureAndWait( self, id, speed )
			if self:IsDowned() then return end
			self:l_ReviveSystem_OldPlayGestureAndWait( id, speed )
		end

		local function OnLambdaOnKilled( self, dmginfo )
			if self:GetIsDead() or self:IsDowned() or self.Takedowning or self.AlreadyWasDowned and downedOnce:GetBool() or dmginfo:IsExplosionDamage() or !reviveEnabled:GetBool() or !enableDowning:GetBool() or random( 1, 100 ) > downChance:GetInt() then
				self:l_ReviveSystem_OldLambdaOnKilled( dmginfo )
				return 
			end

			self:SetHealth( reviveHealth:GetInt() )
			self:GodEnable()
			self:SimpleTimer( 0.5, function() self:GodDisable() end, true )

			self.l_PreDownedData[ "RunSpeed" ] = self:GetRunSpeed()
			self.l_PreDownedData[ "WalkSpeed" ] = self:GetWalkSpeed()
			self.l_PreDownedData[ "CrouchSpeed" ] = self:GetCrouchSpeed()
			self.l_PreDownedData[ "JumpHeight" ] = self.loco:GetJumpHeight()

			self:CancelMovement()
	        self:SetRunSpeed( 25 )
	        self:SetCrouchSpeed( 25 )
	        self:SetWalkSpeed( 25 )
	        self.loco:SetJumpHeight( 0 )

			local wepDelay = Rand( 0.66, 1.25 )
			local curCooldown = self.l_WeaponUseCooldown
			self.l_WeaponUseCooldown = ( CurTime() <= curCooldown and curCooldown + wepDelay or CurTime() + wepDelay )

			self:RemoveGesture( self.l_CurrentPlayedGesture )
			self.l_UpdateAnimations = false
			
			local fallTime = self:SetSequence( self:LookupSequence( "laststand_down" ) )
			self:ResetSequenceInfo()
			self:SetCycle( 0 )
	        
	        self.l_moveWaitTime = CurTime() + fallTime

	        self.l_UpdateDownedAnimations = false
	        self:SimpleTimer( fallTime, function() self.l_UpdateDownedAnimations = true end )
			self:SimpleTimer( fallTime / random( 1, 4 ), function() 
				if self:IsPanicking() then return end
				self:PlaySoundFile( self:GetVoiceLine( "panic" ), true ) 
			end )

			if ignoreDowned:GetBool() then
				local attacker = dmginfo:GetAttacker()
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

			self:SetIsDowned( true )
			self.AlreadyWasDowned = true
			self.l_Downer = dmginfo:GetAttacker()
			self.NextHPTimePain = CurTime() + 1.0
			self.ReviveNumber = 0
			self.DownedTime = CurTime() + reviveTime:GetFloat()
		end

		local reviveTbl = { run = true, tol = 40 }
		local function LambdaReviveFriend( self )
			local revTarget = self.l_ReviveTarget
			if !LambdaIsValid( revTarget ) or !revTarget:IsDowned() or revTarget.Takedowning or LambdaIsValid( revTarget:GetNWEntity( "Reviver" ) ) and revTarget:GetNWEntity( "Reviver" ) != self then
				self:SetState( "Idle" )
				return
			end

			if self:IsInRange( revTarget, 40 ) and self:CanSee( revTarget ) then
				self.l_UpdateAnimations = false
				revTarget:SetNWEntity( "Reviver", self )

				self:SetSequence( self:LookupSequence( "laststand_startrevive" ) )
				self:ResetSequenceInfo()
				self:SetCycle( 0 )

				while ( self.l_ReviveTarget.ReviveNumber < 1.0 ) do
					if !LambdaIsValid( self.l_ReviveTarget ) or !self.l_ReviveTarget:IsDowned() or self.l_ReviveTarget.Takedowning or !self:IsInRange( self.l_ReviveTarget, 40 ) then break end
					if self.l_ReviveTarget:GetNWEntity( "Reviver" ) != self then break end
					if self:IsDowned() or self.Takedowning or self:GetState() != "ReviveFriend" then break end
					self:LookTo( self.l_ReviveTarget:WorldSpaceCenter(), 1.0 )
					coroutine.yield()
				end

				self.l_UpdateAnimations = true
				if self:GetState() == "ReviveFriend" then self:SetState( "Idle" ) end
				if IsValid( self.l_ReviveTarget ) then self.l_ReviveTarget:SetNWEntity( "Reviver", NULL ) end

				return
			end

			self:MoveToPos( revTarget, reviveTbl )
		end

		local function LambdaSetIsDowned( self, downed )
			self.Downed = downed
			self:SetNWBool( "Downed", downed )
		end

		local function LambdaBlankFunction( self ) end
		local function LambdaBlankReturnTrueFunction( self ) return true end
		local function LambdaBlankReturnFalseFunction( self ) return false end

		local function OnInitialize( self )
			self.l_ReviveSystem_OldSetState = self.SetState
			self.SetState = OnSetState

			self.l_ReviveSystem_OldLambdaOnKilled = self.LambdaOnKilled
			self.LambdaOnKilled = OnLambdaOnKilled

			self.l_ReviveSystem_OldGetEyeTrace = self.GetEyeTrace
			self.GetEyeTrace = OnGetEyeTrace

			self.l_ReviveSystem_OldPlayGestureAndWait = self.PlayGestureAndWait
			self.PlayGestureAndWait = OnPlayGestureAndWait

			self.SetIsDowned = LambdaSetIsDowned
			self.ReviveFriend = LambdaReviveFriend
			
			self.SetSVAnimation = LambdaBlankFunction
			self.GetActiveWeapon = LambdaBlankFunction
			self.SetActiveWeapon = LambdaBlankFunction
			self.KeyDown = LambdaBlankReturnTrueFunction

			self.ReviveNumber = 0
			self.l_Downer = NULL
			self.l_IsSelfReviving = false
			self.AlreadyWasDowned = false
			self.l_UpdateDownedAnimations = true
			self.DownedTime = CurTime()
			self.NextHPTimePain = CurTime()
			self.l_ReviveTargetsCheckTime = CurTime() + 1.0
			self.l_PreDownedData = {}
		end

		local GetMovingDirection = plyMeta.MovingDirection
		local function OnThink( self, wepent )
            if self.l_PrevAttackDistance then
	            self.l_CombatAttackRange = self.l_PrevAttackDistance
	            self.l_PrevAttackDistance = nil
	        end

	        if self:IsDowned() then
	        	local reviver = self:GetNWEntity( "Reviver" )
	        	if IsValid( reviver ) then 
	        		if ( !reviver:IsPlayer() or reviver:KeyDown(IN_USE) and reviver:GetEyeTrace().Entity == self ) and !self.Takedowning then
					    self.ReviveNumber = ( self.ReviveNumber + FrameTime() / 3 )
					    self.l_moveWaitTime = CurTime() + 0.1
		        		
		        		if reviver:IsPlayer() and self.l_IsSelfReviving then
		        		 	self.ReviveNumber = 0
		        		 	self.l_IsSelfReviving = false
		        		end

                        if reviver:IsPlayer() then
	                        reviver:SetActiveWeapon(nil)
	                        
	                        if !reviver.RevivingTarget then
	                            reviver:SetSVAnimation( "laststand_startrevive" )
	                            reviver.RevivingTarget = true
	                        end
	                     end
                    else
                        if reviver:IsPlayer() and reviver.RevivingTarget then
                            if !reviver.Takedowning then reviver:SetSVAnimation( "" ) end
                            reviver.RevivingTarget = false
                        end
                       	self:SetNWEntity( "Reviver", NULL )
					end
				else
	        		local canSelfRevive = ( enableSelfReviving:GetBool() and self.l_UpdateDownedAnimations and !self.Takedowning and ( !self:InCombat() or !self:IsInRange( self:GetEnemy(), 1000 ) or !self:CanSee( self:GetEnemy() ) ) and ( !self:IsPanicking() or !LambdaIsValid( self.l_RetreatTarget ) or !self:IsInRange( self.l_RetreatTarget, 1000 ) and !self:CanSee( self.l_RetreatTarget ) ) )
	        		if !self.l_IsSelfReviving then self.l_IsSelfReviving = ( random( 1, 100 ) == 1 and canSelfRevive ) end

	        		if self.l_IsSelfReviving and canSelfRevive then
                    	self.ReviveNumber = ( self.ReviveNumber + FrameTime() / 5.5 )
					    self.l_moveWaitTime = CurTime() + 0.1
		                
		                self.l_PrevAttackDistance = self.l_CombatAttackRange
		                self.l_CombatAttackRange = 0
		        	else
		        		if self.l_IsSelfReviving then self.l_IsSelfReviving = false end
		        		self.ReviveNumber = 0
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

                if self.ReviveNumber >= 1.0 then
					self:SetHealth( 25 )

			        self:SetRunSpeed( self.l_PreDownedData[ "RunSpeed" ] )
			        self:SetWalkSpeed( self.l_PreDownedData[ "WalkSpeed" ] )
			        self:SetCrouchSpeed( self.l_PreDownedData[ "CrouchSpeed" ] )
				    self.loco:SetJumpHeight( self.l_PreDownedData[ "JumpHeight" ] )

					local standTime = self:SetSequence( self:LookupSequence( "laststand_standup" ) )
					self:ResetSequenceInfo()
					self:SetCycle( 0 )

					self.l_moveWaitTime = CurTime() + standTime
					self:SimpleTimer( standTime, function() self.l_UpdateAnimations = true end )

					local wepDelay = Rand( 0.66, 1.25 ) + standTime
					local curCooldown = self.l_WeaponUseCooldown
					self.l_WeaponUseCooldown = ( CurTime() <= curCooldown and curCooldown + wepDelay or CurTime() + wepDelay )
                    
                    local reviver = self:GetNWEntity( "Reviver" )
                    if LambdaIsValid( reviver ) then
                    	if self.AddFriend and random( 1, 2 ) == 1 then self:AddFriend( reviver ) end

                    	if reviver:IsPlayer() then
	                        reviver:SetSVAnimation( "" )
	                        reviver.RevivingTarget = false
	                    end

						self:LookTo( reviver, 1.0 )
						self:SimpleTimer( ( standTime / random( 1, 4 ) ), function() self:PlaySoundFile( self:GetVoiceLine( "assist" ), true ) end )
                    end

					self:SetIsDowned( false )
				    table_Empty( self.l_PreDownedData )
                else
                	local forceWep = forcedWeapon:GetString()
                	if self.l_IsSelfReviving or !enableWeapons:GetBool() or useSpecifiedWeapon:GetBool() and self.l_Weapon != forceWep and !self:CanEquipWeapon( forceWep ) then
                		if self.l_Weapon != "none" and self.l_Weapon != "physgun" then
							self:SwitchWeapon( "none" )
						end
					elseif useSpecifiedWeapon:GetBool() and self.l_Weapon != forceWep and self:CanEquipWeapon( forceWep ) then
						self:SwitchWeapon( forceWep )
					end

		        	if self.l_UpdateDownedAnimations then
			        	local downAnim = "laststand_idle"
			        	if self.l_IsSelfReviving then
			        		downAnim = "laststand_selfrevive"
			        	else
			        		if !self.loco:GetVelocity():IsZero() then downAnim = "laststand_crawl_" .. GetMovingDirection( self ) end
							if self.l_HoldType != "normal" and self.l_HoldType != "passive" and self.l_HoldType != "fist" then downAnim = downAnim .. "_wep" end
			        	end

						downAnim = self:LookupSequence( downAnim )
						if self:GetSequence() != downAnim or self:IsSequenceFinished() then
							self:SetSequence( downAnim )
							self:ResetSequenceInfo()
							self:SetCycle( 0 )
						end
					end
				end
	        elseif CurTime() > self.l_ReviveTargetsCheckTime then 
        		local ene = self:GetEnemy()

        		if ( self:GetState() != "Combat" and !LambdaIsValid( ene ) or ene.IsLambdaPlayer and ( !ene:InCombat() or ene:GetEnemy() != self ) or ene.GetEnemy and ene:GetEnemy() != self ) and !self:IsPanicking() and self:GetState() != "ReviveFriend" and enableReviving:GetBool() then
	        		local canRescueNeutrals = ( bystandersRevive:GetBool() and self:GetState() != "FindTarget" and random( 1, 100 ) > self:GetCombatChance() and random( 1, 2 ) == 1 )
	        		local revTarget = self:GetClosestEntity( nil, 2000, function( ent )
	        			if ( !ent.IsLambdaPlayer or ent:GetIsDead() ) and ( !ent:IsPlayer() or !ent:Alive() or ignorePlys:GetBool() ) or ent.Takedowning or !ent:IsDowned() or LambdaIsValid( ent:GetNWEntity( "Reviver" ) ) or !self:CanSee( ent ) then return false end
	        			if canRescueNeutrals and ent.l_Downer != self and ( !self.l_Team or ent.IsLambdaPlayer and !ent.l_Team or ent:IsPlayer() and ent:GetInfo( "lambdaplayers_teams_myteam" ) == "" ) and ( !self.IsFriendsWith or !self:IsFriendsWith( ent ) ) then return true end
        				if self.IsInMyTeam and self:IsInMyTeam( ent ) then return true end
	        			if self.IsFriendsWith and self:IsFriendsWith( ent ) then return true end
	        		end )

	        		if IsValid( revTarget ) then
	        			if !self:InCombat() and random( 1, 100 ) <= self:GetVoiceChance() then
	        				self:PlaySoundFile( self:GetVoiceLine( "witness" ), true )
	        			end

	        			self.l_ReviveTarget = revTarget
	        			self:SetState( "ReviveFriend" )
	        			self:CancelMovement()
	        		end
	        	end

        		self.l_ReviveTargetsCheckTime = CurTime() + 1.0
	        end
		end

		local function OnBeginMove( self, movePos, onNavmesh )
			if self:IsDowned() then
				local teammates = self:FindInSphere( nil, 1500, function( ent )
        			if ( !ent.IsLambdaPlayer or ent:GetIsDead() ) and ( !ent:IsPlayer() or !ent:Alive() or ignorePlys:GetBool() ) or ent.Takedowning or ent:IsDowned() then return false end
        			if self.IsInMyTeam and self:IsInMyTeam( ent ) then return true end
        			if self.IsFriendsWith and self:IsFriendsWith( ent ) then return true end
				end )
				if #teammates > 0 then
					self:RecomputePath( teammates[ random( #teammates ) ] )
				end
			end
		end

		local function OnFootStep( self, pos, matType )
			if self:IsDowned() then return true end
		end

		local function OnCanTarget( self, target )
			if target:IsDowned() and ignoreDowned:GetBool() then return true end
			if self:IsDowned() and ( target == self:GetNWEntity( "Reviver" ) or !self:HasLethalWeapon() ) then return true end
		end

		local function OnCanSwitchWeapon( self, wepName, wepTbl )
			if self:IsDowned() and wepName != "none" and wepName != "physgun" then 
				if self.l_IsSelfReviving or !enableWeapons:GetBool() or useSpecifiedWeapon:GetBool() and forcedWeapon:GetString() != wepName then 
					return true 
				end
			end
		end

		local function OnKilled( self, dmginfo )
            self.AlreadyWasDowned = false
			if !self:IsDowned() then return end

	        self:SetRunSpeed( self.l_PreDownedData[ "RunSpeed" ] )
	        self:SetWalkSpeed( self.l_PreDownedData[ "WalkSpeed" ] )
	        self:SetCrouchSpeed( self.l_PreDownedData[ "CrouchSpeed" ] )
		    self.loco:SetJumpHeight( self.l_PreDownedData[ "JumpHeight" ] )

        	self:SetIsDowned( false )
		    table_Empty( self.l_PreDownedData )
		end

		hook.Add( "LambdaOnInitialize", hookName .. "OnInitialize", OnInitialize )
		hook.Add( "LambdaOnThink", hookName .. "OnThink", OnThink )
		hook.Add( "LambdaOnBeginMove", hookName .. "OnBeginMove", OnBeginMove )
		hook.Add( "LambdaFootStep", hookName .. "OnFootStep", OnFootStep )
		hook.Add( "LambdaCanTarget", hookName .. "OnCanTarget", OnCanTarget )
		hook.Add( "LambdaCanSwitchWeapon", hookName .. "CanSwitchWeapon", OnCanSwitchWeapon )
		hook.Add( "LambdaOnKilled", hookName .. "OnKilled", OnKilled )

	end
end

hook.Add( "InitPostEntity", hookName .. "InitializeModule", InitializeModule )