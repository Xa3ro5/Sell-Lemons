-- Sell Lemons | Halloween 2026 | 2026-10-29.2
local env = (type(getgenv)=="function" and getgenv()) or _G
local old=env.__LemonSpam
if old then
    if old.Unload then old:Unload() else
        for key in pairs(old.flags or {}) do old.flags[key]=false end
        if old.stopAll then pcall(old.stopAll) end
        if old.win then pcall(function() old.win:Kill() end) end
    end
end
env.__CashVineRunning=false
local RS=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local UIS=game:GetService("UserInputService")
local TweenService=game:GetService("TweenService")
local Lighting=game:GetService("Lighting")
local CS=game:GetService("CollectionService")
local LP=game:GetService("Players").LocalPlayer
if not LP or game.PlaceId~=79268393072444 then warn("[Lemons] Requires Sell Lemons main place 79268393072444");return end
local App={version="2026-10-29.2",alive=true,ready=false,flags={},generations={},connections={},controls={},
    jobs={},status={},stats={},modules={},registry={},watched={},blacklist={},player={},lastResult="None yet",
    config={mode="Teleport",tweenSpeed=100,moveTimeout=20,offset=2,scanInterval=2,rebirthMult=2,maxDistance=5000,
        speedValue=32,jumpValue=75,jumpHeight=12,flySpeed=50,fovValue=80}}
env.__LemonSpam=App
-- Unresolved requests retain their gate across Stop All, timeout, and reload.
env.__LemonPending=env.__LemonPending or {}
local Pending=env.__LemonPending
function App:Connect(signal,fn)
    local c=signal:Connect(fn);table.insert(self.connections,c);return c
end
function App:Note(key,text) self.status[key]=tostring(text) end
function App:UIAccess()
    if type(setthreadidentity)=="function" then pcall(setthreadidentity,8) end
end
function App:Confirmed(key,text)
    self.stats[key]=(self.stats[key] or 0)+1;self.lastResult=key..": "..text
end
function App:Valid(key,token)
    return self.alive and self.ready and self.flags[key]==true and self.generations[key]==token
end
function App:Pause(key,token,seconds)
    local deadline=os.clock()+seconds
    repeat
        if not self:Valid(key,token) then return false end
        task.wait(math.min(0.05,math.max(0.01,deadline-os.clock())))
    until os.clock()>=deadline
    return self:Valid(key,token)
end
function App:WaitFor(key,token,seconds,predicate)
    local deadline=os.clock()+seconds
    repeat
        if not self:Valid(key,token) then return false end
        if predicate() then return true end
        task.wait(0.05)
    until os.clock()>=deadline
    return false
end
function App:Module(path)
    if self.modules[path] then return self.modules[path] end
    local object=RS
    for part in path:gmatch("[^.]+") do object=object and object:FindFirstChild(part) end
    if not object or not object:IsA("ModuleScript") then return nil end
    local identity=type(getthreadidentity)=="function" and getthreadidentity() or nil
    local ok,result=pcall(require,object)
    -- Some executors leave the calling thread at the game's require identity.
    if identity and type(setthreadidentity)=="function" then pcall(setthreadidentity,identity) end
    if ok then self.modules[path]=result;return result end
    self:Note("adapter",path..": "..tostring(result))
end
function App:Tycoon()
    local class=self:Module("Modules.Tycoon.LocalTycoon")
    local t=class and class.get()
    local instance=t and t.Instance
    local owner=instance and instance:FindFirstChild("Owner")
    if not instance or not instance.Parent or not owner or owner.Value~=LP then return nil end
    if self.tycoon~=instance then
        self:CancelMove();self.tycoon=instance;self.registry={};self.nextScan=0
    end
    return t
end
function App:Component(name,sub)
    local t=self:Tycoon()
    local class=self:Module("Modules.Tycoon.Component."..(sub and sub.."." or "")..name)
    return t and class and t:GetComponent(class)
end
function App:Orchard()
    local t=self:Tycoon()
    local object=t and t.Instance:FindFirstChild("Orchard")
    local class=self:Module("Modules.Tycoon.Orchard.Orchard")
    return object and class and class:get(object)
end
function App:Fruits()
    local o=self:Orchard()
    local class=self:Module("Modules.Tycoon.Orchard.OrchardFruits")
    return o and o:IsUnlocked() and class and o:GetComponent(class) or nil
end
function App:Coins()
    local class=self:Module("Core.Player")
    local currency=self:Module("Modules.Player.EventCurrency")
    local p=class and class.getLocal()
    local c=p and currency and p:GetComponent(currency)
    return c and c:Get("Halloween2026",true) -- raw replicated value, no local offsets
end
function App:FruitClicks()
    local service=self:Module("Modules.Service.ClickFruitService")
    return service and service:GetFruitsClicked()
end
function App:Character()
    local c=LP.Character
    local h=c and c:FindFirstChildOfClass("Humanoid")
    local r=c and c:FindFirstChild("HumanoidRootPart")
    if h and r and h.Health>0 then return c,h,r end
end
function App:Position(object)
    if not object or not object.Parent then return nil end
    if object:IsA("ProximityPrompt") or object:IsA("ClickDetector") then return self:Position(object.Parent) end
    if object:IsA("Attachment") then return object.WorldPosition end
    if object:IsA("BasePart") then return object.Position end
    if object:IsA("Model") then return object:GetPivot().Position end
