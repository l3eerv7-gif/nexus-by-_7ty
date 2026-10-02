local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")

if not Drawing or not Players.LocalPlayer then
	game:GetService("StarterGui"):SetCore("SendNotification", {
		Title = "Erreur",
		Text = "Mets le script dans StarterPlayerScripts (LocalScript).",
		Duration = 6,
	})
	return
end

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

Config = {
	-- Aimbot, Tir & Multi-Target Bullet TP
	AimEnabled        = false,
	KeyBind           = Enum.UserInputType.MouseButton2,
	KeyName           = "Clic Droit",
	Smooth            = 3,
	FOVdeg            = 140,
	TargetPart        = "Tête",
	FOVRing           = false,
	TriggerEnabled    = false,
	RapidFire         = false,
	MultiBulletTP     = false,
	NoSpread          = false,
	TeamCheck         = false, -- Désactivé par défaut pour éviter de bloquer l'ESP
	
	-- ESP
	ESPEnabled        = false,
	ShowBox           = false,
	ShowCorner        = false,
	ShowSkeleton      = false,
	ShowTracer        = false,
	ShowNametag       = false,
	MaxDist           = 500,
	
	-- Mouvements & Exploits
	FlyEnabled        = false,
	FlySpeed          = 50,
	SpeedHack         = false,
	SpeedValue        = 24,
	CarFly            = false,
	CarFlySpeed       = 80,
	SkinSwapper       = false,
	
	-- Paramètres
	ToggleKey         = Enum.KeyCode.RightShift,
	ToggleKeyName     = "RightShift",
	Theme             = "Violet",
}
Config.FOV = Config.FOVdeg

local aimbotActive = false
local bindingKey = false
local bindingToggleKey = false

local THEMES = {
	Violet = {
		panel   = Color3.fromRGB(26, 22, 38),
		border  = Color3.fromRGB(124, 66, 228),
		accent  = Color3.fromRGB(168, 120, 255),
		off     = Color3.fromRGB(40, 35, 54),
		offTxt  = Color3.fromRGB(160, 152, 190),
		onTxt   = Color3.new(1, 1, 1),
		header  = Color3.fromRGB(90, 60, 160),
	},
	Cyan = {
		panel   = Color3.fromRGB(18, 30, 38),
		border  = Color3.fromRGB(0, 180, 216),
		accent  = Color3.fromRGB(72, 202, 228),
		off     = Color3.fromRGB(28, 45, 58),
		offTxt  = Color3.fromRGB(140, 175, 195),
		onTxt   = Color3.new(1, 1, 1),
		header  = Color3.fromRGB(0, 119, 182),
	},
	Rouge = {
		panel   = Color3.fromRGB(38, 22, 22),
		border  = Color3.fromRGB(228, 66, 66),
		accent  = Color3.fromRGB(255, 120, 120),
		off     = Color3.fromRGB(54, 35, 35),
		offTxt  = Color3.fromRGB(190, 152, 152),
		onTxt   = Color3.new(1, 1, 1),
		header  = Color3.fromRGB(160, 60, 60),
	}
}

local COL = THEMES[Config.Theme]

-- Fonction Team Check robuste et flexible
local function isEnemy(player)
	if player == LocalPlayer then return false end
	if not Config.TeamCheck then return true end
	
	-- Si le jeu n'utilise pas de service Teams natif
	if #Players:GetTeams() == 0 then
		return true
	end
	
	if LocalPlayer.Team and player.Team then
		return LocalPlayer.Team ~= player.Team
	end
	
	return true
end

local function getTargets()
	local out = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if isEnemy(p) and p.Character then
			local char = p.Character
			local hum = char:FindFirstChildOfClass("Humanoid")
			local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
			local head = char:FindFirstChild("Head")
			
			if root and (not hum or hum.Health > 0) then
				table.insert(out, {
					Model = char,
					Humanoid = hum,
					RootPart = root,
					Head = head or root
				})
			end
		end
	end
	return out
end

local function getPlayerUnderCrosshair()
	local mousePos = UserInputService:GetMouseLocation()
	local ray = Camera:ViewportPointToRay(mousePos.X, mousePos.Y)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = RaycastType.Include
	
	local filterList = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LocalPlayer and p.Character then table.insert(filterList, p.Character) end
	end
	raycastParams.FilterDescendantsInstances = filterList
	
	local result = workspace:Raycast(ray.Origin, ray.Direction * 500, raycastParams)
	if result and result.Instance then
		local hitModel = result.Instance:FindFirstAncestorOfClass("Model")
		if hitModel then return Players:GetPlayerFromCharacter(hitModel) end
	end
	return nil
