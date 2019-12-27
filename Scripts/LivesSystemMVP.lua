-- Operation Enduring Odyssey Lives System MINIMUM VIABLE PRODUCT --

-- Define Required Variables and Functions --
LivesRemaining = 1000
LivesAirborne = 0
LivesLost = 0
LivesMIA = 0
Takeoff = {}
Landing = {}
Death = {}
Eject = {}
--MIA = {}
--Revived = {}
MissionFailure = {}

-- Define Global Variables that are Al Minhad and Al Dhafra --



-- Define Useful Functions for Amending Variable Values --

function PlayerTakeoff()
	LivesRemaining = LivesRemaining - 1
	LivesAirborne = LivesAirborne + 1
		if LivesRemaining < 0
			then
				LivesRemaining = 0
		end
end

function PlayerLand()
	LivesRemaining = LivesRemaining + 1
	LivesAirborne = LivesAirborne - 1
		if LivesAirborne < 0
			then
				LivesAirborne = 0
		end	
end

function PlayerDie()
	LivesAirborne = LivesAirborne - 1
	LivesLost = LivesLost + 1
	if LivesAirborne < 0
		then
			LivesAirborne = 0
	end
end

function PlayerMIA()
	LivesMIA = LivesMIA + 1
	LivesAirborne = LivesAirborne - 1
		if LivesAirborne < 0
			then
				LivesAirborne = 0
		end
end

function PlayerRecovered()
	LivesLost = LivesMIA - 1
	LivesRemaining = LivesRemaining + 1
	if LivesMIA < 0
		then
			LivesMIA = 0
	end
end

-- Define Simple Functions for Amending Arithmetic Values of Variables by 1 --

function LivesRemainingUp()
	LivesRemaining = LivesRemaining - 1
end

function LivesRemainingDown()
	LivesRemaining = LivesRemaining + 1
end

function LivesAirborneUP()
	LivesAirborne = LivesAirborne + 1
end

function LivesAirborneDown()
	LivesAirborne = LivesAirborne - 1
end

function LivesLostUp()
	LivesLost = LivesLost + 1
end

function LivesLostDown()
	LivesLost = LivesLost - 1
end

-- F10 Menu Check Remaning Lives --

function PrintLives()
	trigger.action.outTextForCoalition(2,"Operation Enduring Odyssey Lives Status \n\nLives Remaining: " ..LivesRemaining.. "\nAirborne Pilots: " ..LivesAirborne.. "\nPilots MIA: " ..LivesMIA.. "\nLives Lost: " ..LivesLost, 10, 1)
end

function F10CheckLives()
	local PrintLivesToPlayer = missionCommands.addCommandForCoalition(2, "Team Lives Status", nil, PrintLives, {})
end

F10CheckLives()

-- Define Actions on Player Events --

function Takeoff:onEvent(event)
	if event.id == 3 and event.initiator ~= nil
		then
			PlayerTakeoff()
			local DepartedPilot = event.initiator
			trigger.action.outTextForGroup(DepartedPilot:getGroup():getID(), "You have taken off and a life has been removed from the team. Land safely at either Al Dhafra, Al Minhad or the Carrier to return your life to the pool. Good luck!", 10, 1)
			env.info("TAKEOFF EVENT RUN")
		end
end

function Landing:onEvent(event)
		if event.id == 4 and event.initiator ~= nil
		then 
			PlayerLand()
			local LandedPilot = event.initiator
			trigger.action.outTextForGroup(LandedPilot:getGroup():getID(), "Welcome back! You have landed safely and your life has been returned to the team. Great job!",  10, 1)
			env.info("LANDING EVENT RUN")
		end
end


function Death:onEvent(event)
	if event.id == 9 and event.initiator ~= nil
		then
			PlayerDie()
			local KilledPilot = event.initiator
			trigger.action.outTextForGroup(KilledPilot:getGroup():getID(), "You have been killed in action. Your life has been added to the death toll. Be more careful next time!", 10, 1)
			env.info("DEATH EVENT RUN")
		end
end

function Eject:onEvent(event)
	if event.id == 6 and event.initiator ~= nil
		then
			PlayerMIA()
			local EjectedPilot = event.initiator
			trigger.action.outTextForCoalition(2, EjectedPilot:getPlayerName().." has safely ejected and is considered MIA. CSAR Mission available, use F10 Menu for more information.", 10, 1) -- This line will be removed as Ali's CSAR Script sends the CSAR message.
			env.info("EJECT EVENT RUN")
		end
end

--[[function Revived:onEvent(event) --ALI ASSURES ME HE WILL DEAL WITH THIS IN HIS CSAR SCRIPT.wav
	if (CSAR Script Mission complete = true)
		then
			PlayerRecovered()
			trigger.action.outTextForGroup(RECOVERYPILOTSNAME, "You have successfully returned a downed pilot to base, and a life has been added to the pool. Great job!", 10, 1)
			env.info("RECOVERY EVENT RUN")
		end
end]]--

--[[function PlayerDisconnectLife:onEvent(event)
	TODO: Write function to deal with players disconnecting in the air and unsuccessfully landing.
end]]--

--[[function MIA:onEvent(event)
	TODO: Function to deal with players landing successfully, but not at Minhad or Dhafra, live added to MIA and will be returned to pool after an hour.
end]]--

-- Define Function for actioning Mission Failure --

function RestartMission()
	net.load_next_mission()
end

function MissionFailure:onEvent(event)
	if event.id == 9 and event.initiator ~= nil and LivesLost > 1000
		then
			trigger.action.outTextForCoalition(2, "The death toll of Operation Enduring Odyssey has soared too high. Public opinion of the Operation has fallen and units are being pulled out of the Persian Gulf. Mission Failed.", 60, 1)
			timer.scheduleFunction(RestartMission, {}, timer.getTime()+60)
		end
end

world.addEventHandler(Takeoff)
world.addEventHandler(Landing)
world.addEventHandler(Death)
world.addEventHandler(Eject)
--world.addEventHandler(MIA)
--world.addEventHandler(Revived)
world.addEventHandler(MissionFailure)