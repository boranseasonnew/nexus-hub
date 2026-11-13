import { readFile, writeFile, mkdir } from 'node:fs/promises';
import path from 'node:path';

const root = process.cwd();
const files = [
  'ui/Components', 'ui/Controls', 'ui/MainWindow', 'core/Scope',
  'core/SettingsManager', 'games/logic/BallTracker', 'games/logic/SpeedController', 'games/logic/CollisionTracker', 'games/logic/YARHMFling', 'games/logic/RoleData', 'games/BladeBall',
  'games/logic/AimPrediction', 'games/MM2', 'games/Universal', 'games/Doors'
];
const sources = new Map();
for (const id of files) {
  let source = await readFile(path.join(root, 'client', `${id}.luau`), 'utf8');
  source = source.replace(/require\(script((?:\.[A-Za-z][A-Za-z0-9_]*)+)\)/g, (_whole, suffix) => {
    let parts = id.split('/');
    for (const segment of suffix.slice(1).split('.')) {
      if (segment === 'Parent') parts.pop(); else parts.push(segment);
    }
    const target = parts.join('/');
    if (!files.includes(target)) throw new Error(`Missing dependency ${target} from ${id}`);
    return `nexusRequire(${JSON.stringify(target)})`;
  });
  if (/\bscript\b/.test(source.replace(/--[^\n]*/g, ''))) throw new Error(`Unresolved script reference in ${id}`);
  sources.set(id, source);
}
let output = '-- Nexus Hub local test bundle. Generated; do not edit directly.\nlocal factories, cache = {}, {}\nlocal nexusRequire\n';
for (const [id, source] of sources) output += `\nfactories[${JSON.stringify(id)}] = function()\n${source}\nend\n`;
output += `
nexusRequire = function(id)
    if cache[id] == nil then cache[id] = assert(factories[id], "Missing module: " .. id)() end
    return cache[id]
end
local player = game:GetService("Players").LocalPlayer
assert(player, "Nexus requires a client session")
local playerGui = player:WaitForChild("PlayerGui")
local env = type(getgenv) == "function" and getgenv() or nil
if env and type(env.NexusTestClose) == "function" then pcall(env.NexusTestClose) end
local UI = nexusRequire("ui/Components")
local Controls = nexusRequire("ui/Controls")
local Scope = nexusRequire("core/Scope")
local Settings = nexusRequire("core/SettingsManager")
local Window = nexusRequire("ui/MainWindow")
local id
if game.PlaceId == 13772394625 or game.GameId == 4777817887 then id = "bladeball"
elseif game.PlaceId == 142823291 or game.GameId == 66654135 then id = "mm2"
elseif game.PlaceId == 6516141723 or game.GameId == 2440500124 then id = "doors"
else id = "universal" end
local moduleNames = { bladeball = "games/BladeBall", mm2 = "games/MM2", doors = "games/Doors", universal = "games/Universal" }
local scope = Scope.new()
local screen = UI.make("ScreenGui", playerGui, { Name = "NexusHubLocalTest", ResetOnSpawn = false, DisplayOrder = 11, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
scope:add(function() screen:Destroy(); if env then env.NexusTestClose = nil end end)
if env then env.NexusTestClose = function() scope:close() end end
local settings = Settings.new(playerGui, id)
local window = Window.mount(screen, scope, settings)
local function showHub()
    local page, pageScope = window:page()
    local ok, err = pcall(function() nexusRequire(moduleNames[id]).mount({parent = page, scope = pageScope, settings = settings}) end)
    if not ok then pageScope:close(); window:notify("Module error: " .. tostring(err)); warn("Nexus module error:", err) end
end
window:tab("Hub", showHub)
window:tab("Settings", function()
    local page, pageScope = window:page()
    Controls.slider(page, pageScope, "Scale", settings:get("scale"), 0.8, 1.3, function(v) settings:set("scale", v); window:applySettings() end)
    local key = UI.input(page, "Window key, e.g. RightControl")
    key.Text = settings:get("hotkey")
    pageScope:connect(key.FocusLost, function()
        local text = string.lower(string.match(key.Text, "^%s*(.-)%s*$") or "")
        for _, code in ipairs(Enum.KeyCode:GetEnumItems()) do
            if code ~= Enum.KeyCode.Unknown and string.lower(code.Name) == text then settings:set("hotkey", code.Name); break end
        end
        key.Text = settings:get("hotkey")
    end)
end)
window:notify("Local test · " .. id .. " · RightControl toggles window")
showHub()
`;
await mkdir(path.join(root, 'dist'), { recursive: true });
await writeFile(path.join(root, 'dist', 'nexus-local-test.client.luau'), output);
console.log(`Built ${Buffer.byteLength(output)} bytes: dist/nexus-local-test.client.luau`);

