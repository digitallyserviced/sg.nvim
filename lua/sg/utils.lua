local async = require "plenary.async"

local utils = {}

utils.once = function(f)
  local value, called = nil, false
  return function(...)
    if not called then
      value = f(...)
      called = true
    end

    return value
  end
end

utils.get_word_around_character = function(line, character)
  local match_pat = "[^%w_]"
  local reversed = string.reverse(line)

  local reversed_starting_index = string.find(reversed, match_pat, #line - character, false)
  local start_non_matching_index
  if not reversed_starting_index then
    start_non_matching_index = 0
  else
    start_non_matching_index = #line - reversed_starting_index + 1
  end

  local end_non_matching_index = string.find(line, match_pat, character, false) or (#line + 1)
  return string.sub(line, start_non_matching_index + 1, end_non_matching_index - 1)
end

--- Format some code based on the filetype
---@param bufnr number
---@param code string|string[]
---@return table
utils.format_code = function(bufnr, code)
  return vim.tbl_flatten { string.format("```%s", vim.bo[bufnr].filetype), code, "```" }
end

utils.execute_keystrokes = function(keys)
  vim.cmd(string.format("normal! %s", vim.api.nvim_replace_termcodes(keys, true, false, true)))
end

-- COMPAT(0.10.0)
utils.joinpath = vim.fs.joinpath or function(...)
  return (table.concat({ ... }, "/"):gsub("//+", "/"))
end

-- COMPAT(0.10.0)
-- So far only handle stdout, no other items are handled.
-- Probably will break on me unexpectedly. Nice
utils.system = vim.system or (require "sg.vendored.vim-system")

utils.async_system = async.wrap(function(cmd, opts, on_exit)
  return utils.system(cmd, opts, vim.schedule_wrap(on_exit))
end, 3)

-- From https://gist.github.com/jrus/3197011
utils.uuid = function()
  local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
  return string.gsub(template, "[xy]", function(c)
    local v = (c == "x") and math.random(0, 0xf) or math.random(8, 0xb)
    return string.format("%x", v)
  end)
end

--- Read a file and parse it as json, or return nil
---@param file string: The name of the file
---@return any
utils.json_or_nil = function(file)
  local handle = io.open(file)
  if handle then
    local contents = handle:read "*a"
    handle:close()

    local ok, parsed = pcall(vim.json.decode, contents)
    if ok and parsed then
      return parsed
    end
  end

  return nil
end

return utils