end

local function findPlayerByName(nameInput)
	local name = nameInput:gsub("^%s+", ""):gsub("%s+$", "")
	if name == "" then return nil end
	local target = Players:FindFirstChild(name)
	if target then return target end
	
	for _, p in ipairs(Players:GetPlayers()) do
		if string.lower(p.Name):sub(1, #name) == string.lower(name) then
			return p
		end
	end
	return nil
end

local function copySkin(targetPlayer)
	if not targetPlayer or not targetPlayer.Character then
		pcall(function()
			game:GetService("StarterGui"):SetCore("SendNotification", {
				Title = "Skin Swapper",
				Text = "Joueur introuvable.",
				Duration = 3,
			})
		end)
		return
	end
	pcall(function()
		local myChar = LocalPlayer.Character
		local targetChar = targetPlayer.Character
		if myChar and targetChar then
			local myHum = myChar:FindFirstChildOfClass("Humanoid")
			local targetHum = targetChar:FindFirstChildOfClass("Humanoid")
			
			for _, item in ipairs(myChar:GetChildren()) do
				if item:IsA("Accessory") or item:IsA("Shirt") or item:IsA("Pants")
					or item:IsA("ShirtGraphic") or item:IsA("CharacterMesh")
					or item:IsA("BodyColors") or item:IsA("Clothing") or item:IsA("Hat") then
					pcall(function() item:Destroy() end)
				end
			end

			if myHum and targetHum then
				pcall(function()
					local success, desc = pcall(function()
						return targetHum:GetAppliedDescription()
					end)
					if success and desc then
						myHum:ApplyDescription(desc)
					end
				end)
			end

			for _, item in ipairs(targetChar:GetChildren()) do
				if item:IsA("Accessory") or item:IsA("Shirt") or item:IsA("Pants")
					or item:IsA("ShirtGraphic") or item:IsA("BodyColors") or item:IsA("CharacterMesh") then
					pcall(function()
						local clone = item:Clone()
						clone.Parent = myChar
					end)
				end
			end

			pcall(function()
				local myHead = myChar:FindFirstChild("Head")
				local tHead = targetChar:FindFirstChild("Head")
				if myHead and tHead then
					for _, d in ipairs(myHead:GetChildren()) do
						if d:IsA("Decal") or d:IsA("SpecialMesh") then
							d:Destroy()
						end
					end
					for _, d in ipairs(tHead:GetChildren()) do
						if d:IsA("Decal") or d:IsA("SpecialMesh") then
							local c = d:Clone()
							c.Parent = myHead
						end
					end
				end
			end)

			pcall(function()
				game:GetService("StarterGui"):SetCore("SendNotification", {
					Title = "Skin Swapper",
					Text = "Skin appliqué : " .. targetPlayer.Name,
					Duration = 3,
				})
			end)
		end
	end)
end

local function crashServer()
	spawn(function()
		for i = 1, 5000 do
			pcall(function()
				local p = Instance.new("Part")
				p.Parent = workspace
				p:Destroy()
			end)
		end
	end)
end

UserInputService.InputBegan:Connect(function(input)
	if bindingKey then
		if input.UserInputType == Enum.UserInputType.Keyboard or input.UserInputType == Enum.UserInputType.MouseButton2 then
			Config.KeyBind = input.KeyCode ~= Enum.KeyCode.Unknown and input.KeyCode or input.UserInputType
			Config.KeyName = input.KeyCode ~= Enum.KeyCode.Unknown and input.KeyCode.Name or "Clic Droit"
			bindingKey = false
		end
		return
	end

	if bindingToggleKey then
		if input.KeyCode ~= Enum.KeyCode.Unknown then
			Config.ToggleKey = input.KeyCode
			Config.ToggleKeyName = input.KeyCode.Name
			bindingToggleKey = false
		end
		return
	end

	if input.KeyCode == Config.ToggleKey then
		screenGui.Enabled = not screenGui.Enabled
		return
	end

	if input.KeyCode == Enum.KeyCode.F5 and Config.SkinSwapper then
		local targetPlayer = getPlayerUnderCrosshair()
		if targetPlayer then copySkin(targetPlayer) end
	end

	if input.UserInputType == Config.KeyBind or input.KeyCode == Config.KeyBind then
		aimbotActive = true
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Config.KeyBind or input.KeyCode == Config.KeyBind then
		aimbotActive = false
	end
end)

-- Interface Graphique
screenGui = Instance.new("ScreenGui")
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn = false
screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local mainContainer = Instance.new("Frame")
mainContainer.Size = UDim2.fromOffset(1020, 440)
mainContainer.Position = UDim2.fromOffset(30, 30)
mainContainer.BackgroundTransparency = 1
mainContainer.Parent = screenGui

local function createColumn(posX, titleText)
	local colPanel = Instance.new("Frame")
	colPanel.Size = UDim2.fromOffset(240, 430)
	colPanel.Position = UDim2.fromOffset(posX, 0)
	colPanel.BackgroundColor3 = COL.panel
	colPanel.BackgroundTransparency = 0.08
	colPanel.BorderSizePixel = 2
	colPanel.BorderColor3 = COL.border
	colPanel.Parent = mainContainer

	local h = Instance.new("TextLabel")
	h.Size = UDim2.new(1, 0, 0, 28)
	h.BackgroundColor3 = COL.header
	h.BorderSizePixel = 0
	h.Text = "  " .. titleText
	h.TextXAlignment = Enum.TextXAlignment.Left
	h.TextColor3 = Color3.new(1, 1, 1)
	h.Font = Enum.Font.GothamBold
	h.TextSize = 13
	h.Parent = colPanel

	return colPanel
end

local col1 = createColumn(0, "COMBAT & TIR")
local col2 = createColumn(250, "ESP")
local col3 = createColumn(500, "MOUVEMENTS & EXPLOITS")
local col4 = createColumn(750, "PARAMÈTRES & DANGER")

local function addCheckboxCustom(parent, name, key, yRef, callback)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, -16, 0, 24)
	btn.Position = UDim2.fromOffset(8, yRef)
	btn.TextXAlignment = Enum.TextXAlignment.Left
	btn.Font = Enum.Font.Gotham
	btn.TextSize = 12
	btn.BorderSizePixel = 0
	
	local active = Config[key] == true
	btn.TextColor3 = active and COL.onTxt or COL.offTxt
	btn.BackgroundColor3 = active and COL.border or COL.off
	btn.Text = (active and "[X]" or "[  ]") .. "  " .. name
	btn.Parent = parent
	
	btn.MouseButton1Click:Connect(function()
		Config[key] = not Config[key]
		active = Config[key]
		btn.BackgroundColor3 = active and COL.border or COL.off
		btn.TextColor3 = active and COL.onTxt or COL.offTxt
		btn.Text = (active and "[X]" or "[  ]") .. "  " .. name
		if callback then callback(active) end
	end)
