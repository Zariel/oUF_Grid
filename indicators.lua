local _G = getfenv(0)
local oUF = _G.oufgrid or _G.oUF

if(not oUF) then
	return error("oUF_Grid requires oUF")
end

local indicators = {}


