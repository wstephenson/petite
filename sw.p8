pico-8 cartridge // http://www.pico-8.com
version 14
__lua__
-- petite: tiny cmdr
-- by wstephenson
-- using picoracer-2048 code
-- vim: set ft=lua ts=1 sw=1 noet:
player={}
lasers={}
system={}
torps={}
particles={}
max_val=180
map_size=128
speed_torp=5
heat_laser=30
heat_torp=60
heat_star=10
dmg_laser=20
dmg_torp=60
dmg_collision=30
fuel_max=10000
jump_cost=2500
stellar_radius_scoop_max=1.35
scoop_max=30
stellar_radius_safe=1.4
stellar_radius_crit=1.05
shield_recharge_wait=150 -- 5 seconds
--galaxy map
--seeds
galaxy_side=16
seed0=0x5a4a
seed1=0x0248
seed2=0xb753
--current game state
state=nil
--table of all game states
states={}
--default states
states.menu={}
states.system=system
states.score={}
states.docked={}
states.map={}
states.dead={}

function states.menu:init()
	self.next_state="docked"
	setup_player()
end

function states.menu:draw()
	cls()
	map(16,0,0,0,16,16)
	print("tiny cmdr",46,75,12)
	print("start new cmdr (z/x)",24,109,12)
end

function states.score:init()
	self.next_state="docked"
	self.display_size=9
	self.scored=0
	self.timer=0
end

function states.score:draw()
	cls()
	draw_ui(nil)
	print("score:",46,10,7)
	local count=0
	-- display last $display_size of the $visible items of $score_items
	local first=max(1,self.scored-self.display_size+1)
	local count_to_show=min(self.display_size,self.scored)
	local limit=first+count_to_show
	local j=first
	while j<limit do
		item=player.score_items[j]
		string=item[1]..' '..item[2]..'cr'
		print(string,10,26+(j-first)*6,item[3])
		count+=1
		j+=1
	end
	print(player.score.." cr",70,26+6*self.display_size+2,7)
end