end

local function addSliderCustom(parent, name, key, min, max, step, yRef)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -16, 0, 14)
	label.Position = UDim2.fromOffset(8, yRef)
	label.BackgroundTransparency = 1
	label.Text = name .. " : " .. tostring(Config[key])
	label.TextColor3 = COL.offTxt
	label.Font = Enum.Font.Gotham
	label.TextSize = 11
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent

	local track = Instance.new("Frame")
	track.Size = UDim2.new(1, -16, 0, 5)
	track.Position = UDim2.fromOffset(8, yRef + 16)
	track.BackgroundColor3 = COL.off
	track.BorderSizePixel = 0
	track.Parent = parent

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale((Config[key] - min) / (max - min), 1)
	fill.BackgroundColor3 = COL.accent
	fill.BorderSizePixel = 0
	fill.Parent = track

	local dragging = false
	local function setFromMouse()
		local rel = math.clamp((UserInputService:GetMouseLocation().X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		Config[key] = math.clamp(math.round((min + rel * (max - min)) / step) * step, min, max)
		label.Text = name .. " : " .. tostring(Config[key])
		fill.Size = UDim2.fromScale(rel, 1)
	end
	track.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; setFromMouse() end
	end)
	UserInputService.InputChanged:Connect(function(i)
		if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then setFromMouse() end
	end)
	UserInputService.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
	end)
end

