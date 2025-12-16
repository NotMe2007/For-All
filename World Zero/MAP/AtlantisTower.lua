-- Atlantis Tower Auto Floor Progression
-- Progresses through Atlantis Tower floors by touching tower triggers
-- https://pastebin.com/LBhD6jhw

local Players = game:GetService('Players')
local Workspace = game:GetService('Workspace')
local RunService = game:GetService('RunService')

local _genv = getgenv()
if _genv.AtlantisTowerAutoProgress == nil then
	_genv.AtlantisTowerAutoProgress = false
end

local function wait(sec)
	sec = tonumber(sec)
	if sec and sec > 0 then
		local t0 = os.clock()
		while os.clock() - t0 < sec do
			RunService.Heartbeat:Wait()
		end
	else
		RunService.Heartbeat:Wait()
	end
end

local plr = Players.LocalPlayer
if not plr then
	return
end

local function getPlayerParts()
	if not plr.Character then
		return nil, nil
	end

	local character = plr.Character
	local hrp = character:FindFirstChild('HumanoidRootPart')

	return character, hrp
end

local function setupFlight()
	local character, hrp = getPlayerParts()
	if not character or not hrp then return false end

	pcall(function()
		local collider = character:FindFirstChild('Collider') or character:FindFirstChild('UpperTorso')

		if not hrp:FindFirstChild('BodyVelocity') then
			local bv = Instance.new('BodyVelocity')
			bv.Velocity = Vector3.new(0, 0, 0)
			bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
			bv.P = 9000
			bv.Parent = hrp
		end

		if not hrp:FindFirstChild('BodyGyro') then
			local bg = Instance.new('BodyGyro')
			bg.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
			bg.P = 1e5
			bg.D = 500
			bg.CFrame = hrp.CFrame
			bg.Parent = hrp
		end

		hrp.CanCollide = false
		if collider then collider.CanCollide = false end
	end)

	return true
end

local tweenSpeed = 76
local function tweenToPosition(targetPos)
	local character, hrp = getPlayerParts()
	if not character or not hrp then return false end

	setupFlight()

	local maxTime = 15
	local startTime = os.clock()

	while true do
		character, hrp = getPlayerParts()
		if not character or not hrp then return false end

		local bv = hrp:FindFirstChild('BodyVelocity')
		if not bv then
			setupFlight()
			bv = hrp:FindFirstChild('BodyVelocity')
			if not bv then return false end
		end

		local toTarget = targetPos - hrp.Position
		local distance = toTarget.Magnitude

		if distance < 8 then
			bv.Velocity = Vector3.new(0, 0, 0)
			return true
		end

		if os.clock() - startTime > maxTime then
			bv.Velocity = Vector3.new(0, 0, 0)
			return false
		end

		local direction = toTarget.Unit
		bv.Velocity = direction * tweenSpeed

		wait(0.1)
	end
end

local function areAllMobsDead()
	local mobsAlive = 0

	pcall(function()
		local mobFolder = Workspace:FindFirstChild('Mobs')
		if not mobFolder then
			return
		end

		for _, mob in ipairs(mobFolder:GetChildren()) do
			pcall(function()
				local mobProps = mob:FindFirstChild('MobProperties')
				if mobProps and mobProps:FindFirstChild('Owner') and mobProps.Owner.Value == plr then
					return
				end

				local health = mob:FindFirstChild('HealthProperties')
				if health and health:FindFirstChild('Health') then
					local healthVal = health.Health
					if healthVal and healthVal.Value and healthVal.Value > 0 then
						mobsAlive = mobsAlive + 1
					end
				end
			end)
		end
	end)

	return mobsAlive == 0
end

local function touchPart(part)
	if not part then
		return false
	end

	local character, hrp = getPlayerParts()
	if not character or not hrp then
		return false
	end

	local success = false
	pcall(function()
		local targetPart = part

		if part:IsA('Model') then
			targetPart = part:FindFirstChild('Collider') or part:FindFirstChildWhichIsA('BasePart') or part.PrimaryPart
		end

		if targetPart and targetPart:IsA('BasePart') then
			hrp.CFrame = targetPart.CFrame
			wait(0.1)

			local touchInterest = targetPart:FindFirstChild('TouchInterest') or part:FindFirstChild('TouchInterest')
			if touchInterest then
				local touchTarget = touchInterest.Parent
				firetouchinterest(hrp, touchTarget, 0)
				wait(0.1)
				firetouchinterest(hrp, touchTarget, 1)
				success = true
			else
				success = true
			end
		end
	end)

	return success
end

