ABOUT = {
  NAME          = "Freebox monitor",
  VERSION       = "2016.09.29",
  DESCRIPTION   = "Freebox/Alicebox v5 monitor",
  AUTHOR        = "@logread",
  COPYRIGHT     = "(c) 2016 logread",
  DOCUMENTATION = "https://github.com/999LV/DomoticzBridge/blob/master/README.md"
}
--[[

	2016-09-29	first alpha version

This program is free software: you can redistribute it and/or modify
it under the condition that it is for private or home useage and
this whole comment is reproduced in the source code file.
Commercial utilisation is not authorized without the appropriate
written agreement from "logread", contact by PM on http://forum.micasaverde.com/
This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

-]]

local http		= require "socket.http"

-- Luup device variables
local devNo                      -- our device number
local POLL_DELAY = 3600          -- number of seconds between remote polls. Default is hourly
local SID = {
  altui    = "urn:upnp-org:serviceId:altui1"  ,         -- Variables = 'DisplayLine1' and 'DisplayLine2'
  freebox  = "urn:upnp-org:serviceId:Freebox1",
  hag      = "urn:micasaverde-com:serviceId:HomeAutomationGateway1",
}

-- Freebox monitoring variables
local url = "http://mafreebox.freebox.fr/pub/fbx_info.txt"
local str_uptime = " Temps depuis la mise en route  "
local str_speed = "  Débit ATM              "
local str_noise = "  Marge de bruit         "
local str_att = "  Atténuation            "

-- Logread's utility functions

local function nicelog(message)
	local display = "Domoticz Bridge : %s"
	message = message or ""
	if type(message) == "table" then message = table.concat(message) end
	luup.log(string.format(display, message))
--	print(string.format(display, message))
end

-- Akbooer's LUUP utility functions modified

local function getVar (name, service, device)
  service = service or SID.freebox
  device = device or devNo
  local x = luup.variable_get (service, name, device)
  return x
end

local function setVar (name, value, service, device)
  service = service or SID.freebox
  device = device or devNo
  value = value or ""
  local old = luup.variable_get (service, name, device)
  if tostring(value) ~= old then
   luup.variable_set (service, name, value, device)
  end
end

-- Poll the freebox/alicebox for data
function pollfreebox()
	local uptime, speeddown, speedup, noisedown, noiseup, attdown, attup
	local displayline1, displayline2
	local start, finish, temp

	local data, retcode = http.request(url)
	local	err = (retcode ~=200)

	if err then  -- something wrong happpened (no freebox on network ?)
		data = nil
		displayline1 = "pas de Freebox/Alicebox v5 trouvée !"
		displayline2 = ""
	end

	if data then
		-- extract uptime
		_, start = string.find(data, str_uptime)
		finish = string.find(data, "\n", start)
		uptime = string.sub(data, start+1, finish-1) or "erreur"
		uptime = string.gsub(uptime, "jours", "j")
		uptime = string.gsub(uptime, "heures", "h")
		uptime = string.gsub(uptime, "minutes", "m")

		-- extract speeds
		_, start = string.find(data, str_speed)
		finish = string.find(data, "\n", start)
		temp = string.sub(data, start+1, finish-1) or "erreur"
		speeddown, speedup = string.match(string.gsub(temp, "(kb/s)%s+", ""), "(%d+) (%d+)")

		-- extracts noise
		_, start = string.find(data, str_noise)
		finish = string.find(data, "\n", start)
		temp = string.sub(data, start+1, finish-1) or "erreur"
		noisedown, noiseup = string.match(string.gsub(temp, "(dB)%s+", ""), "(%A+) (%A+)")

		-- extracts attenuation
		_, start = string.find(data, str_att)
		finish = string.find(data, "\n", start)
		temp = string.sub(data, start+1, finish-1) or "erreur"
		attdown, attup = string.match(string.gsub(temp, "(dB)%s+", ""), "(%A+) (%A+)")

		displayline1 = uptime
		displayline2 = string.format("D %d kb/s U %d kb/s", speeddown, speedup)
	end

	setVar("LastUpdate", os.time())
	setVar("Uptime", uptime)
	setVar("SpeedDown", speeddown)
	setVar("SpeedUp", speedup)
	setVar("NoiseDown", noisedown)
	setVar("NoiseUp", noiseup)
	setVar("AttenuationDown", attdown)
	setVar("AttenuationUp", attup)
	setVar("DisplayLine1", displayline1, SID.altui)
	setVar("DisplayLine2", displayline2, SID.altui)
end

-- the polling loop !
function pollbox()
	pollfreebox()
	luup.call_delay("pollbox", POLL_DELAY)
end

-- PLUGIN STARTUP

function init (lul_device)
	luup.log (ABOUT.NAME)
	luup.log (ABOUT.VERSION)
	devNo = lul_device
	do -- version number
		local y,m,d = ABOUT.VERSION:match "(%d+)%D+(%d+)%D+(%d+)"
		local version = ("v%d.%d.%d"): format (y%2000,m,d)
		setVar ("Version", version)
	end
	pollbox()
	return true, "OK", ABOUT.NAME
end

-----