-- Colonne 1 : Combat
local y1 = 36
addCheckboxCustom(col1, "Aimbot Actif", "AimEnabled", y1); y1 = y1 + 27
addCheckboxCustom(col1, "Cercle FOV", "FOVRing", y1); y1 = y1 + 27
addCheckboxCustom(col1, "Team Check", "TeamCheck", y1); y1 = y1 + 27
addCheckboxCustom(col1, "TriggerBot", "TriggerEnabled", y1); y1 = y1 + 27
addCheckboxCustom(col1, "Rapid Fire (Manuel)", "RapidFire", y1); y1 = y1 + 27
addCheckboxCustom(col1, "Multi-Target TP", "MultiBulletTP", y1); y1 = y1 + 27
addCheckboxCustom(col1, "No Spread / No Recoil", "NoSpread", y1); y1 = y1 + 32

local targetBtn = Instance.new("TextButton")
targetBtn.Size = UDim2.new(1, -16, 0, 24)
targetBtn.Position = UDim2.fromOffset(8, y1)
targetBtn.Text = "Visée : " .. Config.TargetPart
targetBtn.TextXAlignment = Enum.TextXAlignment.Left
targetBtn.TextColor3 = COL.onTxt
targetBtn.Font = Enum.Font.Gotham
targetBtn.TextSize = 12
targetBtn.BackgroundColor3 = COL.border
targetBtn.BorderSizePixel = 0
targetBtn.Parent = col1
targetBtn.MouseButton1Click:Connect(function()
	if Config.TargetPart == "Tête" then Config.TargetPart = "Corps"
	elseif Config.TargetPart == "Corps" then Config.TargetPart = "Aléatoire"
	else Config.TargetPart = "Tête" end
	targetBtn.Text = "Visée : " .. Config.TargetPart
end)
y1 = y1 + 32

local bindBtn = Instance.new("TextButton")
bindBtn.Size = UDim2.new(1, -16, 0, 24)
bindBtn.Position = UDim2.fromOffset(8, y1)
bindBtn.Text = "Touche Lock : " .. Config.KeyName
bindBtn.TextXAlignment = Enum.TextXAlignment.Left
bindBtn.TextColor3 = COL.onTxt
bindBtn.Font = Enum.Font.Gotham
bindBtn.TextSize = 12
bindBtn.BackgroundColor3 = COL.border
bindBtn.BorderSizePixel = 0
bindBtn.Parent = col1
bindBtn.MouseButton1Click:Connect(function() bindingKey = true; bindBtn.Text = "Appuie..." end)
y1 = y1 + 32

addSliderCustom(col1, "Smooth Aimbot", "Smooth", 1, 10, 1, y1); y1 = y1 + 35
addSliderCustom(col1, "Taille FOV", "FOVdeg", 10, 180, 5, y1)

-- Colonne 2 : ESP
local y2 = 36
addCheckboxCustom(col2, "Maître ESP", "ESPEnabled", y2); y2 = y2 + 27
addCheckboxCustom(col2, "Boîte (Box)", "ShowBox", y2); y2 = y2 + 27
addCheckboxCustom(col2, "Corner Box", "ShowCorner", y2); y2 = y2 + 27
addCheckboxCustom(col2, "Skeleton", "ShowSkeleton", y2); y2 = y2 + 27
addCheckboxCustom(col2, "Tracer", "ShowTracer", y2); y2 = y2 + 27
addCheckboxCustom(col2, "Nametag & Distance", "ShowNametag", y2); y2 = y2 + 32
addSliderCustom(col2, "Distance Max", "MaxDist", 50, 2000, 50, y2)

-- Colonne 3 : Mouvements & Exploits
local y3 = 36
addCheckboxCustom(col3, "Fly (Joueur)", "FlyEnabled", y3); y3 = y3 + 27
addSliderCustom(col3, "Vitesse Vol", "FlySpeed", 20, 200, 10, y3); y3 = y3 + 35
addCheckboxCustom(col3, "Speedhack", "SpeedHack", y3); y3 = y3 + 27
addSliderCustom(col3, "Valeur Speed", "SpeedValue", 16, 100, 2, y3); y3 = y3 + 35
addCheckboxCustom(col3, "Car Fly", "CarFly", y3); y3 = y3 + 27
addSliderCustom(col3, "Vitesse Car Fly", "CarFlySpeed", 30, 200, 10, y3); y3 = y3 + 35

