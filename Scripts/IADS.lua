shotHandler = {}
local redEWR = {}
local redSAMS = {}
local associatedSAMs = {}
local tracked_weapons = {}
local EWRFound = 0

local enableSAMsite

local function tablelength(T)
  if T == nil then

    return 0

  end
  local count = 0
  for _ in pairs(T) do 

    count = count + 1         
  end
  return count
end

local function getDistance (point1, point2)

  --  env.info("Calculating Distance")
  local x1 = point1.x
  local y1 = point1.y
  local z1 = point1.z
  local x2 = point2.x
  local y2 = point2.y
  local z2= point2.z

  local dX = math.abs(x1-x2)
  local dY = math.abs(y1-y2)
  local dZ = math.abs(z1-z2)
  local distance = math.sqrt(dX*dX + dZ*dZ)

  return distance

end

local function disableSAMsite (disableArgs)
  local SAMGroupName = disableArgs["GroupName"]
  local offTime = disableArgs["time"]
  env.info(SAMGroupName)
  if redSAMS[SAMGroupName].emitting then
--    env.info("Disabling "..SAMGroupName)
    local SAMController = redSAMS[SAMGroupName].group:getController()
    local SAMDetectedTargets = SAMController:getDetectedTargets()  
    if SAMDetectedTargets ~= nil then
      for i = 1, #SAMDetectedTargets do
        if SAMDetectedTargets[i].object:getCoalition() == 2 then
--        env.info("Group can still see blues, staying on...")
          return timer.getTime()+60
        end
      end
    end    
    redSAMS[SAMGroupName].group:getController():setOption(AI.Option.Ground.id.ALARM_STATE,1)
    redSAMS[SAMGroupName].emitting = false
--    env.info("Disabled "..SAMGroupName)
    if offTime ~= nil then
--      env.info("offTime = " ..offTime)
      local enableArgs = {["GroupName"] = SAMGroupName, ["time"] = nil}
      timer.scheduleFunction(enableSAMsite, enableArgs, timer.getTime()+offTime)

    end  
  end
end

local function emergencyShutoff (emergArgs)
  local SAMGroupName = emergArgs["GroupName"]
  local offTime = emergArgs["time"]
  env.info(SAMGroupName)
  if redSAMS[SAMGroupName].emitting then
--    env.info("Disabling "..SAMGroupName)
    local SAMController = redSAMS[SAMGroupName].group:getController()
    redSAMS[SAMGroupName].group:getController():setOption(AI.Option.Ground.id.ALARM_STATE,1)
    redSAMS[SAMGroupName].emitting = false
    --    env.info("Disabled "..SAMGroupName)
    if offTime ~= nil then
      local enableArgs = {["GroupName"] = SAMGroupName, ["time"] = nil}
      timer.scheduleFunction(enableSAMsite, enableArgs, timer.getTime()+offTime)
--      env.info("Scheduled reenable for "..offTime.." seconds")

    end  
  end
end

enableSAMsite = function(enableArgs)
  local SAMGroupName = enableArgs["GroupName"]
  local onTime = enableArgs["time"]
--  env.info("Enabling ".. SAMGroupName)
  if redSAMS[SAMGroupName].emitting == false then
    --    env.info("It's off for now")
    redSAMS[SAMGroupName].group:getController():setOption(AI.Option.Ground.id.ALARM_STATE,2)
    --    env.info("Now it's on")
    redSAMS[SAMGroupName].emitting = true
    --    env.info("Enabled "..SAMGroupName)

    if onTime ~= nil then
      local disableArgs = {["GroupName"] = SAMGroupName, ["time"] = nil}
      timer.scheduleFunction(disableSAMsite, disableArgs, timer.getTime()+onTime)


    end
  end
end

