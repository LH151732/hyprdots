-- rsync-paste: Use rsyncy for paste operations, with SFTP support
-- SFTP URL format in yazi: sftp://service-name//absolute/path

local get_yanked = ya.sync(function()
	local files = {}
	for _, url in pairs(cx.yanked) do
		files[#files + 1] = tostring(url)
	end
	return files, cx.yanked.is_cut
end)

local get_cwd = ya.sync(function()
	return tostring(cx.active.current.cwd)
end)

-- Parse vfs.toml into a table: { service_name = { host, user, port, key_file } }
local function load_vfs()
	local path = os.getenv("HOME") .. "/.config/yazi/vfs.toml"
	local file = io.open(path, "r")
	if not file then
		return {}
	end

	local services = {}
	local cur_name = nil

	for line in file:lines() do
		local name = line:match("^%[services%.(.+)%]$")
		if name then
			cur_name = name
			services[cur_name] = { port = "22" }
		elseif cur_name then
			local k, v = line:match('^(%w+)%s*=%s*"(.+)"$')
			if k then
				services[cur_name][k] = v
			else
				local kn, vn = line:match("^(%w+)%s*=%s*(%d+)%s*$")
				if kn then
					services[cur_name][kn] = vn
				end
			end
		end
	end

	file:close()
	return services
end

-- Parse SFTP URL: sftp://service-name//absolute/path -> { service, path }
local function parse_sftp_url(url)
	if not url:match("^sftp://") then
		return nil
	end
	local rest = url:sub(8) -- strip "sftp://"
	-- service-name followed by / then the absolute path
	local service, path = rest:match("^([^/]+)(/.*)$")
	if service then
		return { service = service, path = path }
	end
	return nil
end

-- Resolve SFTP URL to connection info
-- Supports both: sftp://service-name//path and sftp://user@host:port/path
local function resolve_sftp(url, vfs)
	local parsed = parse_sftp_url(url)
	if not parsed then
		return nil
	end

	-- Try vfs.toml lookup first
	local svc = vfs[parsed.service]
	if svc then
		return {
			service = parsed.service,
			path = parsed.path,
			host = svc.host,
			user = svc.user,
			port = tostring(svc.port or "22"),
			key_file = svc.key_file,
		}
	end

	-- Fallback: parse service field as user@host:port
	local domain = parsed.service
	local user, host, port

	-- user@host:port
	user, host, port = domain:match("^([^@]+)@([^:]+):(%d+)$")
	if not user then
		-- user@host
		user, host = domain:match("^([^@]+)@(.+)$")
		port = "22"
	end

	if user and host then
		return {
			service = domain,
			path = parsed.path,
			host = host,
			user = user,
			port = port,
			key_file = nil,
		}
	end

	return nil
end

-- Build SSH options string for rsync -e
local function ssh_opts(info)
	local parts = { "ssh" }
	if info.port and info.port ~= "22" then
		parts[#parts + 1] = "-p " .. info.port
	end
	if info.key_file then
		parts[#parts + 1] = "-i " .. info.key_file
	end
	if #parts == 1 then
		return nil
	end
	return table.concat(parts, " ")
end

-- Format remote path for rsync: user@host:path
local function remote_path(info)
	return info.user .. "@" .. info.host .. ":" .. info.path
end

return {
	entry = function()
		local files, is_cut = get_yanked()
		if #files == 0 then
			return ya.notify({ title = "Rsync Paste", content = "No yanked files", level = "warn", timeout = 3 })
		end

		local cwd = get_cwd()
		local vfs = load_vfs()

		-- Check if URLs are SFTP but unresolvable
		local src_is_sftp = files[1]:match("^sftp://") ~= nil
		local dst_is_sftp = cwd:match("^sftp://") ~= nil

		local dst_info = dst_is_sftp and resolve_sftp(cwd, vfs) or nil
		local src_info = src_is_sftp and resolve_sftp(files[1], vfs) or nil

		if src_is_sftp and not src_info then
			local parsed = parse_sftp_url(files[1])
			return ya.notify({
				title = "Rsync Paste",
				content = "Cannot resolve SFTP: " .. (parsed and parsed.service or files[1]),
				level = "error",
				timeout = 5,
			})
		end
		if dst_is_sftp and not dst_info then
			local parsed = parse_sftp_url(cwd)
			return ya.notify({
				title = "Rsync Paste",
				content = "Cannot resolve SFTP: " .. (parsed and parsed.service or cwd),
				level = "error",
				timeout = 5,
			})
		end

		-- Validate: all source files must be from the same host
		if src_is_sftp then
			for i = 2, #files do
				local info = resolve_sftp(files[i], vfs)
				if not info or info.host ~= src_info.host or info.user ~= src_info.user then
					return ya.notify({
						title = "Rsync Paste",
						content = "All source files must be from the same server",
						level = "error",
						timeout = 5,
					})
				end
			end
		end

		-- SFTP->SFTP different hosts: not supported
		if src_is_sftp and dst_is_sftp and src_info.host ~= dst_info.host then
			return ya.notify({
				title = "Rsync Paste",
				content = "Cross-host SFTP transfer not supported",
				level = "error",
				timeout = 5,
			})
		end

		-- Build command
		local c

		if not src_is_sftp and not dst_is_sftp then
			-- Local -> Local
			local args = { "-ahP" }
			if is_cut then
				args[#args + 1] = "--remove-source-files"
			end
			c = Command("rsyncy"):arg(args)
			for _, f in ipairs(files) do
				c = c:arg(f)
			end
			c = c:arg(cwd .. "/")

		elseif not src_is_sftp and dst_is_sftp then
			-- Local -> SFTP
			local ssh = ssh_opts(dst_info)
			local args = { "-ahP" }
			if ssh then
				args[#args + 1] = "-e"
				args[#args + 1] = ssh
			end
			if is_cut then
				args[#args + 1] = "--remove-source-files"
			end
			c = Command("rsyncy"):arg(args)
			for _, f in ipairs(files) do
				c = c:arg(f)
			end
			c = c:arg(dst_info.user .. "@" .. dst_info.host .. ":" .. dst_info.path .. "/")

		elseif src_is_sftp and not dst_is_sftp then
			-- SFTP -> Local
			local ssh = ssh_opts(src_info)
			local args = { "-ahP" }
			if ssh then
				args[#args + 1] = "-e"
				args[#args + 1] = ssh
			end
			if is_cut then
				args[#args + 1] = "--remove-source-files"
			end
			c = Command("rsyncy"):arg(args)
			for _, f in ipairs(files) do
				local info = resolve_sftp(f, vfs)
				c = c:arg(remote_path(info))
			end
			c = c:arg(cwd .. "/")

		else
			-- SFTP -> SFTP (same host)
			local remote_args = { "rsync", "-ahP" }
			if is_cut then
				remote_args[#remote_args + 1] = "--remove-source-files"
			end
			for _, f in ipairs(files) do
				local info = resolve_sftp(f, vfs)
				remote_args[#remote_args + 1] = "'" .. info.path:gsub("'", "'\\''") .. "'"
			end
			remote_args[#remote_args + 1] = "'" .. dst_info.path:gsub("'", "'\\''") .. "/'"
			local remote_cmd = table.concat(remote_args, " ")

			local ssh_args = {}
			if src_info.port ~= "22" then
				ssh_args[#ssh_args + 1] = "-p"
				ssh_args[#ssh_args + 1] = src_info.port
			end
			if src_info.key_file then
				ssh_args[#ssh_args + 1] = "-i"
				ssh_args[#ssh_args + 1] = src_info.key_file
			end
			c = Command("ssh"):arg(ssh_args)
				:arg(src_info.user .. "@" .. src_info.host)
				:arg(remote_cmd)
		end

		-- Hide yazi UI and run in terminal so user sees rsyncy progress
		local _permit = ui.hide()
		local child, err = c:stdin(Command.INHERIT):stdout(Command.INHERIT):stderr(Command.INHERIT):spawn()
		if not child then
			ya.notify({
				title = "Rsync Paste",
				content = "Failed to spawn: " .. (err or "unknown error"),
				level = "error",
				timeout = 5,
			})
			return
		end
		local status = child:wait()

		if status and status.success then
			ya.notify({
				title = "Rsync Paste",
				content = string.format("Done! %d file(s) %s", #files, is_cut and "moved" or "copied"),
				timeout = 3,
			})
			ya.mgr_emit("unyank", {})
		else
			ya.notify({
				title = "Rsync Paste",
				content = string.format("Failed (exit %s)", status and status.code or "?"),
				level = "error",
				timeout = 10,
			})
		end
	end,
}