addCheckboxCustom(col3, "Skin Swapper (F5)", "SkinSwapper", y3); y3 = y3 + 27

local skinBox = Instance.new("TextBox")
skinBox.Size = UDim2.new(1, -16, 0, 24)
skinBox.Position = UDim2.fromOffset(8, y3)
skinBox.PlaceholderText = "Pseudo cible skin..."
skinBox.Text = ""
skinBox.TextXAlignment = Enum.TextXAlignment.Left
skinBox.TextColor3 = COL.onTxt
skinBox.PlaceholderColor3 = COL.offTxt
skinBox.Font = Enum.Font.Gotham
skinBox.TextSize = 11
skinBox.BackgroundColor3 = COL.off
skinBox.BorderSizePixel = 0
skinBox.ClearTextOnFocus = false
skinBox.Parent = col3
y3 = y3 + 28

local skinBtn = Instance.new("TextButton")
skinBtn.Size = UDim2.new(1, -16, 0, 26)
skinBtn.Position = UDim2.fromOffset(8, y3)
skinBtn.Text = "Appliquer Skin"
skinBtn.TextXAlignment = Enum.TextXAlignment.Left
skinBtn.TextColor3 = COL.onTxt
skinBtn.Font = Enum.Font.Gotham
skinBtn.TextSize = 11
skinBtn.BackgroundColor3 = COL.border
skinBtn.BorderSizePixel = 0
skinBtn.Parent = col3
skinBtn.MouseButton1Click:Connect(function()
	local target = findPlayerByName(skinBox.Text) or getPlayerUnderCrosshair()
	if target then copySkin(target) end
end)

-- Colonne 4 : Paramètres
local y4 = 36
local menuKeyBtn = Instance.new("TextButton")
menuKeyBtn.Size = UDim2.new(1, -16, 0, 24)
menuKeyBtn.Position = UDim2.fromOffset(8, y4)
menuKeyBtn.Text = "Touche Menu : " .. Config.ToggleKeyName
menuKeyBtn.TextXAlignment = Enum.TextXAlignment.Left
menuKeyBtn.TextColor3 = COL.onTxt
menuKeyBtn.Font = Enum.Font.Gotham
menuKeyBtn.TextSize = 12
menuKeyBtn.BackgroundColor3 = COL.border
menuKeyBtn.BorderSizePixel = 0
menuKeyBtn.Parent = col4
menuKeyBtn.MouseButton1Click:Connect(function() bindingToggleKey = true; menuKeyBtn.Text = "Appuie..." end)
y4 = y4 + 32

local themeBtn = Instance.new("TextButton")
themeBtn.Size = UDim2.new(1, -16, 0, 24)
themeBtn.Position = UDim2.fromOffset(8, y4)
themeBtn.Text = "Thème : " .. Config.Theme
themeBtn.TextXAlignment = Enum.TextXAlignment.Left
themeBtn.TextColor3 = COL.onTxt
themeBtn.Font = Enum.Font.Gotham
themeBtn.TextSize = 12
themeBtn.BackgroundColor3 = COL.border
themeBtn.BorderSizePixel = 0
themeBtn.Parent = col4

themeBtn.MouseButton1Click:Connect(function()
	if Config.Theme == "Violet" then Config.Theme = "Cyan"
	elseif Config.Theme == "Cyan" then Config.Theme = "Rouge"
	else Config.Theme = "Violet" end
	themeBtn.Text = "Thème : " .. Config.Theme
	COL = THEMES[Config.Theme]
	for _, c in ipairs({col1, col2, col3, col4}) do
		c.BackgroundColor3 = COL.panel
		c.BorderColor3 = COL.border
	end
end)
y4 = y4 + 35

local crashBtn = Instance.new("TextButton")
crashBtn.Size = UDim2.new(1, -16, 0, 30)
crashBtn.Position = UDim2.fromOffset(8, y4)
crashBtn.Text = "⚠ CRASH SERVER"
crashBtn.TextColor3 = Color3.new(1, 1, 1)
crashBtn.Font = Enum.Font.GothamBold
crashBtn.TextSize = 12
crashBtn.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
crashBtn.BorderSizePixel = 0
crashBtn.Parent = col4
crashBtn.MouseButton1Click:Connect(function()
	crashServer()
end)