local function rangeOfSAM(SAMGroup)
  local rangeMax = 0
  --  env.info(SAMGroup:getName())
  for index, data in pairs(SAMGroup:getUnits()) do
    --    env.info("Unit "..index)
    if data:getAmmo() then
      --    env.info("Has ammo")
      local ammoType = data:getAmmo() 

      for _, item in pairs(ammoType) do

        if item.desc.rangeMaxAltMin then
          --          env.info("With max range of: "..item.desc.rangeMaxAltMax)
          if (item.desc.rangeMaxAltMin) > rangeMax then

            rangeMax = (item.desc.rangeMaxAltMin)
            --            env.info("The longest range missile in the group has a range of: "..rangeMax)
            return rangeMax
          end 
        end       
      end
    end
  end
end

local function populateEWRList()
  for i, gp in pairs(coalition.getGroups(1), 2) do
    for index, data in pairs(gp:getUnits()) do
      if data:hasAttribute("EWR") then
        --        env.info("EWR found in list")
        local groupName = gp:getName()
        redEWR[groupName] = {["group"] = gp}
      end
    end
  end
end

local function populateSAMList()

  for i, gp in pairs(coalition.getGroups(1), 2) do
    for index, data in pairs(gp:getUnits()) do
      if data:hasAttribute("SAM SR") then
        local groupName = gp:getName()
        redSAMS[groupName] = 
          {
            ["group"] = gp,
            ["emitting"] = true,
            ["range"] = rangeOfSAM(gp),
            ["searchVol"] =
            {
              id = world.VolumeType.SPHERE,
              params =
              {
                point = gp:getUnit(1):getPoint(),
                raidus = rangeOfSAM(gp)
              }
            }
          }
--        env.info("Group: " ..groupName.." added to SAM list")
      end
    end
  end
end

local function disableAllSAMS()

  for i, SAMGroup in pairs(redSAMS) do
    local disableArgs = {["GroupName"] = SAMGroup.group:getName(), ["time"] = nil}
    disableSAMsite(disableArgs)
    env.info("Disabled " ..SAMGroup.group:getName())

  end
end

