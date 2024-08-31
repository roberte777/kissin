local M = {}
local utils = require("kissin.utils")
local sync = require("kissin.sync")

function M.on_vim_enter()
	local config = vim.g.kissin_config
	if config and config.dir_path and vim.fn.getcwd() == config.dir_path then
		sync.check_and_sync(true) -- Immediate sync
	else
		sync.check_and_sync(false)
	end
end

function M.on_dir_changed()
	sync.check_and_sync(true) -- Immediate sync
end

function M.on_buf_enter()
	local config = vim.g.kissin_config
	if config and config.dir_path then
		local file_path = vim.fn.expand("%:p")
		if utils.is_in_dir_path(file_path, config.dir_path) then
			sync.check_and_sync(true) -- Immediate sync
		else
			sync.check_and_sync(false)
		end
	end
end

function M.on_buf_write()
	sync.check_and_sync(true) -- Immediate sync
end

function M.manual_sync()
	local config = vim.g.kissin_config
	if config and config.dir_path then
		sync.perform_sync()
	else
		utils.notify("Kissin is not properly configured.", vim.log.levels.ERROR)
	end
end

function M.setup(config)
	if config.dir_path then
		config.dir_path = vim.fn.expand(config.dir_path)
	end
	vim.g.kissin_config = config

	-- Clone the repository if it doesn't exist
	if config.repo_url then
		local branch = config.branch or "main"
		if not utils.clone_repo(config.dir_path, config.repo_url, branch) then
			utils.notify("Failed to clone repository. Plugin may not function correctly.", vim.log.levels.ERROR)
			return
		end
	end

	-- Set up autocommands
	-- vim.api.nvim_create_autocmd("VimEnter", {
	--   callback = M.on_vim_enter
	-- })
	-- vim.api.nvim_create_autocmd("DirChanged", {
	--   callback = M.on_dir_changed
	-- })
	vim.api.nvim_create_autocmd("BufEnter", {
		callback = M.on_buf_enter,
	})
	vim.api.nvim_create_autocmd("BufWritePost", {
		callback = M.on_buf_write,
	})

	-- Create a command for manual syncing
	vim.api.nvim_create_user_command("KissinSync", M.manual_sync, {})
end

return M