-- Déplacement de la fenêtre
local draggingPanel, grabOffset = false, Vector2.zero
col1.InputBegan:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1 then
		draggingPanel = true
		grabOffset = UserInputService:GetMouseLocation() - mainContainer.AbsolutePosition
	end
end)
UserInputService.InputChanged:Connect(function(i)
	if draggingPanel and i.UserInputType == Enum.UserInputType.MouseMovement then
		local m = UserInputService:GetMouseLocation()
		mainContainer.Position = UDim2.fromOffset(m.X - grabOffset.X, m.Y - grabOffset.Y)
	end
end)
UserInputService.InputEnded:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1 then draggingPanel = false end
end)

-- Boucle principale ESP & Aimbot
local Drawings = {}
local function drawingSet(m)
	if Drawings[m] then return Drawings[m] end
	local lines = {}
	for i = 1, 40 do
		local l = Drawing.new("Line")
		l.Thickness = 1.5
		l.Color = COL.accent
		l.Visible = false
		table.insert(lines, l)
	end
	local text = Drawing.new("Text")
	text.Size = 13
	text.Center = true
	text.Color = Color3.new(1, 1, 1)
	text.Visible = false
	Drawings[m] = { lines = lines, text = text }
	m.AncestryChanged:Connect(function()
		if not m.Parent and Drawings[m] then
			for _, l in ipairs(Drawings[m].lines) do l:Remove() end
			Drawings[m].text:Remove()
			Drawings[m] = nil
		end
	end)
	return Drawings[m]
end

local ring = Drawing.new("Circle")
ring.Color = COL.accent
ring.Thickness = 1.5
ring.NumSides = 60
ring.Visible = false

local flyBv, flyBg
local carBv, carBg
local nextSpreadPatch = 0

local function patchSpreadClient()
	if not Config.NoSpread then return end
	pcall(function()
		local tools = {}
		if LocalPlayer.Character then
			local eq = LocalPlayer.Character:FindFirstChildOfClass("Tool")
			if eq then table.insert(tools, eq) end
		end
		local bp = LocalPlayer:FindFirstChild("Backpack")
		if bp then
			for _, t in ipairs(bp:GetChildren()) do
				if t:IsA("Tool") then table.insert(tools, t) end
			end
		end
		for _, tool in ipairs(tools) do
			for _, v in ipairs(tool:GetDescendants()) do
				if v:IsA("NumberValue") or v:IsA("IntValue") then
					local n = string.lower(v.Name)
					if n:find("spread") or n:find("recoil") or n:find("bloom") or n:find("kick") or n:find("shake") or n:find("sway") then
						v.Value = 0
					end
				end
			end
			for attrName, _ in pairs(tool:GetAttributes()) do
				local n = string.lower(attrName)
				if n:find("spread") or n:find("recoil") or n:find("bloom") or n:find("kick") then
					tool:SetAttribute(attrName, 0)
				end
			end
		end
	end)
end

local function hideDrawings(set)
	if not set then return end
	for _, l in ipairs(set.lines) do l.Visible = false end
	set.text.Visible = false
end