end
function App:Request(key,token,scope,fn,predicate)
    if not self:Valid(key,token) then return false end
    local t=self:Tycoon()
    if not t then self:Note(key,"Waiting for owned tycoon");return false end
    if Pending[scope] then self:Note(key,"Pending: "..Pending[scope].name);return false end
    local lease={name=key,started=os.clock(),instance=t.Instance}
    Pending[scope]=lease
    if not self:Valid(key,token) or t~=self:Tycoon() then Pending[scope]=nil;return false end
    local ok,value=pcall(fn)
    local confirmedOk,confirmedError=pcall(function()
        if ok and self:Valid(key,token) and t==self:Tycoon() and predicate then
            if self:WaitFor(key,token,4,function() return t==self:Tycoon() and predicate() end) then
                self:Confirmed(key,"Replicated state changed")
            elseif self:Valid(key,token) then
                self:SetFlag(key,false);self:Note(key,"No replicated confirmation; paused. Refresh before retrying.")
            end
        end
    end)
    if Pending[scope]==lease then Pending[scope]=nil end
    if not self:Valid(key,token) then return false end
    if not ok then error(value) end
    if not confirmedOk then error(confirmedError) end
    return true,value
end
-- One arbiter for Player modifications, Fly, and every character tween.
function App:ClearFly()
    if self.flyVelocity then self.flyVelocity:Destroy();self.flyVelocity=nil end
    if self.flyGyro then self.flyGyro:Destroy();self.flyGyro=nil end
end
function App:RestoreCharacter()
    local p=self.player
    if p.partConnection then p.partConnection:Disconnect() end
    if p.h and p.h.Parent then
        if p.speedOwned then p.h.WalkSpeed=p.walk end
        if p.jumpOwned then p.h.JumpPower=p.power;p.h.JumpHeight=p.height end
        if p.controlOwned then p.h.AutoRotate=p.rotate;p.h.PlatformStand=p.stand end
    end
    if p.collisionOwned then for part,value in pairs(p.collisions or {}) do if part.Parent then part.CanCollide=value end end end
    self:ClearFly();self.player={}
end
function App:BindCharacter()
    local c,h,r=self:Character()
    if not c or self.player.character==c then return end
    self:CancelMove();self:RestoreCharacter()
    local p={character=c,h=h,root=r,walk=h.WalkSpeed,power=h.JumpPower,height=h.JumpHeight,
        rotate=h.AutoRotate,stand=h.PlatformStand,anchored=r.Anchored,collisions={}}
    self.player=p
    for _,part in ipairs(c:GetDescendants()) do if part:IsA("BasePart") then p.collisions[part]=part.CanCollide end end
    p.partConnection=c.DescendantAdded:Connect(function(part)
        if part:IsA("BasePart") then
            p.collisions[part]=part.CanCollide
            if self.move or self.flags.noclip then part.CanCollide=false end
        end
    end)
end
function App:ApplyCharacter()
    if not self.alive then return end
    self:BindCharacter()
    local p=self.player
    if not p.h or not p.h.Parent then return end
    local moving=self.move~=nil
    local flying=self.flags.fly and not moving
    if self.flags.speed then p.h.WalkSpeed=self.config.speedValue;p.speedOwned=true
    elseif p.speedOwned then p.h.WalkSpeed=p.walk;p.speedOwned=false end
    if self.flags.jump then p.h.JumpPower=self.config.jumpValue;p.h.JumpHeight=self.config.jumpHeight;p.jumpOwned=true
    elseif p.jumpOwned then p.h.JumpPower=p.power;p.h.JumpHeight=p.height;p.jumpOwned=false end
    if moving or flying then
        if not p.controlOwned then p.rotate=p.h.AutoRotate;p.stand=p.h.PlatformStand end
        p.h.AutoRotate=false;p.h.PlatformStand=true;p.controlOwned=true
    elseif p.controlOwned then p.h.AutoRotate=p.rotate;p.h.PlatformStand=p.stand;p.controlOwned=false end
    local suppress=moving or self.flags.noclip
    for part,value in pairs(p.collisions) do
        if part.Parent then
            if suppress then
                if not p.collisionOwned then p.collisions[part]=part.CanCollide end
                part.CanCollide=false
            elseif p.collisionOwned then part.CanCollide=value end
        else p.collisions[part]=nil end
    end
    p.collisionOwned=suppress
end
function App:FlyStep()
    local p=self.player
    if not self.flags.fly or self.move or not p.root or not p.root.Parent or not p.h or p.h.Health<=0 then self:ClearFly();return end
    if not self.flyVelocity then
        self.flyVelocity=Instance.new("BodyVelocity");self.flyVelocity.MaxForce=Vector3.new(1e7,1e7,1e7)
        self.flyVelocity.Velocity=Vector3.zero;self.flyVelocity.Parent=p.root
        self.flyGyro=Instance.new("BodyGyro");self.flyGyro.MaxTorque=Vector3.new(1e7,1e7,1e7)
        self.flyGyro.P=10000;self.flyGyro.Parent=p.root
    end
    local camera=workspace.CurrentCamera
    if not camera then return end
    local v=Vector3.zero
    if not UIS:GetFocusedTextBox() then
        if UIS:IsKeyDown(Enum.KeyCode.W) then v+=camera.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.S) then v-=camera.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.D) then v+=camera.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.A) then v-=camera.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.Space) then v+=Vector3.yAxis end
        if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then v-=Vector3.yAxis end
    end
    self.flyVelocity.Velocity=if v.Magnitude>0 then v.Unit*self.config.flySpeed else Vector3.zero
    self.flyGyro.CFrame=camera.CFrame
end
function App:CancelMove(owner)
    local m=self.move
    if not m or (owner and m.owner~=owner) then return end
    self.move=nil
    if m.tween then m.tween:Cancel() end
    if m.root and m.root.Parent then m.root.Anchored=m.anchored end
    if self.alive and self.player.character==LP.Character then self:ApplyCharacter() end