local function foundEWRtoAssosciate(foundItem, EWR)

  --  env.info("Found group")
  local inList = 0
  local foundItemGroup = foundItem:getGroup()
  if foundItem:hasAttribute("SAM SR") then
    --    env.info("Found SAM site to attribute")
    if #associatedSAMs ~= 0 then
      for i = 1, #associatedSAMs do
        if associatedSAMs[i] == foundItemGroup:getName() then
          --        env.info("Already in list")
          return        
        end
      end
    end
    --      env.info("Adding SAM to local list")
    associatedSAMs[#associatedSAMs+1] = foundItemGroup:getName()

  end
end

local function associateSAMtoEWR()
  for i, EWR in pairs(redEWR) do
    associatedSAMs = {}
    local volEWRSearch =
      {
        id = world.VolumeType.SPHERE,
        params =
        {
          point = EWR.group:getUnit(1):getPoint(),
          radius = 120000
        }
      }
    world.searchObjects(Object.Category.UNIT, volEWRSearch, foundEWRtoAssosciate, EWR)        


    EWR["SAMs"] = associatedSAMs
    --    env.info("There are "..#associatedSAMs.." sams to be added to the EWR")
    --    env.info("There are " ..tablelength(EWR.SAMs).." associated with "..EWR.group:getName())    

  end   
end

local function EWRDetectedAircraft()

  for i, EWR in pairs(redEWR) do
    --    env.info("EWR "..EWR.group:getName())
    if EWR.group:getController() ~= nil then
      local EWRController = EWR.group:getController()
      --     env.info("Got controller")
      local detectedTargets = EWRController:getDetectedTargets()
      --      env.info(#detectedTargets .." targets found")
      for j = 1, #detectedTargets do
        if detectedTargets[j].object:getCoalition() == 2 then
          --        env.info("Target "..detectedTargets[j].object:getName().." is blue")
          --        env.info("There are "..tablelength(EWR.SAMs).." radars under this EWR")
          if (tablelength(EWR.SAMs) ~= 0) then
            for k = 1 , tablelength(EWR.SAMs) do
--              env.info("Range of SAM associated with EWR is: "..redSAMS[EWR.SAMs[k]].range)
              local distance = getDistance(redSAMS[EWR.SAMs[k]].group:getUnit(1):getPoint(), detectedTargets[j].object:getPoint())
--              env.info("Distance from target to SAM is: "..distance)
              if redSAMS[EWR.SAMs[k]].range > distance then
--                env.info("It's in range of "..redSAMS[EWR.SAMs[k]].group:getName())
                local enableArgs = {["GroupName"] = redSAMS[EWR.SAMs[k]].group:getName(), ["time"] = 300}
                enableSAMsite(enableArgs)
              end
            end 
          end
        end
      end
    end
  end
  return timer.getTime()+10 
end

local function ifFoundLocalEWR(foundItem)

--  env.info("Found Object")
  if foundItem:hasAttribute("EWR") then
    
--    env.info("It's an EWR")
    EWRFound = 1

  end
end

local function localEWRSites()
  
  EWRFound = 0
  for i, SAM in pairs(redSAMS) do


    local volEWRSearch =
      {
        id = world.VolumeType.SPHERE,
        params =
        {
          point = SAM.group:getUnit(1):getPoint(),
          radius = 100000
        }
      }
     world.searchObjects(Object.Category.UNIT, volEWRSearch, ifFoundLocalEWR)        


    if EWRFound == 0 then

      local enableArgs = {["GroupName"] = SAM.group:getName(), ["time"] = nil}
      enableSAMsite(enableArgs)
--      env.info("No EWRs within 100km, turning SAM site "..SAM.group:getName().." on.")

    end
  end
  return 420
end

local function ifFoundVisualSearch(foundItem, val)

  if foundItem:hasAttribute("Air") then
    if foundItem:getCoalition() == 2 then

      val = 1

    end
  end

end

local function visualSearch()

  local VisSpot= 0
  for i, SAM in pairs(redSAMS) do
    local volVisSearch =
      {
        id = world.VolumeType.SPHERE,
        params =
        {
          point = SAM.group:getUnit(1):getPoint(),
          radius = 7000
        }
      }    world.searchObjects(Object.Category.UNIT, volVisSearch, ifFoundVisualSearch, VisSpot)        
    if VisSpot == 1 then
      SAM.group:getController():setOption(AI.Option.Ground.id.ALARM_STATE,2)
--      env.info("Visual spot, turning SAM site "..SAM.group:getName().." on.")
    end
  end
  return 30
end

local function ifFoundMag(foundItem, val)

  -- env.info("Search found groupID: " ..foundItem:getName()) 
  if foundItem:getCoalition() == 1 then
    --    env.info("Group is friendly - Ignored") 
    --   env.info("Group is not friendly - Continue")
    if foundItem:hasAttribute("SAM SR") then 
      --      env.info(foundItem:getName().. " is a SAM SR")              
      if math.random(1,100) > 20 then      
--        env.info("Oh shit turn the radars off, said Ahmed, working at "..foundItem:getName()..". Part of group: " ..foundItem:getGroup():getName()) 
        local disableArgs = {["GroupName"] = foundItem:getGroup():getName(), ["time"] = math.random(50,100)}
        timer.scheduleFunction(emergencyShutoff, disableArgs, timer.getTime() + math.random(15,25))
      end           
    end     
  end      


end

local function ifFoundK(foundItem, impactPoint)
  local point1 = foundItem:getPoint()
  point1.y = point1.y + 2
  local point2 = impactPoint
  point2.y = point2.y + 2
  if land.isVisible(point1, point2) == true then
    trigger.action.explosion(point1, 1)
--    env.info("Unit"..foundItem.getID().. "Destroyed by script")                         
  end                                                                    
end

local function ifFoundS(foundItem, impactPoint)
--  env.info("Found unit in suppression range")
  local point1 = foundItem:getPoint()
  point1.y = point1.y + 5
  local point2 = impactPoint
  point2.y = point2.y + 5
  if land.isVisible(point1, point2) == true then
    foundItem:getController():setOnOff(false)
--       env.info("Suppressing.")
    local suppTime = math.random(35,120)
    local time = timer.getTime() + suppTime
    timer.scheduleFunction(foundItem:getController():setOnOff(true), {}, time)
--    env.info("recovering in " ..suppTime.." seconds")

  end

end

function shotHandler:onEvent(event)
  if event.id == world.event.S_EVENT_SHOT 
  then
    if event.weapon then

      --              env.info("weapon launched")          
      local ordnance = event.weapon                  
      local ordnanceName = ordnance:getTypeName()
      local WeaponPos = ordnance:getPosition().p
      local WeaponDir = ordnance:getPosition().x  
      local init = event.initiator
      local init_name = ' '
      if ordnanceName == "weapons.missiles.AGM_122" or ordnanceName == "weapons.missiles.AGM_88" or ordnanceName == "weapons.missiles.LD-10" or ordnanceName == "weapons.missiles.Kh-58U" or ordnanceName == "weapons.missiles.Kh-25MPU"then
        env.info("of type ARM") 
        local time = timer.getTime()               
        local VolMag =
          {
            id = world.VolumeType.SPHERE,
            params =
            {
              point = ordnance:getPosition().p,
              radius = 50000
            }
          }
        --               env.warning("Begin Search for magnum suppression")
        world.searchObjects(Object.Category.UNIT, VolMag, ifFoundMag)
        --               env.warning("Finished Search for magnum suppression")  
      end
      if init:isExist() then
        init_name = init:getName()
      end               
      tracked_weapons[event.weapon.id_] = { wpn = ordnance, init = init_name, pos = WeaponPos, dir = WeaponDir }                                         
    end

  end
end

local function track_wpns(timeInterval, time)
  for wpn_id_, wpnData in pairs(tracked_weapons) do

    if wpnData.wpn:isExist() then  -- just update position and direction.
      wpnData.pos = wpnData.wpn:getPosition().p
      wpnData.dir = wpnData.wpn:getPosition().x
      wpnData.exMass = wpnData.wpn:getDesc().warhead.explosiveMass
    else -- wpn no longer exists, must be dead.
      --                env.info("Mass of weapon warhead is " .. wpnData.exMass)
      local suppressionRadius = wpnData.exMass
      local ip = land.getIP(wpnData.pos, wpnData.dir, 20)  -- terrain intersection point with weapon's nose.  Only search out 20 meters though.
      local impactPoint
      if not ip then -- use last position
        impactPoint = wpnData.pos
        --                    trigger.action.outText("Impact Point:\nPos X: " .. impactPoint.x .. "\nPos Z: " .. impactPoint.z, 2)

      else -- use intersection point
        impactPoint = ip
        --                    trigger.action.outText("Impact Point:\nPos X: " .. impactPoint.x .. "\nPos Z: " .. impactPoint.z, 2)

      end 
      local VolK =
        {
          id = world.VolumeType.SPHERE,
          params =
          {
            point = impactPoint,
            radius = suppressionRadius*0.2
          }
        }

      local VolS =
        {
          id = world.VolumeType.SPHERE,
          params =
          {
            point = impactPoint,
            radius = suppressionRadius
          }
        }                              
      --                env.warning("Begin Search")
      world.searchObjects(Object.Category.UNIT, VolK, ifFoundK,impactPoint)
      world.searchObjects(Object.Category.UNIT, VolS, ifFoundS,impactPoint)               
      --                env.warning("Finished Search")
      tracked_weapons[wpn_id_] = nil -- remove from tracked weapons first.         


    end
  end
  return time + timeInterval
end

world.addEventHandler(shotHandler)
populateEWRList()
env.info("Red EWR list populated, it contains " ..tablelength(redEWR).." sites")
populateSAMList()
env.info("Red SAM list populated, it contains " ..tablelength(redSAMS).." sites")
associateSAMtoEWR()
env.info("Associated SAM sites to EWRs")
disableAllSAMS()
env.info("Disabled all SAM Sites")
localEWRSites()
env.info("Enabled all SAMs with no EWR nearby")
timer.scheduleFunction(localEWRSites, {},timer.getTime())
timer.scheduleFunction(track_wpns, .5, timer.getTime() + 1)
timer.scheduleFunction(EWRDetectedAircraft, {}, timer.getTime()+10)
timer.scheduleFunction(visualSearch, {}, timer.getTime()+120)