local function startFloor()
	local success = false

	pcall(function()
		local missionObjects = Workspace:FindFirstChild('MissionObjects')
		if not missionObjects then
			return
		end

		-- Step 1: Go to NextFloorTeleporter.TouchInterest
		local nextTele = missionObjects:FindFirstChild('NextFloorTeleporter')
		if nextTele then
			touchPart(nextTele)
			success = true
		end

		-- Step 2: Wait 3 seconds (same as Prison Tower)
		wait(3)

		-- Step 3: TWEEN to MinibossSpawn to trigger mob spawning
		local minibossSpawn = missionObjects:FindFirstChild('MinibossSpawn')
		if minibossSpawn then
			local targetPos
			if minibossSpawn:IsA('BasePart') then
				targetPos = minibossSpawn.Position
			elseif minibossSpawn:IsA('Model') then
				local part = minibossSpawn:FindFirstChild('Collider') or minibossSpawn:FindFirstChildWhichIsA('BasePart') or minibossSpawn.PrimaryPart
				if part then targetPos = part.Position end
			end

			if targetPos then
				tweenToPosition(targetPos)
			end
			touchPart(minibossSpawn)
			success = true
		end
	end)

	return success
end

local function completeFloor()
	local success = false

	pcall(function()
		local missionObjects = Workspace:FindFirstChild('MissionObjects')
		if not missionObjects then
			return
		end

		-- Step 1: Go to WaveExit.TouchInterest
		local waveExit = missionObjects:FindFirstChild('WaveExit')
		if waveExit then
			if touchPart(waveExit) then
				-- Step 2: Wait 1 second
				wait(1)

				-- Step 3: Go to WaveStartGate.Collider if it exists (gate is already open)
				local waveStartGate = missionObjects:FindFirstChild('WaveStartGate')
				if waveStartGate then
					local collider = waveStartGate:FindFirstChild('Collider')
					if collider then
						touchPart(collider)
					end
				end
				success = true
			end
		end
	end)

	return success
end

spawn(function()
	local lastDeadCheckTime = 0
	local consecutiveDeadTime = 0
	local waitingForTransition = false
	local currentFloor = 1  -- Start at floor 1

	while true do
		wait(0.5)

		if not _genv.AtlantisTowerAutoProgress then
			waitingForTransition = false
			consecutiveDeadTime = 0
			wait(1)
		else
			local currentTime = os.clock()

			-- Check if mobs are dead
			if areAllMobsDead() then
				-- Track how long mobs have been dead
				if consecutiveDeadTime == 0 then
					consecutiveDeadTime = currentTime
				end

				-- If mobs have been dead for more than 5 seconds, proceed to next floor
				if currentTime - consecutiveDeadTime >= 5 and not waitingForTransition then
					waitingForTransition = true

					-- Complete current floor
					if completeFloor() then
						currentFloor = currentFloor + 1

						-- Wait a moment for transition
						wait(1)

						if currentFloor < 5 then
							startFloor()
						elseif currentFloor == 5 then
							-- Floor 5 is boss floor - do NextFloorTeleporter then BossDoorTrigger instead of MinibossSpawn
							local missionObjects = Workspace:FindFirstChild('MissionObjects')
							if missionObjects then
								-- Step 1: Touch NextFloorTeleporter (like normal)
								local nextTele = missionObjects:FindFirstChild('NextFloorTeleporter')
								if nextTele then
									touchPart(nextTele)
								end

								-- Step 2: Wait 3 seconds
								wait(3)

								-- Step 3: Tween to and trigger BossDoorTrigger (instead of MinibossSpawn)
								local bossDoorTrigger = missionObjects:FindFirstChild('BossDoorTrigger')
								if bossDoorTrigger then
									local targetPos
									if bossDoorTrigger:IsA('BasePart') then
										targetPos = bossDoorTrigger.Position
									elseif bossDoorTrigger:IsA('Model') then
										local part = bossDoorTrigger:FindFirstChild('Collider') or bossDoorTrigger:FindFirstChildWhichIsA('BasePart') or bossDoorTrigger.PrimaryPart
										if part then targetPos = part.Position end
									end

									if targetPos then
										tweenToPosition(targetPos)
									end
									touchPart(bossDoorTrigger)
								end
							end
						end
					end

					consecutiveDeadTime = 0
					waitingForTransition = false
				end
			else
				-- Mobs are alive, reset timer
				consecutiveDeadTime = 0
				waitingForTransition = false
			end
		end
	end
end)

local AtlantisTowerAPI = {}

function AtlantisTowerAPI.enable()
	_genv.AtlantisTowerAutoProgress = true
end

function AtlantisTowerAPI.disable()
	_genv.AtlantisTowerAutoProgress = false
end

function AtlantisTowerAPI.toggle()
	_genv.AtlantisTowerAutoProgress = not _genv.AtlantisTowerAutoProgress
end

function AtlantisTowerAPI.startFloor()
	return startFloor()
end

function AtlantisTowerAPI.completeFloor()
	return completeFloor()
end

_G.AtlantisTowerAPI = AtlantisTowerAPI
getgenv().AtlantisTowerAPI = AtlantisTowerAPI

return AtlantisTowerAPI