end
function App:Move(key,token,position,offset)
    if not self:Valid(key,token) or not position then return false end
    if self.flags.fly then self:Note(key,"Turn Fly off before travelling");return false end
    if self.move then self:Note(key,"Movement is owned by "..self.move.owner);return false end
    self:BindCharacter()
    local c,h,r=self:Character()
    if not c then self:Note(key,"Waiting for character");return false end
    local destination=CFrame.new(position+Vector3.new(0,offset or self.config.offset,0))*r.CFrame.Rotation
    local m={owner=key,root=r,character=c,anchored=r.Anchored}
    self.move=m
    local ok,err=pcall(function()
        self:ApplyCharacter();r.AssemblyLinearVelocity=Vector3.zero;r.AssemblyAngularVelocity=Vector3.zero
        if self.config.mode=="Tween" then
            local duration=(r.Position-destination.Position).Magnitude/self.config.tweenSpeed
            if duration>self.config.moveTimeout then error("Travel exceeds movement timeout") end
            r.Anchored=true
            m.tween=TweenService:Create(r,TweenInfo.new(math.max(0.05,duration),Enum.EasingStyle.Linear),{CFrame=destination})
            m.tween:Play()
            local deadline=os.clock()+duration+0.4
            while m.tween.PlaybackState==Enum.PlaybackState.Playing and os.clock()<deadline do
                if not self:Valid(key,token) or self.move~=m or LP.Character~=c or h.Health<=0 then return end
                task.wait(0.03)
            end
        else r.CFrame=destination end
    end)
    if self.move==m then self:CancelMove() end
    if not ok then error(err) end
    if not self:Pause(key,token,0.2) or LP.Character~=c then return false end
    local reached=(r.Position-destination.Position).Magnitude<8
    if not reached then self:Note(key,"Movement corrected or target not reached") end
    return reached
end
function App:SetFlag(key,on)
    if not self.alive then return end
    on=self.ready and on==true
    local p=self.player
    if on and not self.flags[key] and p.h and p.h.Parent then
        if key=="speed" then p.walk=p.h.WalkSpeed end
        if key=="jump" then p.power=p.h.JumpPower;p.height=p.h.JumpHeight end
    end
    self.generations[key]=(self.generations[key] or 0)+1;self.flags[key]=on
    self:CancelMove(key)
    if self.controls[key] then self:UIAccess();self.controls[key]:Set(on) end
    self:Note(key,on and "Ready" or "Off")
    if key=="fly" and on then self:CancelMove() end
    if key=="fly" and not on then self:ClearFly() end
    if key=="fov" then
        local camera=workspace.CurrentCamera
        if on and camera and not self.fovCamera then self.fovCamera=camera;self.savedFov=camera.FieldOfView end
        if not on and self.fovCamera then self.fovCamera.FieldOfView=self.savedFov;self.fovCamera=nil end
    elseif key=="fullbright" then
        if on and not self.lightSnapshot then
            self.lightSnapshot={Brightness=Lighting.Brightness,ClockTime=Lighting.ClockTime,Ambient=Lighting.Ambient,OutdoorAmbient=Lighting.OutdoorAmbient}
        elseif not on and self.lightSnapshot then
            for prop,value in pairs(self.lightSnapshot) do Lighting[prop]=value end
            self.lightSnapshot=nil
        end
    end
    self:ApplyCharacter()
end
function App:ResetPlayer()
    for _,key in ipairs({"noclip","speed","jump","infiniteJump","fly","antiIdle","fov","fullbright"}) do self:SetFlag(key,false) end
end
function App:StopAll()
    for key in pairs(self.flags) do self:SetFlag(key,false) end
    self:CancelMove();self:ResetPlayer();self.manual=nil;self:Note("system","Stopped")
end
App.stopAll=function() App:StopAll() end
function App:Unload()
    if not self.alive then return end
    self:StopAll();self.alive=false;self.ready=false;self:RestoreCharacter()
    for _,c in ipairs(self.connections) do c:Disconnect() end
    for _,c in pairs(self.watched) do c:Disconnect() end
    table.clear(self.connections);table.clear(self.watched)
    if self.win then self.win:Kill() end
    if env.__LemonSpam==self then env.__LemonSpam=nil end
