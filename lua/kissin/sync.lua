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

local function sync_repo(dir_path, callback)
	local function git_command(cmd, on_exit)
		local full_cmd = string.format("cd %s && %s", vim.fn.shellescape(dir_path), cmd)
		local output = {}
		vim.fn.jobstart(full_cmd, {
			on_stdout = function(_, data)
				if data then
					vim.list_extend(output, data)
				end
			end,
			on_exit = function(_, exit_code)
				-- Remove empty strings and join the output
				local final_output = table.concat(
					vim.tbl_filter(function(line)
						return line ~= ""
					end, output),
					"\n"
				)
				on_exit(exit_code == 0, final_output)
			end,
		})
	end

	local function handle_push()
		git_command("git push", function(success)
			callback(success)
		end)
	end

	local function handle_pull()
		git_command("git rev-list HEAD..@{u} --count", function(success, output)
			if success then
				local behind = tonumber(output)
				if behind and behind > 0 then
					git_command("git pull", function(pull_success, pull_output)
						-- Update all buffers regardless of pull success
						for _, buf in ipairs(vim.api.nvim_list_bufs()) do
							if vim.api.nvim_buf_is_loaded(buf) then
								local bufname = vim.api.nvim_buf_get_name(buf)
								if utils.is_in_dir_path(bufname, vim.g.kissin_config.dir_path) then
									vim.api.nvim_buf_call(buf, function()
										vim.cmd("checktime")
									end)
								end
							end
						end

						if pull_success then
							handle_push()
						else
							utils.notify("Pull failed. There might be merge conflicts.", vim.log.levels.ERROR)
							utils.notify(pull_output, vim.log.levels.DEBUG)
							utils.notify(
								"Please resolve conflicts manually and then run :KissinSync",
								vim.log.levels.INFO
							)
							callback(false)
						end
					end)
				else
					handle_push()
				end
			else
				utils.notify("Failed to check if behind remote", vim.log.levels.ERROR)
				callback(false)
			end
		end)
	end

	local function handle_fetch()
		git_command("git fetch", function(success)
			if success then
				handle_pull()
			else
				callback(false)
			end
		end)
	end

	local function handle_commit()
		git_command("git status --porcelain", function(success, status_output)
			if success and status_output ~= "" then
				git_command("git add -A", function(add_success)
					if add_success then
						git_command("git commit -m 'Auto-commit by Kissin'", function(commit_success)
							if not commit_success then
								utils.notify("Error committing changes", vim.log.levels.ERROR)
								callback(false)
							else
								handle_fetch()
							end
						end)
					else
						utils.notify("Error staging changes", vim.log.levels.ERROR)
						callback(false)
					end
				end)
			else
				handle_fetch()
			end
		end)
	end

	handle_commit()
end

function M.perform_sync(manual)
	if manual == nil then
		manual = false
	end
	local config = vim.g.kissin_config
	if config and config.dir_path then
		sync_repo(config.dir_path, function(success)
			if success then
				if had_sync_failure then
					utils.notify("Repository synced successfully after previous failure.", vim.log.levels.INFO)
					had_sync_failure = false
				end
			else
				if manual or not had_sync_failure then
					utils.notify("Sync failed. Will retry in background.", vim.log.levels.WARN)
					had_sync_failure = true
				end
			end
		end)
	else
		M.stop_sync()
	end
end

function M.sync_interval()
	local config = vim.g.kissin_config
	if config and config.dir_path and should_sync() then
		M.perform_sync()
	end
end

function M.start_sync()
	if not sync_timer then
		sync_timer = vim.loop.new_timer()
		sync_timer:start(0, 60000, vim.schedule_wrap(M.sync_interval)) -- Sync every 60 seconds
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
		vim.notify("syincing")
		if immediate then
			M.perform_sync()
		end
		M.start_sync()
	else
		vim.notify("not syincing")
		M.stop_sync()
	end
end

return M