function states.score:update()
	if(self.scored<#player.score_items)then
	 self.timer+=1
		if(self.timer%20==0 or (btnp(4)))then
			self.scored+=1
			player.score+=player.score_items[self.scored][2]
		end
	else
		if (btnp(4))then
			player.score_items={}
			update_state()
		end
	end
end

function states.docked:init()
	self.next_state="map"
	local pship=player.ship
	if(pship.hp<pship.maxhp)then
		add(player.score_items,{'repair',flr((pship.maxhp-pship.hp)/pship.maxhp*-1000),6})
		pship.hp=pship.maxhp
	end
	if(pship.fuel<fuel_max)then
		add(player.score_items,{'refuel',flr((fuel_max-pship.fuel)/fuel_max*-100),11})
		pship.fuel=fuel_max
	end
	generate_system(player.sysx,player.sysy)
	self.txt={"docked",
			"",
			"score:"..player.score,
			"rank: harmless",
			"system:"..system_economy_label().." ("..player.sysx..","..player.sysy..")",
			"cargo:"..cargo_label(),
			"",
			"press z to launch"}
end

function states.docked:draw()
	draw_ui(self.txt)
end

function states.map:init()
	reseed_galaxy()
	cls()
	self.blink_timer=0
	self.blinked_cursor=false
	self.next_state="system"
	self.map_originx=24
	self.map_originy=16
	self.tgtx=player.sysx
	self.tgty=player.sysy
	--map
	if(not self.map_generated)then
		self.d={}
		for i=0,galaxy_side-1 do
			self.d[i]={}
			for j=0,galaxy_side-1 do
				local system={}
				system.color=star_color()
				local dwarf_star_scalef=(star_color()==2 or star_color()==7) and 0.33 or 1
				local r=(20+4*star_size())*dwarf_star_scalef
				local distance_from_start=distance(vec(3,3),vec(j,i))
				system.known=r/(distance_from_start*distance_from_start)>1.4
				self.d[i][j]=system
				twist()
			end
		end
		self.map_generated=true
	end
	--draw it
	draw_ui(nil)
	print("galaxy map",44,8,12)
	camera(-self.map_originx,-self.map_originy)
	rect(player.sysx*5,player.sysy*5,player.sysx*5+5,player.sysy*5+5,12)
	for i=0,galaxy_side-1 do
		for j=0,galaxy_side-1 do
			assert(#self.d>0)
   --jump range indicator
			if(self:in_range(i,j))then
				rect(j*5,i*5,j*5+5,i*5+5,11)
			end
   --star type
			if(self.d[i][j].known)then
				rectfill(j*5+1,i*5+1,j*5+4,i*5+4,self.d[i][j].color)
			else
				rect(j*5+1,i*5+1,j*5+4,i*5+4,self.d[i][j].color)
			end
		end
	end
	camera()
end

function states.map:update()
	if(btnp(0)) then self:erase_blink() self.tgtx-=1 end
	if(btnp(1)) then self:erase_blink() self.tgtx+=1 end
	if(btnp(2)) then self:erase_blink() self.tgty-=1 end
	if(btnp(3)) then self:erase_blink() self.tgty+=1 end
	if(self:in_range(self.tgtx,self.tgty) and btnp(4))then
	 if(not(player.sysx==self.tgtx and player.sysy==self.tgty))then
			player.sysx=self.tgtx
			player.sysy=self.tgty
			player.ship.fuel=max(0,player.ship.fuel-jump_cost)
		end
		update_state()
	end

	self.blink_timer+=1
	if(self.blink_timer%10==0) self:blink_cursor()
	rectfill(8,98,120,120,0)
	--todo: cache this - this is update()
	generate_system(player.sysx,player.sysy)
	print("cur: ("..player.sysx..","..player.sysy..")",10,98,12)
	print(system_economy_label(),66,98,(system_economy()==7) and 8 or 12)
	generate_system(self.tgtx,self.tgty)
	print("tgt: ("..self.tgtx..","..self.tgty..")",10,105,12)
	if(self.d[self.tgty][self.tgtx].known)then
		print(system_economy_label(),66,105,(system_economy()==7) and 8 or 12)
	else
		print("unknown",66,105,14)
	end
	print("cargo: "..cargo_label(),10,112,12)
	if (not self:in_range(self.tgtx,self.tgty))then
		print("too far",66,112,8)
	end
end

function states.map:blink_cursor()
	self.blinked_cursor=not self.blinked_cursor
	local cx1=self.map_originx+(self.tgtx*5)
	local cy1=self.map_originy+(self.tgty*5)
	local cx2=cx1+6
	local cy2=cy1+6
	local unaligned_start=cx1%2
	local unaligned_end=cx2%2
	xor_rect(cx1,cy1,cx2,cy2)
end

function states.map:erase_blink()
	if(self.blinked_cursor) self:blink_cursor()
end

function states.map:in_range(x,y)
	return (abs(player.sysx-x)<=1)and(abs(player.sysy-y)<=1)
end

function states.map:draw()
end

function system:init()
	self.next_state="score"
	generate_system(player.sysx,player.sysy)
	self.lastcx=64
	self.lastcy=64
	self.objects={}
	self.scoopables={}
	add(self.objects,player.ship)
	local q=create_ship('k', self)
	local r=create_ship('s', self)
	add(self.objects,q)
	add(self.objects,r)
	q.x=25
	q.y=0
	r.x=0
	r.y=-25
	player.ship.system=self
	self:populate()
end

function system:update()
	player.ship.fuel-=1
	-- enter input
	local controls=player.ship.controls
	controls.left = btn(0)
	controls.right = btn(1)
	controls.action = btnp(4)
	controls.select = btnp(5)
	controls.thrust = btn(2)
	controls.brake = btn(3)
	for o in all(self.objects) do
		o:update()
	end
	for l in all(lasers) do
		for o in all(self.objects) do
			check_laser_hit(l,o)
			if(o.hp<=0)self:killed(l,o)
		end
		age_transient(l,lasers)
	end
	for t in all(torps) do
		age_transient(t,torps)
		t.x+=t.xv
		t.y+=t.yv
		for o in all(self.objects) do
			check_torp_hit(t,o)
			if(o.hp<=0)self:killed(t,o)
		end
	end
	if(player.ship.fuel<=0)self:killed(nil,player.ship)
	self:environment_update()
end

function system:populate()
	local stype='cans'
	self.environment={}
	if(true) then
	local planet_radius=2+2.5*planet_size()
	local dwarf_star_scalef=(star_color()==2 or star_color()==7) and 0.33 or 1
	self.environment = {
			stype=stype,
			star = {
				x=-75,
				y=75,
				r=(20+4*star_size())*dwarf_star_scalef,
				color=star_color()
			},
			planet = {
				x=60,
				y=-60,
				r=planet_radius,
				color=planet_color()
			},
			station = {
				x=60+(planet_radius+20)*cos(-0.375),
				y=-60+(planet_radius+20)*sin(-0.375),
				angle=0.25,
				color=9,
				verts={
					vec(0,0),
					vec(-4,-4),
					vec(4,-4),
					vec(4,4),
					vec(-4,4)
				}
			}
		}
	end
	if(stype=='roids')then
		self.environment.roids={}
		local roids = self.environment.roids
		foreach ({3,7,12}, function(radius)
			for i=1,(36/radius) do
				local tooclose=true
				local tries=0
				while (tooclose and tries < 100) do
				 tooclose=false
					tries+=1
					roid={x=rnd(256)-128,y=rnd(256)-128,r=radius}
					for other in all(roids) do
						if (not tooclose) then
							tooclose=(other.r+roid.r)*1.5>distance(vec(other.x,other.y),vec(roid.x,roid.y))
						end
					end
				end
				add(roids,roid)
			end
		end)
	end
	if(stype=='cans')then
		for i=1,3 do
			local can={x=sin(i/3)*12,y=cos(i/3)*12,contents='liquor',value=100,color=4}
			add(self.scoopables,can)
		end
		for i=1,3 do
			local can={x=sin(i/3+0.5)*12-50,y=cos(i/3+0.5)*12,contents='fuel',value=1000,color=3}
			add(self.scoopables,can)
		end
	end
	local entry_body = self.environment.star
	local entry_angle=0.125
	player.ship.x=entry_body.x+entry_body.r*1.5*cos(entry_angle)
	player.ship.y=entry_body.y+entry_body.r*1.5*sin(entry_angle)
	player.ship.angle=entry_angle
end

function system:environment_update()
	local station=self.environment.station
	local star=self.environment.star
	station.angle-=0.005
	-- if player is within scooping range, scoop fuel dependent on velocity
	local pship=player.ship
	local not_scoopable=star.color==1 or star.color==2 or star.color==7
	player.scooping=(distance(vec(pship.x,pship.y),vec(star.x,star.y))<star.r*stellar_radius_scoop_max) and not not_scoopable
	if(player.scooping)then
		local speed = mysqrt(pship.xv*pship.xv+pship.yv*pship.yv)
		local fuel=scoop_max*speed/pship.maxv
		pship.fuel=min(pship.fuel+fuel,fuel_max)
	end
	-- ship heating
	local dist_player2star=distance(vec(pship.x,pship.y),vec(star.x,star.y))
	local dist_safe=star.r*stellar_radius_safe
	local dist_crit=star.r*stellar_radius_crit
	local heat_strength=1-clamp((dist_player2star-dist_crit)/(dist_safe-dist_crit),0,1)
	pship.heat+=heat_star*heat_strength
	-- check for object scooping
	foreach(self.scoopables,check_scooped)
	-- check for docking
	if(distance(vec(player.ship.x,player.ship.y),vec(station.x,station.y))<20 and
			abs(station.angle%1-player.ship.angle%1)<=0.05) then
		states.map:do_exploration_award()
		do_trade()
		update_state()
	end
end

function system:environment_draw()
	local env=self.environment
	local star=env.star
	local station=env.station
	local planet=env.planet

	rect(-map_size,-map_size,map_size,map_size,14)
	circ(star.x,star.y,star.r+rnd(1)-0.5,star.color)
	circ(planet.x,planet.y,planet.r,planet.color)
	local poly=fmap(station.verts,function(i) return rotate_point(station.x+i.x,station.y+i.y,station.angle,station.x,station.y) end)
	draw_poly(poly,station.color)
	if(env.stype=='roids')then
		foreach(env.roids, function(r) circ(r.x, r.y, r.r, 5) end)
	end
	foreach(self.scoopables,function(s)circ(s.x,s.y,3,s.color) end)
end

-- system
function check_laser_hit(laser,object)
	if(laser.origin==object or laser.spent==true)return
	local hit
	local hx
	local hy
	local ox=laser.origin.x
	local oy=laser.origin.y
	local poly = object:get_poly()
	hit,hx,hy=line_intersects_convex_poly(ox,oy,ox+laser.range*cos(laser.angle),oy+laser.range*sin(laser.angle),poly)
	if(hit) then
		make_explosion(vec(hx,hy),object.xv,object.yv)
		laser.spent=true
		laser.ttl-=1
		apply_damage(laser, object)
	end
end

-- system
function check_torp_hit(torp,object)
	if(torp.origin==object) return
	local hit
	local hx
	local hy
	local x = torp.x+4*cos(torp.angle+0.5)
	local y = torp.y+4*sin(torp.angle+0.5)
	local poly = object:get_poly()
	hit,hx,hy=line_intersects_convex_poly(torp.x,torp.y,x,y,poly)
	if(hit) then
		make_explosion(vec(hx,hy),(torp.xv+object.xv)/4,(torp.yv+object.yv)/4)
		del(torps,torp)
		apply_damage(torp, object)
	end
end

-- system
function apply_damage(weapon, subject)
	local dmg
	if(weapon.type=='l')then
		dmg=dmg_laser
	else
		if(weapon.type=='h')then
			local excessheat=subject.heat-subject.maxheat
			dmg=max(0,excessheat)/50
		else
			if(weapon.type=='c')then --collision
				dmg=dmg_collision
			else --torp
				dmg=dmg_torp
			end
		end
	end
	local old_shield=subject.shield
	local dmg_to_hull=min(0,subject.shield-dmg)
	subject.shield=max(0,subject.shield-dmg)
	if (old_shield > 0 and subject.shield == 0 and subject.timer_shield_recharge == 0) subject.timer_shield_recharge = shield_recharge_wait
	subject.hp+=dmg_to_hull
end

-- system
function system:debug()
	local o=player.ship
	print("score:"..player.score.." <"..o.actions[o.curr_action]..">",0,110,7)
	if(player.scooping)then
		print("scooping",44,64,2)
	end
	local ox=0
	hbar(ox,116,16,5,o.hp,o.maxhp,7,'d:')
	hbar(ox+26,116,16,5,o.shield,o.maxshield,12,'s:')
	hbar(ox+52,116,16,5,o.heat,o.maxheat,8,'h:')
	hbar(ox+78,116,16,5,o.fuel,fuel_max,8,'f:')
end

function system:draw()
	cls()
	local cx,cy
	local pship=player.ship
	cx=pship.x-64
	cy=pship.y-64
	camera(lerp(self.lastcx,cx,0.5),lerp(self.lastcy,cy,0.5))
	self.lastcx = cx
	self.lastcy = cy

 self:environment_draw()

	for o in all(self.objects) do
		o:draw()
	end
	--player:draw()
	for l in all(lasers) do
		local ox=l.origin.x
		local oy=l.origin.y
		line(ox,oy,ox+l.range*cos(l.angle),oy+l.range*sin(l.angle),l.color)
	end
	for t in all(torps) do
		line(t.x,t.y,t.x+1.5*cos(t.angle-0.45),t.y+1.5*sin(t.angle-0.45),9)
		line(t.x,t.y,t.x+1.5*cos(t.angle+0.45),t.y+1.5*sin(t.angle+0.45),9)
	end
	for p in all(particles) do
		line(p.x,p.y,p.x-p.xv,p.y-p.yv,p.ttl > 12 and 10 or (p.ttl > 7 and 9 or 8))
	end
	camera()
	--local sc=uint_shr(w1,12)*0.47
	--print('ps:'..planet_size()..',pc:'..planet_color()..',sc:'..sc..',e:'..system_economy(),10)
	self:debug()
end

--system
--puts a lot of methods onto the ship
function create_ship(type)
	local ship = {
		x=0,
		y=0,
		xv=0,
		yv=0,
		angle=0,
		speed=0,
		accel=0,
		thrust=0.2,
		revthrust=0.08,
		yaw=0.1,
		maxv=4,
		color=7,
		collision=0,
		laser_ttl=0,
		laser_range=20,
		actions={"l","m"},
		curr_action=1,
		heat=0,
		timer_shield_recharge=0
	}
	ship.controls = {}
	if type=='k' then
		ship.verts = {
			vec(5,0),
			vec(0,5),
			vec(-1.5,0),
			vec(0,-5)
		}
		ship.maxhp=50
		ship.maxshield=50
	else
		if type=='c' then
			ship.verts = {
				vec(1,-7),
				vec(6,-2),
				vec(6,2),
				vec(1,7),
				vec(-1.5,7),
				vec(-1.5,-7),
			}
			ship.maxhp=80
			ship.maxshield=80
		else
			ship.verts = {
				vec(2.5,2),
				vec(-2.5,4),
				vec(-2.5,-4),
				vec(2.5,-2)
			}
			ship.maxhp=40
			ship.maxshield=40
		end
	end
	ship.maxheat=heat_laser*4
	ship.hp=ship.maxhp
	ship.shield=ship.maxshield

	function ship:get_poly()
		return fmap(self.verts,function(i) return rotate_point(self.x+i.x,self.y+i.y,self.angle,self.x,self.y) end)
	end
	function ship:update()
		local angle = self.angle
		local ax = cos(angle)
		local ay = sin(angle)
		local x = self.x
		local y = self.y
		local xv = self.xv
		local yv = self.yv
		local accel = self.accel
		local controls = self.controls

		if controls.thrust then
			if(self==player.ship)player.ship.fuel-=self.thrust*50
			local speed = mysqrt(xv*xv+yv*yv)
			if(speed<self.maxv) then
				xv+=ax*self.thrust
				yv+=ay*self.thrust
			end
		end
		-- accelerate
		if controls.left then angle+=self.yaw*0.3 end
		if controls.right then angle-=self.yaw*0.3 end
		-- brake
		local sb_left
		local sb_right
		if controls.brake then
		 if(self==player.ship)player.ship.fuel-=self.revthrust*50
--			if controls.left then
--				sb_left = true
--			elseif controls.right then
--				sb_right = true
--			else
--				sb_left = true
--				sb_right = true
--			end
--			if sb_left then
--				angle += speed*0.0009
--			end
--			if sb_right then
--				angle -= speed*0.0009
--			end
			local speed = mysqrt(xv*xv+yv*yv)
			if(speed<self.maxv) then
				xv-=ax*self.revthrust
				yv-=ay*self.revthrust
			end
		end
		accel=min(accel,self.boosting and 3 or 2)
		xv+=ax*accel
		yv+=ay*accel

		x+=xv*0.3
		y+=yv*0.3

		xv*=0.99
		yv*=0.99
		-- actions (lasers,torps)
		if(controls.action) then
			if(self.actions[self.curr_action] == 'l') then
				if(self.heat<self.maxheat) then
					add(lasers,{type='l',origin=ship,range=self.laser_range,angle=self.angle,color=8,ttl=5,spent=false})
					self.heat+=heat_laser
				end
			end
			if(self.actions[self.curr_action] == 'm') then
				if(self.heat<self.maxheat) then
					add(torps,{type='m',origin=ship,x=self.x,y=self.y,angle=self.angle,xv=self.xv+speed_torp*cos(angle),yv=self.yv+speed_torp*sin(angle),ttl=30})
					self.heat+=heat_torp
				end
			end
		end
		-- select action
		if(controls.select)then
			self.curr_action+=1
			if(self.curr_action>count(self.actions)) self.curr_action=1
		end
		-- update self attrs
		-- motion
		self.x = x
		self.y = y
		self.xv = xv
		self.yv = yv
		self.accel = accel
		self.speed = speed -- used for showing speedo
		self.angle = angle
		-- heat
		self.heat=max(0,self.heat-1)
		apply_damage({type='h'}, self)
		if(self.hp<=0)self.system:killed({origin=nil},self)
		-- shields
		--self.timer_shield_recharge+=1
		self.timer_shield_recharge=max(0,self.timer_shield_recharge-1)
		if (self.timer_shield_recharge>0) self.timer_shield_recharge-=1
		if (self.timer_shield_recharge==0) self.shield=min(self.shield+1,self.maxshield)
	end
	function ship:draw()
		local x = self.x
		local y = self.y
		local angle = self.angle
		local color = (self.shield==self.maxshield) and self.color or (self.shield > 0 and 12 or (self.hp > 0 and 9 or 4))
		local v = fmap(self.verts,function(i) return rotate_point(x+i.x,y+i.y,angle,x,y) end)
		draw_poly(v,color)
	end
	return ship
end
-- end of create ship

function system:killed(subject, object)
	if(subject and subject.origin==player.ship)player.score+=1
	del(self.objects,object)
	make_explosion(vec(object.x,object.y,object.xv,object.yv))
	if(object==player.ship)then
		self.next_state='dead'
		update_state()
	end
end

function check_scooped(o)
	local pship=player.ship
	local speed_ok = mysqrt(pship.xv*pship.xv+pship.yv*pship.yv)<(pship.maxv*0.25)
	if(distance(vec(pship.x,pship.y),vec(o.x,o.y))<10)then
		if(speed_ok)then
			--todo: is object in front 90 degrees of ship?
			--todo: scoop sfx
			if(o.contents=='fuel')then
				pship.fuel=min(pship.fuel+o.value,fuel_max)
			else
				add(player.score_items,{'scooped ['..o.contents..']',o.value, 14})
			end
		else
		 make_explosion(vec(o.x,o.y),0,0)
			apply_damage({type='c'}, pship)
		end
		del(system.scoopables,o)
	end
end

function states.map:do_exploration_award()
	if(not states.map.d[player.sysy][player.sysx].known)then
		add(player.score_items,{'discovery ('..player.sysx..','..player.sysy..')',2000,12})
		states.map.d[player.sysy][player.sysx].known=true
	end
end

function states.dead:init()
	self.next_state='menu'
end

function states.dead:draw()
	draw_ui({'you died','','score:'..player.score})
end

-- utility
function clamp(val,minv,maxv)
	return max(minv,min(val,maxv))
end

function xor_rect(x,y,x2,y2)
	-- xor's each byte with 0xff
	-- each screen row is 64 bytes
	-- base addr of row given by y*0x40
	-- bytes to xor = base + x/2 to x2-x/2 + 1 if unalignedend
	-- x is even: start at x/2
	-- x is odd: start at (x/2) and xor 0xf0 first, xor 0x0f last
	assert(x2>x)
	assert(y2>y)
	local screenbase=0x6000
	local unaligned_start=x%2
	local unaligned_end=x2%2
	local bytes_wide=flr((x2-x)/2)+unaligned_end
	for i=0,y2-y-1 do
		local rowbase=screenbase+(y+i)*0x40
		local colstart=rowbase+x/2
		--xor each byte in row
		for j=0,bytes_wide-1 do
			local xor=0xff
			if (j==0 and unaligned_start>0) xor=0xf0
			if (j==bytes_wide-1 and unaligned_end > 0) then xor=0xf end
			local pixpair=peek(colstart+j)
			pixpair=bxor(pixpair,xor)
			poke(colstart+j, pixpair)
		end
	end
end

function draw_ui(txt)
	cls()
	map(0,0,0,0,16,16)
	local i=0
	foreach(txt,function(str) 
			print(str,64-(#str*4/2),64-(count(txt)/2)*6+i*6,7)
			i+=1
		end)
end

function make_explosion(point,xv,yv)
	xv=xv or 0
	yv=yv or 0
	for i=1,8 do
		add(particles,{x=point.x,y=point.y,xv=xv+rnd(2)-1,yv=yv+rnd(2)-1,ttl=20})
	end
end

function age_transient(transient,array)
	transient.ttl-=1
		if transient.ttl < 0 then
			del(array,transient)
		end
end

function mysqrt(x)
	if x <= 0 then return 0 end
	local r = sqrt(x)
	if r < 0 then return 32768 end
	return r
end

function vecdiff(a,b)
 return { x=a.x-b.x, y=a.y-b.y }
end

-- this works without overflow
function distance(a, b)
 local dx = a.x-b.x
 local dy = a.y-b.y
 dx*=dx
 dy*=dy
 local sum=dx+dy
 -- check for overflows
 if (dx<0 or dy<0 or sum<0) return max_val
 return sqrt(sum)
end

-- this overflows
function naive_distance(a,b)
 return mysqrt(distance2(a,b))
end

-- this is only useful for comparison
function distance2(a,b)
 local d = vecdiff(a,b)
 return d.x*d.x+d.y*d.y
end

function fmap(objs,func)
	local ret = {}
	for i in all(objs) do
		add(ret,func(i))
	end
	return ret
end

function vec(x,y)
	return { x=x,y=y }
end

function rotate_point(x,y,angle,ox,oy)
	ox = ox or 0
	oy = oy or 0
	return vec(cos(angle) * (x-ox) - sin(angle) * (y-oy) + ox,sin(angle) * (x-ox) + cos(angle) * (y-oy) + oy)
end

function linevec(a,b,col)
	line(a.x,a.y,b.x,b.y,col)
end

function draw_poly(points,col)
	for i=1,count(points) do
		if i<count(points) then
			linevec(points[i],points[i+1],col)
		else
			linevec(points[i],points[1],col)
		end
	end
end

-- returns bool,x,y (hit, one point of intersection if hit)
function line_intersects_convex_poly(x1,y1,x2,y2,poly)
	local hit
	local hitx
	local hity
	local point1
	local point2
	for i=1,count(poly) do
		if i<count(poly) then
			point1 = poly[i]
			point2 = poly[i+1]
		else
			point1 = poly[i]
			point2 = poly[1]
		end
		hit,hitx,hity=line_intersects_line(x1,y1,x2,y2,point1.x,point1.y,point2.x,point2.y)
		if hit then return hit,hitx,hity end
	end
	return false,0,0
end

function line_intersects_line(x0,y0,x1,y1,x2,y2,x3,y3)
	local s
	local t
	local s1x = x1-x0
	local s1y = y1-y0
	local s2x = x3-x2
	local s2y = y3-y2
	local denom=-s2x*s1y+s1x*s2y
	s=(-s1y*(x0-x2)+s1x*(y0-y2))/denom
	t=(s2x*(y0-y2)-s2y*(x0-x2))/denom
	if(s>=0 and s<=1 and t>=0 and t<=1) then
		-- intersection!
		return true,x0+t*s1x,y0+t*s1y
	else
		return false,0,0
	end
end

function lerp(a,b,t)
 return (1-t)*a+t*b
end

function hbar(x,y,w,h,v,max,color,label)
	local abswidth=v/max*w+#label*4
	print(label,x,y,color)
	rectfill(x+#label*4,y,x+abswidth,y+h-1,color)
end

function update_state()
	local next_state=states[state].next_state
	if(next_state)then
		state=next_state
		states[state]:init()
	end
end

function twist()
	local old=w0
	w0=w1
	w1=w2
	w2=old+w0+w1
	--debug('seed: ')
end

function reseed_galaxy()
	w0=seed0
	w1=seed1
	w2=seed2
end

function generate_system(x,y)
	reseed_galaxy()
	local system_index=y*galaxy_side+x
	for i=1,system_index do
		twist()
	end
end

function star_size()
	-- 4 lowest bits of hsb of w1
	return band(0xf,uint_shr(w1,8))
end

function star_color()
	-- 4 highest bits of hsb of w1
	local star_colors={[0]=1,2,8,9,10,7,12}
	return star_colors[flr(uint_shr(w1,12)*0.47)] or 8
end

function system_economy()
	-- 3 lowest bits of hsb of w0
	return band(uint_shr(w0,8),0x7)
end

function system_economy_label()
	local label={"none","none","none","lo-tech","lo-tech","hi-tech","hi-tech","anarchy"}
	return label[system_economy()+1]
end

function planet_size()
	-- 3 lowest bits of hsb of w1
 return uint_shr(band(w2,0xf00),8)
end

function planet_color()
	-- 5 lowest bits of hsb of w0
	local planet_colors={[0]=3,4,5,6,8,10,11,12,14,15}
	return planet_colors[flr(band(uint_shr(w0,8),0x1f)*0.65)] or 7
end

-- placeholder 
function system_color()
	return band(0xf,uint_shr(w0,8))
end

-- trading
function cargo_label()
	local cargo_types={[0]="none","lo-tech","hi-tech","contraband","stolen"}
	return cargo_types[player.cargo] or "miss!"
end

function do_trade()
	-- ship size factor, placeholder
	local ssf=1
	local cargo_value=0
	local new_cargo=player.cargo
	local src='uns'
	local dest='uns'
	--local system_economy=system_econy
	if(player.cargo==0)then --empty
		if(system_economy()==3 or system_economy()==4)then --lt
			new_cargo=1
		end
		if(system_economy()==5 or system_economy()==6)then --ht
			new_cargo=2
		end
		if(system_economy()==7)then --an
			new_cargo=0
		end
	end
	if(player.cargo==1)then --lt
		src='lt'
		if(system_economy()==3 or system_economy()==4)then --lt
			dest='lt'
			new_cargo=1
			cargo_value=100
		end
		if(system_economy()==5 or system_economy()==6)then --ht
			dest='ht'
			new_cargo=2
			cargo_value=200
		end
		if(system_economy()==7)then --an
			dest='an'
			new_cargo=0
			cargo_value=400
		end
	end
	if(player.cargo==2)then --ht
		src='ht'
		if(system_economy()==3 or system_economy()==4)then --lt
			dest='lt'
			new_cargo=1
			cargo_value=200
		end
		if(system_economy()==5 or system_economy()==6)then --ht
			dest='ht'
			new_cargo=2
			cargo_value=100
		end
		if(system_economy()==7)then --an
			dest='an'
			new_cargo=0
			cargo_value=400
		end
	end
	--todo: give contraband value when there are cops
	if(player.cargo==3)then --con
		if(system_economy()==3 or system_economy()==4)then --lt
			new_cargo=1
			cargo_value=0
		end
		if(system_economy()==5 or system_economy()==6)then --ht
			new_cargo=2
			cargo_value=0
		end
		if(system_economy()==7)then --an
			new_cargo=0
			cargo_value=0
		end
	end
	player.cargo=new_cargo
	if(cargo_value>0)then
		add(player.score_items,{"trade "..src.."->"..dest,cargo_value*ssf,8})
	end
end

function uint_shr(x,n)
	--shortcut
	if(x>=0) return flr(shr(x,n))
	--left shift unsupported
	assert(n>=0)
	if(n==0)then
		return x
	else
		--print("depth: "..n)
		local out=0
		for i=0,14 do
			-- lacking a bit set operation
			local bit_to_set=shl(1,i)
			local bit_to_test=shl(1,i+1)
			-- lua: 0 is true
			if(band(x,bit_to_test)!=0)then
				--print("setting bit "..i)
				out=bor(out,bit_to_set)
			end
		end
		return uint_shr(out,flr(n-1))
	end
end

function default_update()
	if(btnp(4) or btnp(5)) then update_state() end
end

function setup_player()
	local p=create_ship('c')
	player.ship=p
	player.score=0
	player.score_items={}
	player.sysx=3
	player.sysy=3
	player.cargo=0
	player.jump_range=1
	p.fuel=fuel_max
	p.player=player
end

function _init()
	srand(666)
	setup_player()
	state="menu"
 for k,v in pairs(states) do v:init() end
end

function _draw()
	states[state]:draw()
end

function _update()
	if(not states[state].update)then
		default_update()
	else
		states[state]:update()
	end

	for p in all(particles) do
		p.x += p.xv
		p.y += p.yv
		p.xv *= 0.95
		p.yv *= 0.95
		p.ttl -= 1
		if p.ttl < 0 then
			del(particles,p)
		end
	end
end


-->8
-- foon

function bar()
end

__gfx__
011cc000000000000000000000000000011cc000006c1100006c1100011cc0000000000ccccc000ccccc0ccc000ccc0cc0000ccccc0000000000000000000000
0011c0000010101010101010101010100011c000006cc110006cc1100011c000000000c11111c0c11111c111c0c111c11c00c11111c000000000000000000000
011cc000011111111111111111111100011cc000006c1100666c1100011cc66600000c1111111c1111111c11ccc111c11ccc1111111c00000000000000000000
0011c0000011c1c1c1c1c1c1c1c1c1100011c000006cc110ccccc1100011cccc0000c111111111c1111111c1111ccc111111c1111111c0000000000000000000
011cc000011ccccccccccccccccc1100011cc000006c11001c1c1100011c1c1c0000c111ccc111c1ccc111c1111c0c111111c1ccc111c0000000000000000000
0011c0000011c00000000000006cc1100011c000006cc11011111110001111110000c111c0c111c1c0c111c1111ccc111111c1c0c111c0000000000000000000
011cc000011cc00000000000006c1100011cc000006c110001010100010101010000c111ccc111c1ccc111c1111c11c11111c1ccc111c0000000000000000000
0011c0000011c00000000000006cc1100011c000006cc11000000000000000000000c111111111c1111111c1ccc111c11ccc11111111c0000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000c11111111c1111111c11c0c111c11cc11111111c00000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000c1111111c111ccccc111c0c111c11cc111ccccc000000000000000000000
66666666666660000066666600000000000000000000000000000000000000000000c111ccccc111c000c111c0c111c11cc111c0000000000000000000000000
ccccccccccccc000006ccccc00000000000000000000000000000000000000000000c111c000c111ccccc111c0c111c11cc111ccccc000000000000000000000
1c1c1c1c1c1cc000006c1c1c00000000000000000000000000000000000000000000c111c0000c1111111c11c0c111c11c0c1111111c00000000000000000000
111111111111c000006cc11100000000000000000000000000000000000000000000c111c00000c111111c11c0c111c11c00c111111c00000000000000000000
01010101011cc000006c110100000000000000000000000000000000000000000000c111c000000ccccccccc000ccccccc000cccccc000000000000000000000
000000000011c000006cc110000000000000000000000000000000000000000000000ccc00000000000000000000000000000000000000000000000000000000
66666666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66666666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66666666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66666666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66666666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66666666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66666666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66666666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

__gff__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0102020202020202020202020202020301020202020202020202020202020203000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0400000000000000000000000000000504000000000000000000000000000005000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0400000000000000000000000000000504000000000000202000000000000005000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0400000000000000000000000000000504000000000020000020000000000005000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0400000000000000000000000000000504002020202000000000202020200005000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0400000000000000000000000000000504002000000020000020000000200005000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0400000000000000000000000000000504002000010202020202020300200005000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
04000000000000000000000000000005040020200408090a0b0c0d0520200005000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
04000000000000000000000000000005040000000418191a1b1c1d0500000005000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0400000000000000000000000000000504000000071100000000120600000005000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0400000000000000000000000000000504000000000710101010060000000005000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0400000000000000000000000000000504000000000020202020000000000005000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0400000000000000000000000000000504000000000000000000000000000005000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0400000000000000000000000000000504000000000000000000000000000005000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0400000000000000000000000000000504000000000000000000000000000005000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0710101010101010101010101010100607101010101010101010101010101006000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344