end
function App:Refresh()
    local t=self:Tycoon()
    if not t then self:Note("adapter","Waiting for owned tycoon");return end
    local r={eventButtons={},manualPrompts={},fruitDetectors={},locations={},cannons={}}
    local plot=t.Instance:FindFirstChild("HalloweenPlot")
    local buttons=plot and plot:FindFirstChild("Buttons")
    if buttons then for _,category in ipairs(buttons:GetChildren()) do for _,button in ipairs(category:GetChildren()) do
        if CS:HasTag(button,"Tycoon.EventPurchase") and button:GetAttribute("EventCurrency")=="Halloween2026" then
            table.insert(r.eventButtons,{object=button,category=category.Name})
        end
    end end end
    if plot then for _,x in ipairs(plot:GetDescendants()) do
        if x:IsA("ProximityPrompt") and x.Parent and x.Parent.Parent and x.Parent.Parent:GetAttribute("Manual")==true then
            table.insert(r.manualPrompts,x)
            local remote=x.Parent.Parent:FindFirstChild("Candy")
            if remote and remote:IsA("RemoteEvent") and not self.watched[remote] then
                self.watched[remote]=remote.OnClientEvent:Connect(function() if self.alive then self.candySignals=(self.candySignals or 0)+1 end end)
            end
        elseif CS:HasTag(x,"Effect.HalloweenCannon") then table.insert(r.cannons,x) end
    end end
    -- Native ClickFruitService registers these public fruits, including new trees.
    for _,fruit in ipairs(CS:GetTagged("ClickFruit")) do
        if fruit:IsDescendantOf(workspace) then
            local part=fruit:FindFirstChild("ClickFruitPart")
            local detector=part and part:FindFirstChildOfClass("ClickDetector")
            if detector then table.insert(r.fruitDetectors,detector) end
        end
    end
    for object,untilTime in pairs(self.blacklist) do
        if not object.Parent or untilTime<os.clock() then self.blacklist[object]=nil end
    end
    for _,x in ipairs(CS:GetTagged("Tycoon.Teleport")) do if x:IsDescendantOf(t.Instance) then r.locations[x.Name]=x end end
    local map=workspace:FindFirstChild("Map")
    local event=map and map:FindFirstChild("Event")
    if event and event:FindFirstChild("Center") then r.locations["Halloween Event"]=event.Center end
    local orchard=t.Instance:FindFirstChild("Orchard")
    if orchard and orchard:FindFirstChild("Teleport") then r.locations.Orchard=orchard.Teleport end
    local home=t.Instance:FindFirstChild("Locations")
    if home then for _,x in ipairs(home:GetChildren()) do if x:IsA("BasePart") then r.locations[x.Name]=x end end end
    local locations=self:Component("TycoonLocations")
    r.lockedLocations={}
    if locations then
        for name in pairs(r.locations) do
            if name~="Halloween Event" and locations:GetLocation(name) and locations:GetLocationUnlocked(name)~=true then
                table.insert(r.lockedLocations,name);r.locations[name]=nil
            end
        end
    end
    for remote,c in pairs(self.watched) do if not remote.Parent then c:Disconnect();self.watched[remote]=nil end end
    self.registry=r;self.nextScan=os.clock()+self.config.scanInterval
    self:Note("adapter",t.Instance.Name.." | event buttons: "..#r.eventButtons.." | manual: "..#r.manualPrompts)
    if self.locationControl then
        local names={} for name in pairs(r.locations) do table.insert(names,name) end table.sort(names)
        if #names==0 then names={"No loaded locations"} end
        self:UIAccess();self.locationControl:SetOptions(names)
    end
end
function App:Job(key,interval,fn)
    self.jobs[key]={interval=interval,fn=fn,errors=0,nextRun=0};self.flags[key]=false;self.generations[key]=0
    task.spawn(function()
        local job=self.jobs[key]
        while self.alive do
            local usesMovement=key=="travel" or key=="spookyCoins" or key=="toffee" or key=="autofarmFruits"
            if self.ready and self.flags[key] and os.clock()>=job.nextRun and (not usesMovement or not self.movementJob) then
                local token=self.generations[key]
                local lease={key=key,token=token}
                if usesMovement then self.movementJob=lease end
                local ok,err=pcall(job.fn,self,key,token)
                if self.movementJob==lease then self.movementJob=nil end
                job.nextRun=os.clock()+job.interval
                if self:Valid(key,token) then
                    if not ok then
                        job.errors+=1;self:Note(key,tostring(err))
                        if job.errors>=3 then self:SetFlag(key,false);self:Note(key,"Paused after 3 errors: "..tostring(err)) end
                    else job.errors=0 end
                end
            end
            task.wait(0.1)
        end
    end)
end
function App:Nearest(objects,filter)
    local _,_,root=self:Character()
    if not root then return nil end
    local best,distance
    for _,object in ipairs(objects or {}) do
        local position=self:Position(object)
        if position and (not filter or filter(object)) and (not self.blacklist[object] or self.blacklist[object]<os.clock()) then
            local d=(position-root.Position).Magnitude
            if d<=self.config.maxDistance and (not distance or d<distance) then best,distance=object,d end
        end
    end
    return best
end
function App:DropList(spookyOnly)
    local folder=workspace:FindFirstChild("Drops")
    local list={}
    if folder then for _,x in ipairs(folder:GetChildren()) do
        if (not spookyOnly or x.Name=="SpookyCoinDrop") and self:Position(x) then table.insert(list,x) end
    end end
    return list
end
function App:MovementAllowed(key)
    if self.manual or self.flags.travel or self.flags.fly then self:Note(key,"Manual travel / Fly has priority");return false end
    if key~="spookyCoins" and self.flags.spookyCoins and self:Nearest(self:DropList(true)) then self:Note(key,"Spooky Coins have priority");return false end
    if key=="autofarmFruits" and self.flags.toffee and #(self.registry.manualPrompts or {})>0 then self:Note(key,"Toffee Dropper has priority");return false end
    return not self.move
end
function App:Travel(name,object,position,offset)
    for _,key in ipairs({"spookyCoins","toffee","autofarmFruits"}) do self.generations[key]=(self.generations[key] or 0)+1 end
    self:CancelMove();self.manual={name=name,object=object,position=position,offset=offset};self:SetFlag("travel",true)
end

App:Job("spookyCoins",0.4,function(self,key,token)
    if not self:MovementAllowed(key) then return end
    local target=self:Nearest(self:DropList(true),function(x) return x:FindFirstChild("Token")~=nil end)
    if not target then self:Note(key,"No Spooky Coin drops loaded; waiting for spawn");return end
    local before=self:Coins()
    if before==nil then self:Note(key,"Replicated event balance not loaded");return end
    self:Note(key,"Collecting "..target.Name)
    if not self:Move(key,token,self:Position(target),0) then return end
    if self:WaitFor(key,token,2,function() return self:Coins() and self:Coins()>before and (not target.Parent or not target:FindFirstChild("Token")) end) then
        self:Confirmed(key,"Spooky Coins +"..tostring(self:Coins()-before))
    elseif self:Valid(key,token) then self.blacklist[target]=os.clock()+8;self:Note(key,"Pickup not confirmed; target deferred") end
end)
App:Job("toffee",0.7,function(self,key,token)
    if not self:MovementAllowed(key) then return end
    local prompt=self:Nearest(self.registry.manualPrompts,function(x) return x.Enabled end)
    if not prompt then self:Note(key,"Toffee Dropper locked or not loaded; enable event purchases to unlock");return end
    if type(fireproximityprompt)~="function" then self:Note(key,"Executor lacks fireproximityprompt");return end
    local point=self:Position(prompt.Parent)
    local _,_,root=self:Character()
    if not point or not root then return end
    if (root.Position-point).Magnitude>math.min(6,prompt.MaxActivationDistance) then
        if not self:Move(key,token,point,2) then return end
    end
    if not self:Valid(key,token) or not prompt.Parent or not prompt.Enabled then return end
    local _,_,current=self:Character()
    if not current or (current.Position-point).Magnitude>prompt.MaxActivationDistance then return end
    local before=self.candySignals or 0
    fireproximityprompt(prompt,math.max(0,prompt.HoldDuration))
    if self:WaitFor(key,token,2,function() return (self.candySignals or 0)>before end) then self:Confirmed(key,"Server Candy descriptor received")
    else self:Note(key,"No server Candy descriptor yet") end
end)
App:Job("eventBuy",0.5,function(self,key,token)
    local balance=self:Coins()
    if balance==nil then self:Note(key,"Waiting for event balance");return end
    local best,bestPrice
    for _,entry in ipairs(self.registry.eventButtons or {}) do
        local x=entry.object
        local price=x:GetAttribute("EventCurrencyCost")
        if x.Parent and x:GetAttribute("Shown")==true and x:GetAttribute("Enabled")==true
            and x:GetAttribute("Unlocked")~=true and type(price)=="number" and price>=0 and price<=balance then
            if not bestPrice or price<bestPrice or (price==bestPrice and x.Name<best.Name) then best,bestPrice=x,price end
        end
    end
    if not best then self:Note(key,"Waiting for Spooky Coins or the next available Halloween purchase");return end
    local remote=best:FindFirstChild("Unlock")
    if not remote or not remote:IsA("RemoteFunction") then self:Note(key,"Unlock remote not loaded");return end
    self:Note(key,"Buying "..best.Name.." for "..bestPrice.." Spooky Coins")
    self:Request(key,token,"halloween",function() return remote:InvokeServer() end,function() return best.Parent and best:GetAttribute("Unlocked")==true end)
end)
App:Job("wake",0.3,function(self,key,token)
    local income,analyzer=self:Component("TycoonIncome"),self:Component("TycoonAnalyzer")
    if not income or not analyzer then return end
    local names={}
    for name,earner in pairs(analyzer:GetEarners()) do
        local stream=income:GetAllStreams()[name]
        if earner:IsEnabled() and stream and not stream.Automatic and stream.Count>0 then table.insert(names,name) end
    end
    table.sort(names)
    if #names==0 then self:Note(key,"All owned income streams are automated or unavailable");return end
    self.wakeIndex=(self.wakeIndex or 0)%#names+1
    local name=names[self.wakeIndex]
    local t=self:Tycoon()
    local remote=t and t.Remotes:FindFirstChild("WakeIncomeStream")
    if remote then self:Note(key,"Wake "..name);self:Request(key,token,"wake",function() return remote:InvokeServer(name) end) end
end)
App:Job("phoneOffer",0.5,function(self,key,token)
    local comp=self:Component("ClientTycoonPhoneOffers","Client")
    if not comp or not comp:GetCurrentOffer() then self:Note(key,"Waiting for phone offer");return end
    self:Request(key,token,"phone",function() comp:AcceptOffer() end,function() return comp:GetCurrentOffer()==nil end)
end)
App:Job("allPurchases",0.4,function(self,key,token)
    local a,b=self:Component("TycoonAnalyzer"),self:Component("TycoonBalances")
    if not a or not b then return end
    local cash=b:GetCash()
    local best,price
    for _,entity in pairs(a:GetPurchases()) do
        if entity:IsEnabled() and not entity:IsPurchased() then
            local cost=entity:GetPrice()
            if cost and cash>=cost and (not price or cost<price) then best,price=entity,cost end
        end
    end
    if not best then self:Note(key,"No affordable regular purchases");return end
    self:Note(key,"Buying "..best.Name)
    self:Request(key,token,"economy",function() return best:TryPurchaseAsync(false,false) end,function() return best:IsPurchased() end)
end)
App:Job("upgradeAll",0.4,function(self,key,token)
    local a,b=self:Component("TycoonAnalyzer"),self:Component("TycoonBalances")
    if not a or not b then return end
    local list={}
    for name,e in pairs(a:GetEarners()) do if e:IsEnabled() then table.insert(list,{name=name,earner=e}) end end
    table.sort(list,function(x,y) return x.name<y.name end)
    if #list==0 then return end
    self.upgradeIndex=(self.upgradeIndex or 0)%#list+1
    local e=list[self.upgradeIndex].earner
    local cost=e:GetUpgradePrice(nil,1)
    if not cost or cost>b:GetCash() then self:Note(key,"Waiting for cash: "..e.Name);return end
    local level=e:GetUpgradeLevel()
    self:Note(key,"Upgrading "..e.Name)
    self:Request(key,token,"economy",function() return e:UpgradeAsync(1) end,function() return e:GetUpgradeLevel()>level end)
end)
App:Job("autoRebirth",2,function(self,key,token)
    local r,b=self:Component("TycoonRebirth"),self:Component("TycoonBalances")
    local huge=self:Module("Modules.Huge")
    if not r or not b or not huge then return end
    local potential=r:GetPotentialInvestors()
    local threshold=huge.multiply(huge.add(b:GetInvestors(),b:GetInvestorsSpent()),huge.toHuge(self.config.rebirthMult))
    if potential<=huge.zero or potential<threshold then self:Note(key,"Waiting for investor multiplier");return end
    local before=r:GetTotalRebirths()
    self:Request(key,token,"economy",function() return r:RebirthAsync(false) end,function() return r:GetTotalRebirths()>before end)
end)
App:Job("autoEvolve",3,function(self,key,token)
    local e=self:Component("TycoonEvolution")
    if not e or e:GetEvolutionProgress()<1 then self:Note(key,"Evolution progress below 100%");return end
    local before=e:GetTotalEvolves()
    self:Request(key,token,"economy",function() return e:EvolveAsync(false) end,function() return e:GetTotalEvolves()>before end)
end)
App:Job("autoAscend",4,function(self,key,token)
    local a=self:Component("TycoonAscension")
    if not a or a:GetAscensionProgress()<1 then self:Note(key,"Ascension progress below 100%");return end
    local before=a:GetAscension()
    self:Request(key,token,"economy",function() return a:AscendAsync() end,function() return a:GetAscension()>before end)
end)
App:Job("orchardHarvest",0.6,function(self,key,token)
    local o=self:Orchard()
    if not o or not o:IsUnlocked() then self:Note(key,"Orchard locked");return end
    local plots=o.Instance:FindFirstChild("Plots")
    local core=RS:FindFirstChild("Core")
    local rr=core and core:FindFirstChild("RemoteRequest")
    local remote=rr and rr:FindFirstChild("OrchardPlot.Harvest")
    local fruits=self:Fruits()
    if not plots or not remote or not fruits or not fruits._Table or not fruits._Table:IsLoaded() then self:Note(key,"Orchard state not loaded");return end
    for _,plot in ipairs(plots:GetChildren()) do
        if plot:GetAttribute("Enabled")==true and plot:GetAttribute("State")==3 then
            local before=fruits:GetCount()
            self:Note(key,"Harvest "..plot.Name)
            self:Request(key,token,"orchard",function() return remote:InvokeServer(plot) end,function() return fruits:GetCount()>before end)
            return
        end
    end
    self:Note(key,"Waiting for ripe fruit (FruitReady)")
end)
App:Job("autoSellOrchard",1,function(self,key,token)
    local fruits=self:Fruits()
    if not fruits or not fruits._Table or not fruits._Table:IsLoaded() then self:Note(key,"Orchard locked or inventory not loaded");return end
    if Pending.orchard then self:Note(key,"Harvest in progress");return end
    local payload,total={},0
    for _,entry in ipairs(fruits:GetAll()) do if entry.Count>0 then payload[entry.Fruit]=entry.Count;total+=entry.Count end end
    if total==0 then self:Note(key,"No orchard fruit to sell");return end
    -- Native serializer, never an invented remote payload or a getgc search.
    self:Request(key,token,"orchard",function() return fruits:SellFruitsAsync(payload) end,function() return fruits:GetCount()<total end)
end)
App:Job("autofarmFruits",0.3,function(self,key,token)
    if not self:MovementAllowed(key) then return end
    if type(fireclickdetector)~="function" then self:Note(key,"Executor lacks fireclickdetector");return end
    local detector=self:Nearest(self.registry.fruitDetectors,function(x) return x.Parent and self:Position(x.Parent)~=nil end)
    if not detector then self:Note(key,"No fruit tree loaded");return end
    local part=detector.Parent
    local before=self:FruitClicks()
    if before==nil then self:Note(key,"Fruit progress not loaded");return end
    if not self:Move(key,token,self:Position(part),2) then return end
    local _,_,root=self:Character()
    if self:Valid(key,token) and root and detector.Parent and (root.Position-part.Position).Magnitude<=detector.MaxActivationDistance then
        fireclickdetector(detector);self.blacklist[detector]=os.clock()+2.5
        if self:WaitFor(key,token,2,function() return self:FruitClicks()>before end) then
            self:Confirmed(key,"Replicated FruitsClicked +"..tostring(self:FruitClicks()-before))
        elseif self:Valid(key,token) then self:Note(key,"No replicated fruit reward yet") end
    end
end)
App:Job("cashVine",30,function(self,key,token)
    local map=workspace:FindFirstChild("Map")
    local sewer=map and map:FindFirstChild("Sewer")
    local outer=sewer and sewer:FindFirstChild("CashVine")
    local inner=outer and outer:FindFirstChild("CashVine")
    local remote=inner and inner:FindFirstChild("Use")
    if not remote or not remote:IsA("RemoteFunction") then self:Note(key,"CashVine not loaded");return end
    self:Request(key,token,"cashVine",function() return remote:InvokeServer() end)
    self:Note(key,"Request sent; next check in 30s")
end)
App:Job("travel",0.15,function(self,key,token)
    local command=self.manual
    if not command then self:SetFlag(key,false);return end
    self:CancelMove()
    local position=command.position or self:Position(command.object)
    if position then
        if self:Move(key,token,position,command.offset) and self:Valid(key,token) then self:Note(key,"Reached "..command.name) end
    else self:Note(key,"Destination no longer loaded") end
    if self:Valid(key,token) then self.manual=nil;self:SetFlag(key,false) end
end)

local Library
for _,url in ipairs({
    "https://raw.githubusercontent.com/Xa3ro5/LifeIsRoblox/refs/heads/main/SmugLibCoreV2.lua",
    "https://pastebin.com/raw/CkVW0eJZ",
}) do
    local ok,source=pcall(game.HttpGet,game,url.."?lemons="..game:GetService("HttpService"):GenerateGUID(false),true)
    if ok and type(source)=="string" then
        local chunk,compileError=loadstring(source)
        if chunk then
            local ran,result=pcall(chunk)
            if ran and type(result)=="table" and type(result.CreateWindow)=="function" then Library=result;break end
            App:Note("ui",tostring(result))
        else App:Note("ui",tostring(compileError)) end
    else App:Note("ui",tostring(source)) end
end
if not Library then warn("[Lemons] SmugLibV2 could not load: "..tostring(App.status.ui));App:Unload();return end
local ok,win=pcall(Library.CreateWindow,Library,"Sell Lemons | Halloween 2026",{
    Width=650,Height=560,ToggleKey=Enum.KeyCode.RightShift,
    ConfigKey="SellLemons_Halloween2026",ConfigAutoSave=true,
})
if not ok or not win then warn("[Lemons] SmugLibV2: "..tostring(win));App:Unload();return end
App.win=win
local function setupUI()
-- SmugLib can invoke callbacks while constructing saved toggles.
-- Clear their persisted values AND guard callbacks until construction completes.
local saved=win:GetConfig()
for key,value in pairs(saved) do if type(value)=="boolean" then saved[key]=false end end
function App:Toggle(section,label,key)
    self.flags[key]=false;self.generations[key]=self.generations[key] or 0
    local control=section:Toggle(label,function(on) if self.ready then self:SetFlag(key,on) end end,false)
    control:Set(false);self.controls[key]=control;return control
end
function App:Slider(section,label,key,min,max,step)
    section:Slider(label,min,max,self.config[key],function(value)
        if type(value)=="number" and value==value then self.config[key]=math.clamp(value,min,max) end
    end,step or 1)
end
local halloween=win:Folder("Halloween")
local eventFarm=halloween:Section("Autofarm")
App:Toggle(eventFarm,"Auto Collect Spooky Coins","spookyCoins")
App:Toggle(eventFarm,"Auto Toffee Dropper","toffee")
App.eventLabel=eventFarm:Label("Loading replicated event state...")
eventFarm:Label("Priority: manual travel > Spooky Coins > Toffee > fruit trees")
local eventBuy=halloween:Section("Candy Factory Purchases")
App:Toggle(eventBuy,"Auto Buy ALL Halloween (spends all Spooky Coins)","eventBuy")
eventBuy:Label("Buys every available Halloween item, including decorations. No coin reserve.")
eventBuy:Label("Cannons fire automatically on the server.")
local farms=win:Folder("Autofarm")
local main=farms:Section("Lemon Tycoon")
for _,entry in ipairs({{"Spam Collect (ready streams)","wake"},{"Auto-Accept PhoneOffer","phoneOffer"},
    {"Auto-Upgrade ALL","upgradeAll"},{"Auto purchase ALL","allPurchases"},{"Autofarm fruits","autofarmFruits"},
    {"Auto-Harvest Orchard","orchardHarvest"},{"Auto-Sell Orchard","autoSellOrchard"},{"Auto CashVine","cashVine"}}) do App:Toggle(main,entry[1],entry[2]) end
local prestige=farms:Section("Prestige (resets progression when enabled)")
App:Toggle(prestige,"Auto-Rebirth","autoRebirth")
App:Slider(prestige,"Rebirth investor multiplier","rebirthMult",1.1,20,0.1)
App:Toggle(prestige,"Auto-Evolve","autoEvolve")
App:Toggle(prestige,"Auto-Ascension","autoAscend")
local travel=win:Folder("Teleport / Tween"):Section("Navigation")
travel:Dropdown("Movement",{"Teleport","Tween"},function(value)
    if value=="Teleport" or value=="Tween" then App.config.mode=value end
end,"Teleport")
App:Slider(travel,"Tween speed","tweenSpeed",20,300,5)
App:Slider(travel,"Movement timeout","moveTimeout",3,60,1)
App:Slider(travel,"Target height offset","offset",0,8,0.5)
App.locationControl=travel:Dropdown("Location",{"Halloween"},function(value) App.selectedLocation=value end,"Halloween")
travel:Button("Travel to selected location",function()
    local name=App.selectedLocation or "Halloween"
    local object=(App.registry.locations or {})[name]
    if name=="Orchard" then local o=App:Orchard();if not o or not o:IsUnlocked() then win:Notify("Orchard is locked",3);return end end
    if object then App:Travel(name,object) else win:Notify("Destination not loaded; Refresh",3) end
end)
travel:Button("Teleport Home",function()
    local locations=App.registry.locations or {}
    local object=locations.LemonStand or locations["Lemon Stand"] or locations.Spawn
    if not object then
        local t=App:Tycoon()
        local p=t and t.Instance:FindFirstChild("Purchases")
        local s=p and p:FindFirstChild("Lemon Stand")
        local m=s and s:FindFirstChild("Multiplier")
        local b=m and m:FindFirstChild("Billboard")
        object=b and b:FindFirstChild("Part4")
    end
    if object then App:Travel("Home",object) else win:Notify("Home not loaded",3) end
end)
travel:Button("Teleport to nearest drop",function()
    local target=App:Nearest(App:DropList(false))
    if target then App:Travel(target.Name,target,nil,0) else win:Notify("No drops loaded",3) end
end)
travel:Button("Save current position",function()
    local _,_,root=App:Character();if root then App.savedPosition=root.Position;win:Notify("Position saved",2) end
end)
travel:Button("Return to saved position",function() if App.savedPosition then App:Travel("Saved position",nil,App.savedPosition,0) end end)
travel:Button("Cancel movement",function() App.manual=nil;App:SetFlag("travel",false);App:CancelMove() end)
local player=win:Folder("Player"):Section("Character")
App:Toggle(player,"Noclip","noclip")
App:Toggle(player,"Speed changer","speed")
App:Slider(player,"Walk speed","speedValue",8,120,1)
App:Toggle(player,"Jump changer","jump")
App:Slider(player,"Jump power","jumpValue",20,160,5)
App:Slider(player,"Jump height (height mode)","jumpHeight",3,40,1)
App:Toggle(player,"Infinite jump","infiniteJump")
App:Toggle(player,"Fly (WASD / Space / Left Ctrl)","fly")
App:Slider(player,"Fly speed","flySpeed",10,160,5)
App:Toggle(player,"Anti-idle","antiIdle")
App:Toggle(player,"FOV changer","fov")
App:Slider(player,"Field of view","fovValue",40,110,1)
App:Toggle(player,"Fullbright","fullbright")
player:Button("Reset player settings",function() App:ResetPlayer() end)
local settings=win:Folder("Settings / Diagnostics"):Section("Runtime")
App:Slider(settings,"Maximum target distance","maxDistance",20,5000,20)
App:Slider(settings,"Registry refresh interval","scanInterval",1,10,1)
App.statusLabel=settings:Label("Starting...")
App.resultLabel=settings:Label("Last confirmed result: none")
settings:Button("Refresh",function() App:Refresh() end)
settings:Button("Stop All",function() App:StopAll();win:Notify("All automation and Player controls stopped",3) end)
settings:Button("Unload",function() App:Unload() end)
settings:Bind("Panic / Unload",Enum.KeyCode.P,function() App:Unload() end)
win:SetOnClose(function() App:Unload() end)
App:Connect(LP.CharacterRemoving,function()
    App:CancelMove();App:RestoreCharacter()
    for key in pairs(App.generations) do App.generations[key]+=1 end
end)
App:Connect(RunService.Stepped,function() App:ApplyCharacter() end)
App:Connect(RunService.Heartbeat,function()
    if not App.alive then return end
    App:FlyStep()
    if App.flags.fov and workspace.CurrentCamera then
        if App.fovCamera~=workspace.CurrentCamera then
            if App.fovCamera then App.fovCamera.FieldOfView=App.savedFov end
            App.fovCamera=workspace.CurrentCamera;App.savedFov=App.fovCamera.FieldOfView
        end
        App.fovCamera.FieldOfView=App.config.fovValue
    end
    if App.flags.fullbright then
        Lighting.Brightness=2;Lighting.ClockTime=14
        Lighting.Ambient=Color3.fromRGB(160,160,160);Lighting.OutdoorAmbient=Color3.fromRGB(160,160,160)
    end
end)
App:Connect(UIS.JumpRequest,function()
    if App.flags.infiniteJump and not App.move and not App.flags.fly and not UIS:GetFocusedTextBox() then
        local _,h=App:Character();if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)
App:Connect(LP.Idled,function()
    if not App.flags.antiIdle then return end
    local vu=game:GetService("VirtualUser")
    pcall(function() vu:CaptureController();vu:ClickButton2(Vector2.new(0,0)) end)
end)
App.ready=true
App:Refresh()
task.spawn(function()
    while App.alive do
        local success,err=xpcall(function()
            if os.clock()>=(App.nextScan or 0) then App:Refresh() end
            local milestone=App:Module("Modules.Service.EventMilestoneService")
            local coins=App:Coins()
            local cannon={}
            for _,machine in ipairs(App.registry.cannons or {}) do
                if machine.Parent then table.insert(cannon,"F"..tostring(machine:GetAttribute("Floor")).." candy "..tostring(machine:GetAttribute("CandyValue") or 0)) end
            end
            local eventText="Spooky Coins: "..tostring(coins or "loading").." | "..#App:DropList(true).." drops"
            if milestone then eventText..="\nServer candy: "..milestone:GetCandy().." / 10000 | bonus x"..milestone:GetMultiplier().."\n"..table.concat(cannon," | ") end
            App:UIAccess()
            App.eventLabel:SetText(eventText)
            local lines={"v"..App.version.." | "..(App.status.adapter or "Waiting for tycoon")}
            local keys={} for key,on in pairs(App.flags) do if on then table.insert(keys,key) end end table.sort(keys)
            for _,key in ipairs(keys) do table.insert(lines,key..": "..(App.status[key] or "Ready")) end
            for key,text in pairs(App.status) do
                if not App.flags[key] and (text:match("^Paused") or text:match("^No replicated confirmation")) then
                    table.insert(lines,key..": "..text)
                end
            end
            for scope,request in pairs(Pending) do table.insert(lines,scope.." pending "..math.floor(os.clock()-request.started).."s") end
            if #keys==0 then table.insert(lines,"All automation OFF") end
            if App.status.diagnostics then table.insert(lines,"Diagnostics: "..App.status.diagnostics) end
            App.statusLabel:SetText(table.concat(lines,"\n"))
            App.resultLabel:SetText("Last confirmed result: "..App.lastResult)
            App.status.diagnostics=nil
        end,debug.traceback)
        if not success then App:Note("diagnostics",err) end
        task.wait(0.5)
    end
end)
win:Notify("Loaded. All automation OFF. RShift: menu | P: unload",4)
end
local built,buildError=xpcall(setupUI,debug.traceback)
if not built then warn("[Lemons] UI initialization failed: "..tostring(buildError));App:Unload();return end
return App
