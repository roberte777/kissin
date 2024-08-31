local M = {}

function M.notify(message, level)
	vim.notify(message, level, { title = "Kissin" })
end

function M.is_in_dir_path(file_path, dir_path)
	local normalized_file_path = vim.fn.fnamemodify(file_path, ":p")
	local normalized_dir_path = vim.fn.fnamemodify(dir_path, ":p")
	return vim.startswith(normalized_file_path, normalized_dir_path)
end

function M.clone_repo(dir_path, repo_url, branch)
	local notes_dir = vim.fn.expand(dir_path)
	if vim.fn.isdirectory(notes_dir) == 0 then
		local cmd = string.format("git clone -b %s %s %s", branch, repo_url, dir_path)
		local clone_result = vim.fn.system(cmd)
		if vim.v.shell_error ~= 0 then
			M.notify("Error cloning repository: " .. clone_result, vim.log.levels.ERROR)
			return false
		end
		M.notify("Repository cloned successfully.", vim.log.levels.INFO)
		return true
	else
		M.notify("Directory already exists. Skipping clone.", vim.log.levels.INFO)
		return true
	end
end

return M
