
local abs = math.abs
local pi = math.pi
local floor = math.floor
local random = math.random
local sqrt = math.sqrt
local max = math.max
local min = math.min
local pow = math.pow
local sign = math.sign

local time = os.time



-- throws a coin
function water_life.leftorright()
    local rnd = math.random()
    if rnd > 0.5 then return true else return false end
end



 -- drop on death what is definded in the entity table
function water_life.handle_drops(self)   
    if not self.drops then return end
    
    for _,item in ipairs(self.drops) do
        
        local amount = math.random (item.min, item.max)
        local chance = math.random(1,100) 
        local pos = self.object:get_pos()
        pos.x = pos.x + math.random(-1,1)
        pos.z = pos.z + math.random(-1,1)
        
        if chance < (100/item.chance) then
            minetest.add_item(pos, item.name.." "..tostring(amount))
        end
        
    end
end



function water_life.register_shark_food(name)
    table.insert(water_life.shark_food,name)
end


function water_life.feed_shark()
    local index = math.random(1,#water_life.shark_food)
    return water_life.shark_food[index]
end


function water_life.aqua_radar_dumb(pos,yaw,range,reverse)
	range = range or 4
	
	local function okpos(p)
		local node = mobkit.nodeatpos(p)
		if node then 
			if node.drawtype == 'liquid' then 
				local nodeu = mobkit.nodeatpos(mobkit.pos_shift(p,{y=1}))
				local noded = mobkit.nodeatpos(mobkit.pos_shift(p,{y=-1}))
				if (nodeu and nodeu.drawtype == 'liquid') or (noded and noded.drawtype == 'liquid') then
					return true
				else
					return false
				end
			else
				local h,l = mobkit.get_terrain_height(p)
				if h then 
					local node2 = mobkit.nodeatpos({x=p.x,y=h+1.99,z=p.z})
					if node2 and node2.drawtype == 'liquid' then return true, h end
				else
					return false
				end
			end
		else
			return false
		end
	end
	
	local fpos = mobkit.pos_translate2d(pos,yaw,range)
	local ok,h = okpos(fpos)
	if not ok then
		local ffrom, fto, fstep
		if reverse then 
			ffrom, fto, fstep = 3,1,-1
		else
			ffrom, fto, fstep = 1,3,1
		end
		for i=ffrom, fto, fstep  do
			local ok,h = okpos(mobkit.pos_translate2d(pos,yaw+i,range))
			if ok then return yaw+i,h end
			ok,h = okpos(mobkit.pos_translate2d(pos,yaw-i,range))
			if ok then return yaw-i,h end
		end
		return yaw+pi,h
	else 
		return yaw, h
	end	
end



-- counts animals in specified radius or active_object_send_range_blocks, returns a table containing numbers
function water_life.count_objects(pos,radius)

if not radius then radius = water_life.abo * 16 end

local all_objects = minetest.get_objects_inside_radius(pos, radius)
local hasil = {}
hasil.whales = 0
hasil.sharks = 0
hasil.fish = 0
hasil.all = #all_objects or 0

local _,obj
for _,obj in ipairs(all_objects) do
    local entity = obj:get_luaentity()
	if entity and entity.name == "water_life:whale" then
		hasil.whales = hasil.whales +1
    elseif entity and entity.name == "water_life:shark" then
		hasil.sharks = hasil.sharks +1
    elseif entity and (entity.name == "water_life:fish" or entity.name == "water_life:fish_tamed") then
        hasil.fish = hasil.fish +1
	end
end
return hasil
end




-- returns 2D angle from self to target in radians
function water_life.get_yaw_to_object(self,target)

    local pos = mobkit.get_stand_pos(self)
    local opos = target:get_pos()
    local ankat = pos.x - opos.x
    local gegkat = pos.z - opos.z
    local yaw = math.atan2(ankat, gegkat)
    
    return yaw
end

-- returns 2D angle from self to pos in radians
function water_life.get_yaw_to_pos(self,target)

    local pos = mobkit.get_stand_pos(self)
    local opos = target
    local ankat = pos.x - opos.x
    local gegkat = pos.z - opos.z
    local yaw = math.atan2(ankat, gegkat)
    
    return yaw - pi
end

-- turn around 90degrees from tgtob and swim away until out of sight
function water_life.hq_swimfrom(self,prty,tgtobj,speed) 
	
	local func = function(self)
	
		if not mobkit.is_alive(tgtobj) then return true end
        
            local pos = mobkit.get_stand_pos(self)
            local opos = tgtobj:get_pos()
			local yaw = water_life.get_yaw_to_object(self,tgtobj) - (pi/2) -- pi/2 = 90 degrees
            local distance = vector.distance(pos,opos)
            
            if (distance/1.5) < self.view_range then
                
                local swimto, height = water_life.aqua_radar_dumb(pos,yaw,3)
                if height and height > pos.y then
                    local vel = self.object:get_velocity()
                    vel.y = vel.y+0.1
                    self.object:set_velocity(vel)
                end	
                mobkit.hq_aqua_turn(self,51,swimto,speed)
                
            else
                return true
            end
                
            --minetest.chat_send_all("angel= "..dump(yaw).."  viewrange= "..dump(self.view_range).." distance= "..dump(vector.distance(pos,opos)))

        
		
	end
	mobkit.queue_high(self,func,prty)
end



-- same as mobkit.hq_aqua_turn but for large mobs
function water_life.big_hq_aqua_turn(self,prty,tyaw,speed)
    
	local func = function(self)
    if not speed then speed = 0.4 end
    if speed < 0 then speed = speed * -1 end
        
        local finished=mobkit.turn2yaw(self,tyaw,speed)
        if finished then return true end
	end
	mobkit.queue_high(self,func,prty)
end



-- same as mobkit.hq_aqua_roam but for large mobs
function water_life.big_aqua_roam(self,prty,speed)
	local tyaw = 0
	local init = true
	local prvscanpos = {x=0,y=0,z=0}
	local center = self.object:get_pos()
	local func = function(self)
		if init then
			mobkit.animate(self,'def')
			init = false
		end
		local pos = mobkit.get_stand_pos(self)
		local yaw = self.object:get_yaw()
		local scanpos = mobkit.get_node_pos(mobkit.pos_translate2d(pos,yaw,speed))
		if not vector.equals(prvscanpos,scanpos) then
			prvscanpos=scanpos
			local nyaw,height = water_life.aqua_radar_dumb(pos,yaw,speed,true)
			if height and height > pos.y then
				local vel = self.object:get_velocity()
				vel.y = vel.y+0.1
				self.object:set_velocity(vel)
			end	
			if yaw ~= nyaw then
				tyaw=nyaw
				mobkit.hq_aqua_turn(self,prty+1,tyaw,speed)
				return
			end
		end
		if mobkit.timer(self,10) then
			if vector.distance(pos,center) > water_life.abo*16*0.5 then
				tyaw = minetest.dir_to_yaw(vector.direction(pos,{x=center.x+random()*10-5,y=center.y,z=center.z+random()*10-5}))
			else
				if random(10)>=9 then tyaw=tyaw+random()*pi - pi*0.5 end
			end
		end
		
		if mobkit.timer(self,20) then mobkit.turn2yaw(self,tyaw,-1) end
		--local yaw = self.object:get_yaw()
		mobkit.go_forward_horizontal(self,speed)
	end
	mobkit.queue_high(self,func,prty)
end



-- swim to the next "node" which is inside viewrange or quit
function water_life.hq_swimto(self,prty,speed,node)
    
	local func = function(self)
    
    if not mobkit.is_alive(self) then return true end
    local r = self.view_range
    local pos = self.object:get_pos()
    local endpos = minetest.find_node_near(pos, r, {node})
    if not endpos then return true end
    local yaw = water_life.get_yaw_to_pos(self,endpos)
    
    if vector.distance(pos,endpos) > 1 then
                
                --minetest.chat_send_all(vector.distance(pos,endpos))
                if endpos.y > pos.y then
                    local vel = self.object:get_velocity()
                    vel.y = vel.y+0.1
                    self.object:set_velocity(vel)
                end	
                mobkit.hq_aqua_turn(self,51,yaw,speed)
                pos = self.object:get_pos() --mobkit.get_stand_pos(self)
                yaw = water_life.get_yaw_to_pos(self,endpos)
               
    else
         return true
    end
    
end
	mobkit.queue_high(self,func,prty)
    
end
