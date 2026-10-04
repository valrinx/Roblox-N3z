-- N3Z Hypershot | all gameplay features default OFF
return function(Window, ctx)
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local UIS = game:GetService("UserInputService")
    local Workspace = game:GetService("Workspace")
    local LocalPlayer = Players.LocalPlayer
    local env = getgenv and getgenv() or _G
    if type(env.__N3Z_HYPERSHOT) == "table" and type(env.__N3Z_HYPERSHOT.Destroy) == "function" then
        pcall(env.__N3Z_HYPERSHOT.Destroy)
    end
    local running, connections, drawings = true, {}, {}
    local settings = {
        aim=false, trigger=false, esp=false, fovCircle=false, diagnostics=false,
        wallCheck=true, teamCheck=true, targetPart="Head", fov=140, smoothness=0.22,
        triggerDelay=0.03, prediction=false, projectileSpeed=700, gravity=0,
        showNames=true, showDistance=true, showHealth=true, showWeapon=true,
    }
    local state = {target=nil, targetPart=nil, visible=false, weapon="Unknown", speed=0, reason="Idle"}
    local function connect(sig, fn)
        local c=sig:Connect(fn); connections[#connections+1]=c; return c
    end
    local function camera() return Workspace.CurrentCamera end
    local function center(cam)
        local v=cam.ViewportSize; return Vector2.new(v.X*0.5,v.Y*0.5)
    end
    local function isEnemy(plr)
        if not settings.teamCheck then return true end
        if LocalPlayer.Team and plr.Team then return LocalPlayer.Team ~= plr.Team end
        local a,b=LocalPlayer:GetAttribute("TeamID"),plr:GetAttribute("TeamID")
        return a==nil or b==nil or a~=b
    end
    local function alivePart(plr)
        local ch=plr.Character
        local hum=ch and ch:FindFirstChildOfClass("Humanoid")
        if not ch or not hum or hum.Health<=0 then return nil end
        return ch:FindFirstChild(settings.targetPart) or ch:FindFirstChild("Head")
            or ch:FindFirstChild("UpperTorso") or ch:FindFirstChild("HumanoidRootPart")
    end
    local function visible(cam,ch,part)
        if not settings.wallCheck then return true end
        local p=RaycastParams.new(); p.FilterType=Enum.RaycastFilterType.Exclude
        p.FilterDescendantsInstances={LocalPlayer.Character,cam}
        local hit=Workspace:Raycast(cam.CFrame.Position,part.Position-cam.CFrame.Position,p)
        return hit==nil or hit.Instance:IsDescendantOf(ch)
    end
    local function predicted(part)
        if not settings.prediction then return part.Position end
        local cam=camera(); if not cam then return part.Position end
        local t=(part.Position-cam.CFrame.Position).Magnitude/math.max(settings.projectileSpeed,1)
        return part.Position+part.AssemblyLinearVelocity*t+Vector3.new(0,0.5*settings.gravity*t*t,0)
    end
    local function acquire()
        local cam=camera(); if not cam then return nil end
        local c,best,bestD=center(cam),nil,settings.fov
        for _,plr in ipairs(Players:GetPlayers()) do
            if plr~=LocalPlayer and isEnemy(plr) then
                local part=alivePart(plr)
                if part then
                    local pos=predicted(part)
                    local s,on=cam:WorldToViewportPoint(pos)
                    local d=(Vector2.new(s.X,s.Y)-c).Magnitude
                    if on and s.Z>0 and d<bestD and visible(cam,plr.Character,part) then
                        bestD,best=d,{player=plr,part=part,position=pos}
                    end
                end
            end
        end
        return best
    end
    local function moveAim(t)
        local cam=camera(); if not cam or not t then return end
        local s=cam:WorldToViewportPoint(t.position)
        local d=Vector2.new(s.X,s.Y)-center(cam)
        local mover=ctx.platformAdapter and ctx.platformAdapter.mousemoverel
        if type(mover)=="function" then mover(d.X*settings.smoothness,d.Y*settings.smoothness) end
    end
    local function triggerCheck()
        local cam=camera(); if not cam then return false end
        local c=center(cam); local ray=cam:ViewportPointToRay(c.X,c.Y)
        local p=RaycastParams.new(); p.FilterType=Enum.RaycastFilterType.Exclude
        p.FilterDescendantsInstances={LocalPlayer.Character,cam}
        local hit=Workspace:Raycast(ray.Origin,ray.Direction*2500,p)
        if not hit then state.reason="No target"; return false end
        local ch=hit.Instance:FindFirstAncestorOfClass("Model")
        local plr=ch and Players:GetPlayerFromCharacter(ch)
        if not plr or plr==LocalPlayer or not isEnemy(plr) then state.reason="Blocked/team"; return false end
        state.reason="Target under crosshair"; return true
    end
    local function fireOnce()
        local press=ctx.platformAdapter and ctx.platformAdapter.mouse1press
        local release=ctx.platformAdapter and ctx.platformAdapter.mouse1release
        if type(press)=="function" and type(release)=="function" then
            press(); task.wait(0.01); release()
        end
    end
    local lastTrigger=0
    connect(RunService.RenderStepped,function()
        if not running then return end
        local t=(settings.aim or settings.diagnostics) and acquire() or nil
        state.target=t and t.player.Name or nil
        state.targetPart=t and t.part.Name or nil
        state.visible=t~=nil
        if settings.aim and UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then moveAim(t) end
        if settings.trigger and os.clock()-lastTrigger>=settings.triggerDelay and triggerCheck() then
            lastTrigger=os.clock(); task.spawn(fireOnce)
        end
        local ch=LocalPlayer.Character; local root=ch and ch:FindFirstChild("HumanoidRootPart")
        state.speed=root and root.AssemblyLinearVelocity.Magnitude or 0
    end)
    local Combat=Window:CreateTab("Combat","crosshair")
    Combat:CreateSection("Aim & Trigger")
    Combat:CreateToggle({Name="Aimbot (Hold RMB)",CurrentValue=false,Flag="HS_Aim",Callback=function(v) settings.aim=v end})
    Combat:CreateToggle({Name="Triggerbot",CurrentValue=false,Flag="HS_Trigger",Callback=function(v) settings.trigger=v end})
    Combat:CreateToggle({Name="Projectile Prediction",CurrentValue=false,Flag="HS_Predict",Callback=function(v) settings.prediction=v end})
    Combat:CreateToggle({Name="Visibility Check",CurrentValue=true,Flag="HS_Wall",Callback=function(v) settings.wallCheck=v end})
    Combat:CreateToggle({Name="Team Check",CurrentValue=true,Flag="HS_Team",Callback=function(v) settings.teamCheck=v end})
    Combat:CreateDropdown({Name="Target Part",Options={"Head","UpperTorso","HumanoidRootPart"},CurrentOption={"Head"},Flag="HS_Part",Callback=function(v) settings.targetPart=type(v)=="table" and v[1] or v end})
    Combat:CreateSlider({Name="FOV",Range={30,500},Increment=5,CurrentValue=140,Flag="HS_FOV",Callback=function(v) settings.fov=v end})
    Combat:CreateSlider({Name="Aim Smoothness",Range={5,100},Increment=1,CurrentValue=22,Suffix="%",Flag="HS_Smooth",Callback=function(v) settings.smoothness=v/100 end})
    Combat:CreateSlider({Name="Trigger Delay",Range={0,250},Increment=5,CurrentValue=30,Suffix=" ms",Flag="HS_TrigDelay",Callback=function(v) settings.triggerDelay=v/1000 end})
    local Visuals=Window:CreateTab("Visuals","eye")
    Visuals:CreateSection("Overlay")
    Visuals:CreateToggle({Name="Player ESP",CurrentValue=false,Flag="HS_ESP",Callback=function(v) settings.esp=v end})
    Visuals:CreateToggle({Name="FOV Circle",CurrentValue=false,Flag="HS_FOVCircle",Callback=function(v) settings.fovCircle=v end})
    local Player=Window:CreateTab("Player","user")
    Player:CreateSection("Telemetry")
    local speedLabel=Player:CreateParagraph({Title="Movement Speed",Content="0 studs/s"})
    local weaponLabel=Player:CreateParagraph({Title="Weapon",Content="Unknown"})
    local Diagnostics=Window:CreateTab("Diagnostics","tools")
    Diagnostics:CreateSection("Aim / Trigger")
    Diagnostics:CreateToggle({Name="Enable Diagnostics",CurrentValue=false,Flag="HS_Diag",Callback=function(v) settings.diagnostics=v end})
    local targetLabel=Diagnostics:CreateParagraph({Title="Target",Content="None"})
    local triggerLabel=Diagnostics:CreateParagraph({Title="Trigger",Content="Idle"})
    task.spawn(function()
        while running do
            pcall(function()
                if speedLabel and speedLabel.SetDesc then speedLabel:SetDesc(string.format("%.1f studs/s",state.speed)) end
                if weaponLabel and weaponLabel.SetDesc then weaponLabel:SetDesc(state.weapon) end
                if targetLabel and targetLabel.SetDesc then targetLabel:SetDesc(state.target and (state.target.." / "..tostring(state.targetPart)) or "None") end
                if triggerLabel and triggerLabel.SetDesc then triggerLabel:SetDesc(state.reason) end
            end)
            task.wait(0.25)
        end
    end)
    local function cleanup()
        running=false
        for _,c in ipairs(connections) do pcall(function() c:Disconnect() end) end
        table.clear(connections)
        for _,d in ipairs(drawings) do pcall(function() d.Visible=false; d:Remove() end) end
        table.clear(drawings)
        env.__N3Z_HYPERSHOT=nil
    end
    env.__N3Z_HYPERSHOT={Destroy=cleanup,Settings=settings,State=state}
    return {Cleanup=cleanup}
end
