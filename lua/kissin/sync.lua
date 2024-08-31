local M = {}
local utils = require("kissin.utils")

local sync_timer = nil
local had_sync_failure = false

local function should_sync()
	local config = vim.g.kissin_config
	if config and config.dir_path then
		local cwd = vim.fn.getcwd()
		if utils.is_in_dir_path(cwd, config.dir_path) then
			return true
		end

		for _, buf in ipairs(vim.api.nvim_list_bufs()) do
			if vim.api.nvim_buf_is_loaded(buf) then
				local buf_name = vim.api.nvim_buf_get_name(buf)
				if utils.is_in_dir_path(buf_name, config.dir_path) then
					return true
				end
			end
		end
	end
	return false
end

local function sync_repo(dir_path)
	-- Function to run git commands in the specified directory
	local function git_command(cmd)
		return vim.fn.system(string.format("cd %s && %s", vim.fn.shellescape(dir_path), cmd))
	end

	-- Check for uncommitted changes
	local status = git_command("git status --porcelain")
	if status ~= "" then
		local commit_result = git_command("git commit -am 'Auto-commit by Kissin'")
		if vim.v.shell_error ~= 0 then
			utils.notify("Error committing changes: " .. commit_result, vim.log.levels.ERROR)
			return false
		end
	end

	-- Fetch the latest changes
	local fetch_result = git_command("git fetch")
	if vim.v.shell_error ~= 0 then
		return false
	end

	-- Check if we're behind the remote
	local behind_check = git_command("git rev-list HEAD..@{u} --count")
	if tonumber(behind_check) > 0 then
		local pull_result = git_command("git pull --rebase")
		if vim.v.shell_error ~= 0 then
			utils.notify("Cannot rebase. There might be a merge conflict.", vim.log.levels.ERROR)
			utils.notify("Please resolve conflicts manually and then run :KissinSync", vim.log.levels.INFO)
			return false
		end
	end

	-- Push changes to remote
	local push_result = git_command("git push")
	if vim.v.shell_error ~= 0 then
		return false
	end

	return true
end

function M.perform_sync()
	local config = vim.g.kissin_config
	if config and config.dir_path and should_sync() then
		local success = sync_repo(config.dir_path)
		if success then
			if had_sync_failure then
				utils.notify("Repository synced successfully after previous failure.", vim.log.levels.INFO)
				had_sync_failure = false
			end
		else
			if not had_sync_failure then
				utils.notify("Sync failed. Will retry in background.", vim.log.levels.WARN)
				had_sync_failure = true
			end
		end
	else
		M.stop_sync()
	end
end

function M.start_sync()
	if not sync_timer then
		sync_timer = vim.loop.new_timer()
		sync_timer:start(0, 60000, vim.schedule_wrap(M.perform_sync)) -- Sync every 60 seconds
	end
end

function M.stop_sync()
	if sync_timer then
		sync_timer:stop()
		sync_timer = nil
	end
end

function M.check_and_sync(immediate)
	if should_sync() then
		if immediate then
			M.perform_sync()
		end
		M.start_sync()
	else
		M.stop_sync()
	end
end

return M
