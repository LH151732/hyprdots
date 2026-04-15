local state = { active = false, matches = {}, services = {} }

local function parse_services()
	local path = os.getenv("HOME") .. "/.config/yazi/vfs.toml"
	local file = io.open(path, "r")
	if not file then return {} end

	local services = {}
	for line in file:lines() do
		local name = line:match("^%[services%.(.+)%]$")
		if name then services[#services + 1] = name end
	end
	file:close()
	return services
end

local function fuzzy_match(query, name)
	if not query or query == "" then return true end
	query = query:lower()
	name = name:lower()
	local qi = 1
	for i = 1, #name do
		if name:sub(i, i) == query:sub(qi, qi) then
			qi = qi + 1
			if qi > #query then return true end
		end
	end
	return false
end

local update = ya.sync(function(_, matches, active)
	state.matches = matches
	state.active = active
	ui.render()
end)

local function setup()
	state.services = parse_services()

	local old_build = Tab.build
	Tab.build = function(self, ...)
		old_build(self, ...)

		if not state.active or #state.matches == 0 then return end

		local max_h = math.min(#state.matches, 13)
		local w = 50
		local x = math.max(0, math.floor((self._area.w - w) / 2))
		local y = 4
		local area = ui.Rect { x = x, y = y, w = w, h = max_h + 2 }
		local inner = ui.Rect { x = x + 1, y = y + 1, w = w - 2, h = max_h }

		local items = {}
		for i, name in ipairs(state.matches) do
			if i > max_h then break end
			local line = ui.Line(ui.Span(" " .. name))
			if i == 1 then
				line = ui.Line(ui.Span(" " .. name):style(ui.Style():fg("black"):bg("blue")))
			end
			items[#items + 1] = line
		end

		self._base = ya.list_merge(self._base or {}, {
			ui.Clear(area),
			ui.Border(ui.Edge.ALL):area(area):type(ui.Border.ROUNDED)
				:style(ui.Style():fg("blue")),
			ui.List(items):area(inner),
		})
	end
end

local function entry()
	local services = state.services
	if #services == 0 then
		services = parse_services()
		state.services = services
	end

	update(services, true)

	local input = ya.input {
		pos = { "top-center", w = 50, offset = { 0, 2 } },
		title = "SFTP",
		realtime = true,
		debounce = 0.1,
	}

	local final_value = ""
	while true do
		local value, event = input:recv()
		if not value then break end

		if event == 1 then
			final_value = value
			break
		elseif event == 2 then
			update({}, false)
			return
		end

		final_value = value
		local matches = {}
		for _, name in ipairs(services) do
			if fuzzy_match(value, name) then
				matches[#matches + 1] = name
			end
		end
		update(matches, true)
	end

	update({}, false)

	if final_value == "" then return end

	-- use top match if available, otherwise treat as direct address
	local target
	local matches = {}
	for _, name in ipairs(services) do
		if fuzzy_match(final_value, name) then
			matches[#matches + 1] = name
		end
	end

	if #matches > 0 then
		target = matches[1]
	else
		target = final_value
	end

	ya.emit("tab_create", { Url("sftp://" .. target) })
end

return { setup = setup, entry = entry }
