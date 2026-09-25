-- DataStoreSafe.luau  (ModuleScript, shared)
--
-- DataStoreService:GetDataStore() THROWS when the place is unpublished or when
-- "Enable Studio Access to API Services" is off. Called at the top of a server
-- script, that single exception kills the ENTIRE script - including every
-- :Connect() further down. The remotes still exist, so the client finds them
-- and fires them, but nobody is listening and the game loads forever with no
-- visible error. One unguarded line took down all ten games this way.
--
-- Get() never throws. When DataStores are unreachable it returns an inert stub
-- whose methods do nothing and return nil, so existing call sites need no
-- changes and the script survives to connect its handlers. Saving is lost for
-- that session; the game still runs.

local DataStoreService = game:GetService("DataStoreService")

local DataStoreSafe = {}

local function noop()
	return nil
end

-- Same shape as a real GlobalDataStore, but inert. Methods ignore their
-- arguments (including `self`) and return nil.
local STUB = {
	GetAsync          = noop,
	SetAsync          = noop,
	RemoveAsync       = noop,
	IncrementAsync    = noop,
	UpdateAsync       = noop,
	GetSortedAsync    = noop,
	ListKeysAsync     = noop,
	GetVersionAsync   = noop,
	ListVersionsAsync = noop,
}

local warned = false

-- Returns the real DataStore, or an inert stub. Never throws, never yields
-- long, never nil.
function DataStoreSafe.Get(name, scope)
	local ok, store = pcall(function()
		if scope then
			return DataStoreService:GetDataStore(name, scope)
		end
		return DataStoreService:GetDataStore(name)
	end)

	if ok and store then
		return store
	end

	if not warned then
		warned = true
		warn("[DataStoreSafe] DataStores unreachable - saving is disabled this "
			.. "session, but the games will still run. Publish the place and turn on "
			.. "Game Settings > Security > Enable Studio Access to API Services. ("
			.. tostring(store) .. ")")
	end
	return STUB
end

-- True when real DataStores are reachable. Useful to skip persistence work
-- entirely instead of writing into the void.
function DataStoreSafe.IsAvailable()
	local ok = pcall(function()
		return DataStoreService:GetDataStore("DataStoreSafe_Probe_v1")
	end)
	return ok
end

return DataStoreSafe
