-- DNA R5 metadata inspection only: no HTTP, no gameplay changes, no attribution guesses.
local W=game:GetService('Workspace')
local P=game:GetService('Players')
local H=game:GetService('HttpService')
local gui=P.LocalPlayer:WaitForChild('PlayerGui')
assert(not gui:FindFirstChild('DNA_WEATHER_R5'),'R5 sudah terbuka')
local s=Instance.new('ScreenGui'); s.Name='DNA_WEATHER_R5'; s.ResetOnSpawn=false; s.Parent=gui
local b=Instance.new('TextButton'); b.Size=UDim2.new(0,340,0,65); b.Position=UDim2.new(0,15,0,340)
b.Text='R5 aktif: memeriksa Weather Potion\nKlik untuk berhenti'; b.TextWrapped=true; b.Parent=s
local active=true; local links={}; local seen=setmetatable({},{__mode='k'})
local queue={}; local head,tail=1,0; local records=0; local limited=false
local function log(k,t)
    if records>=4000 then
        if not limited then limited=true; tail=tail+1; queue[tail]='[DNA R5] LIMIT: 4000 records reached; inspection incomplete' end
        return
    end
    records=records+1; tail=tail+1
    queue[tail]='[DNA R5] '..os.date('!%Y-%m-%dT%H:%M:%SZ')..' | '..k..' | '..tostring(t):gsub('[\r\n]',' '):sub(1,1800)
end
local function ref(v)
    if typeof(v)=='Instance' then return v:GetFullName() end
    return tostring(v)
end
local function node(o)
    if seen[o] then return end; seen[o]=true
    local attrs=o:GetAttributes(); local names={}
    for k,v in pairs(attrs) do table.insert(names,k..'='..ref(v)) end
    if #names>0 then log('ATTRIBUTES',o:GetFullName()..' | '..table.concat(names,'; ')) end
    if o:IsA('ValueBase') then
        local ok,v=pcall(function() return o.Value end)
        if ok then log('VALUE',o:GetFullName()..' | '..ref(v)) end
    end
    if o:IsA('JointInstance') or o:IsA('WeldConstraint') then
        log('JOINT',o:GetFullName()..' | Part0='..ref(o.Part0)..' | Part1='..ref(o.Part1))
    end
    if o:IsA('Constraint') then
        pcall(function() log('CONSTRAINT',o:GetFullName()..' | Attachment0='..ref(o.Attachment0)..' | Attachment1='..ref(o.Attachment1)) end)
    end
    table.insert(links,o.AttributeChanged:Connect(function(key)
        if active then log('ATTRIBUTE_CHANGED',o:GetFullName()..' | '..key..'='..ref(o:GetAttribute(key))) end
    end))
end
local roots=setmetatable({},{__mode='k'})
local function inspect(root,reason)
    if roots[root] or not active then return end; roots[root]=true
    log('WEATHER_OBJECT',reason..' | '..root.ClassName..' | '..root:GetFullName())
    local ancestor=root
    for _=1,4 do
        if not ancestor then break end
        node(ancestor); ancestor=ancestor.Parent
    end
    table.insert(links,root.DescendantAdded:Connect(function(o)
        task.defer(function() if active and o.Parent then
            local ok,err=pcall(node,o); if not ok then log('ERROR',err) end
        end end)
    end))
    local children=root:GetDescendants()
    log('TREE_SIZE',#children)
    for i,o in ipairs(children) do
        if not active then return end
        if i>1500 then log('TREE_LIMIT','Only first 1500 descendants inspected'); break end
        local ok,err=pcall(node,o); if not ok then log('ERROR',err) end
        if i<=200 then log('NODE',o.ClassName..' | '..o:GetFullName()) end
    end
end
local function candidate(o)
    if o.Name=='Weather Potion' then
        task.defer(function() if active and o.Parent then inspect(o,'NEW') end end)
    end
end
table.insert(links,W.DescendantAdded:Connect(candidate))
log('START','Metadata only. No distance attribution. No potion required. Runs at most 5 minutes.')
local folder=W:FindFirstChild('CosmeticFolder')
local found=0
if folder then
    for _,o in ipairs(folder:GetDescendants()) do
        if o.Name=='Weather Potion' then found=found+1; inspect(o,'EXISTING') end
    end
end
log('INITIAL_DONE','Existing Weather Potion objects='..found..'; absence does not recover past objects')
local function stop()
    if not active then return end; active=false
    for _,c in ipairs(links) do c:Disconnect() end
    log('STOP','Records='..records..'; limitReached='..tostring(limited))
end
b.Activated:Connect(function() stop(); s:Destroy() end)
s.Destroying:Connect(stop)
task.delay(300,function() stop(); if s.Parent then b.Text='R5 selesai. Ekspor Roblox Output.\nKlik untuk menutup' end end)
task.spawn(function()
    while active or head<=tail do
        for _=1,10 do
            if head>tail then break end
            print(queue[head]); queue[head]=nil; head=head+1
        end
        if head>tail then queue={}; head=1; tail=0 end
        task.wait(0.1)
    end
end)