RunService.RenderStepped:Connect(function()
	ring.Color = COL.accent
	Config.FOV = Config.FOVdeg
	local center = Camera.ViewportSize / 2
	local camPos = Camera.CFrame.Position

	local char = LocalPlayer.Character
	local rootPart = char and char:FindFirstChild("HumanoidRootPart")
	local humChar = char and char:FindFirstChildOfClass("Humanoid")

	if Config.SpeedHack and humChar then
		humChar.WalkSpeed = Config.SpeedValue
	end

	if Config.FlyEnabled and rootPart then
		if not flyBv then
			flyBv = Instance.new("BodyVelocity")
			flyBv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
			flyBv.Velocity = Vector3.zero
			flyBv.Parent = rootPart
		end
		if not flyBg then
			flyBg = Instance.new("BodyGyro")
			flyBg.MaxTorque = Vector3.new(3e4, 3e4, 3e4)
			flyBg.P = 3000
			flyBg.Parent = rootPart
		end
		flyBg.CFrame = Camera.CFrame
		local moveDir = Vector3.zero
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + Camera.CFrame.LookVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - Camera.CFrame.LookVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - Camera.CFrame.RightVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + Camera.CFrame.RightVector end
		flyBv.Velocity = moveDir * Config.FlySpeed
	else
		if flyBv then flyBv:Destroy(); flyBv = nil end
		if flyBg then flyBg:Destroy(); flyBg = nil end
	end

	local currentVehicleRoot = nil
	if humChar and humChar.SeatPart then
		local seat = humChar.SeatPart
		local vehicleModel = seat.Parent
		if vehicleModel and vehicleModel:IsA("Model") then
			currentVehicleRoot = vehicleModel.PrimaryPart or vehicleModel:FindFirstChild("HumanoidRootPart") or seat
		end
	end

	if Config.CarFly and currentVehicleRoot then
		if not carBv then
			carBv = Instance.new("BodyVelocity")
			carBv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
			carBv.Velocity = Vector3.zero
			carBv.Parent = currentVehicleRoot
		end
		if not carBg then
			carBg = Instance.new("BodyGyro")
			carBg.MaxTorque = Vector3.new(3e4, 3e4, 3e4)
			carBg.P = 3000
			carBg.Parent = currentVehicleRoot
		end
		carBg.CFrame = Camera.CFrame
		local carMoveDir = Vector3.zero
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then carMoveDir = carMoveDir + Camera.CFrame.LookVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then carMoveDir = carMoveDir - Camera.CFrame.LookVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then carMoveDir = carMoveDir - Camera.CFrame.RightVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then carMoveDir = carMoveDir + Camera.CFrame.RightVector end
		carBv.Velocity = carMoveDir * Config.CarFlySpeed
	else
		if carBv then carBv:Destroy(); carBv = nil end
		if carBg then carBg:Destroy(); carBg = nil end
	end

	local bestTarget = nil
	local shortestDist = math.huge
	local mousePos = UserInputService:GetMouseLocation()
	local allVisibleTargets = {}

	for _, t in ipairs(getTargets()) do
		local partToAim = t.RootPart
		if Config.TargetPart == "Tête" then
			partToAim = t.Head
		elseif Config.TargetPart == "Aléatoire" then
			partToAim = (math.random(1, 2) == 1) and t.Head or t.RootPart
		end

		if partToAim then
			local screenPos, onScreen = Camera:WorldToViewportPoint(partToAim.Position)
			if onScreen then
				local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
				local maxR = Camera.ViewportSize.Y / 2 * (Config.FOVdeg / 140)
				if dist <= maxR then
					table.insert(allVisibleTargets, partToAim)
					if dist < shortestDist then
						shortestDist = dist
						bestTarget = partToAim
					end
				end
			end
		end
	end

	local isShootingEarly = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
	if Config.AimEnabled and aimbotActive and bestTarget then
		if Config.NoSpread and isShootingEarly then
			Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, bestTarget.Position)
		else
			local goalCFrame = CFrame.lookAt(Camera.CFrame.Position, bestTarget.Position)
			Camera.CFrame = Camera.CFrame:Lerp(goalCFrame, 1 / Config.Smooth)
		end
	end

	if Config.NoSpread and os.clock() >= nextSpreadPatch then
		nextSpreadPatch = os.clock() + 2
		task.spawn(patchSpreadClient)
	end

	if Config.TriggerEnabled and bestTarget and shortestDist < 15 then
		VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
		task.wait(0.02)
		VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
	end

	local isShooting = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
	if aimbotActive and isShooting then
		if Config.MultiBulletTP and #allVisibleTargets > 0 then
			task.spawn(function()
				VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
				task.wait(0.005)
				VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
			end)
		elseif Config.RapidFire and bestTarget then
			task.spawn(function()
				VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
				task.wait(0.01)
				VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
			end)
		end
	end

	if ring then
		if Config.FOVRing then
			ring.Visible = true
			ring.Radius = Camera.ViewportSize.Y / 2 * (Config.FOVdeg / 140)
			ring.Position = center
		else
			ring.Visible = false
		end
	end

	local activeModels = {}
	if Config.ESPEnabled then
		for _, t in ipairs(getTargets()) do activeModels[t.Model] = t end
	end

	for model, set in pairs(Drawings) do
		local hum = model:FindFirstChildOfClass("Humanoid")
		if not Config.ESPEnabled or not activeModels[model] or (hum and hum.Health <= 0) then
			hideDrawings(set)
		end
	end

	if Config.ESPEnabled then
		local skeletonR15 = {
			{"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
			{"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"}, {"LeftLowerArm", "LeftHand"},
			{"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"},
			{"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"}, {"LeftLowerLeg", "LeftFoot"},
			{"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"}, {"RightLowerLeg", "RightFoot"}
		}
		local skeletonR6 = {
			{"Head", "Torso"},
			{"Torso", "Left Arm"}, {"Torso", "Right Arm"},
			{"Torso", "Left Leg"}, {"Torso", "Right Leg"}
		}

		local function getLimb(model, name)
			local p = model:FindFirstChild(name, true)
			if p and p:IsA("BasePart") then return p end
			return nil
		end

		for _, t in ipairs(getTargets()) do
			local root = t.RootPart
			local head = t.Head
			local set = drawingSet(t.Model)

			hideDrawings(set)

			if root and head then
				local distToPlayer = (camPos - root.Position).Magnitude
				if distToPlayer <= Config.MaxDist then
					local topV, topOn = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.8, 0))
					local botV, botOn = Camera:WorldToViewportPoint(root.Position - Vector3.new(0, 2.5, 0))

					if topOn or botOn then
						local topPos = Vector2.new(topV.X, topV.Y)
						local botPos = Vector2.new(botV.X, botV.Y)
						
						local h = math.abs(topPos.Y - botPos.Y)
						local w = h * 0.5
						local lft = botPos.X - w / 2
						local rgt = botPos.X + w / 2

						local idx = 1
						local function addLine(from, to)
							if set.lines[idx] then
								set.lines[idx].Visible = true
								set.lines[idx].Color = COL.accent
								set.lines[idx].From = from
								set.lines[idx].To = to
								idx = idx + 1
							end
						end

						if Config.ShowBox then
							addLine(Vector2.new(lft, topPos.Y), Vector2.new(rgt, topPos.Y))
							addLine(Vector2.new(rgt, topPos.Y), Vector2.new(rgt, botPos.Y))
							addLine(Vector2.new(rgt, botPos.Y), Vector2.new(lft, botPos.Y))
							addLine(Vector2.new(lft, botPos.Y), Vector2.new(lft, topPos.Y))
						end

						if Config.ShowCorner then
							local cw, ch = w * 0.25, h * 0.25
							addLine(Vector2.new(lft, topPos.Y), Vector2.new(lft + cw, topPos.Y))
							addLine(Vector2.new(lft, topPos.Y), Vector2.new(lft, topPos.Y + ch))
							addLine(Vector2.new(rgt, topPos.Y), Vector2.new(rgt - cw, topPos.Y))
							addLine(Vector2.new(rgt, topPos.Y), Vector2.new(rgt, topPos.Y + ch))
							addLine(Vector2.new(lft, botPos.Y), Vector2.new(lft + cw, botPos.Y))
							addLine(Vector2.new(lft, botPos.Y), Vector2.new(lft, botPos.Y - ch))
							addLine(Vector2.new(rgt, botPos.Y), Vector2.new(rgt - cw, botPos.Y))
							addLine(Vector2.new(rgt, botPos.Y), Vector2.new(rgt, botPos.Y - ch))
						end

						if Config.ShowSkeleton then
							local pairsToUse = skeletonR15
							if getLimb(t.Model, "Torso") and not getLimb(t.Model, "UpperTorso") then
								pairsToUse = skeletonR6
							end
							for _, pair in ipairs(pairsToUse) do
								local p1 = getLimb(t.Model, pair[1])
								local p2 = getLimb(t.Model, pair[2])
								if p1 and p2 then
									local v1, o1 = Camera:WorldToViewportPoint(p1.Position)
									local v2, o2 = Camera:WorldToViewportPoint(p2.Position)
									if o1 or o2 then
										addLine(Vector2.new(v1.X, v1.Y), Vector2.new(v2.X, v2.Y))
									end
								end
							end
						end

						if Config.ShowTracer then
							addLine(Vector2.new(center.X, Camera.ViewportSize.Y), botPos)
						end

						if Config.ShowNametag then
							set.text.Visible = true
							set.text.Text = t.Model.Name .. " [" .. math.floor(distToPlayer) .. "m]"
							set.text.Position = Vector2.new(botPos.X, topPos.Y - 18)
						end
					end
				end
			end
		end
	end
end)
