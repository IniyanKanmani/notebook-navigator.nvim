local utils = {}

utils.get_cell_marker = function(bufnr, cell_markers)
  local ft = vim.bo[bufnr].filetype

  if ft == nil or ft == "" then
    print "[NotebookNavigator] utils.lua: Empty filetype"
  end

  local user_opt_cell_marker = cell_markers[ft]
  if user_opt_cell_marker then
    return user_opt_cell_marker
  end

  -- use double percent markers as default for cell markers
  -- DOCS https://jupytext.readthedocs.io/en/latest/formats-scripts.html#the-percent-format
  if not vim.bo.commentstring then
    error("There's no cell marker and no commentstring defined for filetype " .. ft)
  end
  local cstring = string.gsub(vim.bo.commentstring, "^%%", "%%%%")
  local double_percent_cell_marker = cstring:format "%%"
  return double_percent_cell_marker
end

local find_supported_repls = function()
  local supported_repls = {
    { name = "iron", module = "iron" },
    { name = "toggleterm", module = "toggleterm" },
    { name = "molten", module = "molten.health" },
  }

  local available_repls = {}
  for _, repl in pairs(supported_repls) do
    if pcall(require, repl.module) then
      available_repls[#available_repls + 1] = repl.name
    end
  end

  return available_repls
end

utils.available_repls = find_supported_repls()

utils.has_value = function(tab, val)
  for _, value in ipairs(tab) do
    if value == val then
      return true
    end
  end

  return false
end

utils.is_markdown_cell = function(buffer, cell_object)
  local cell_lines = vim.api.nvim_buf_get_lines(buffer, cell_object.from.line, cell_object.to.line, false)
  local md_object = {}

  md_object = utils.check_if_multiline_md(cell_object.from.line, cell_lines)

  if next(md_object) == nil then
    md_object = utils.check_if_linebyline_md(cell_object.from.line, cell_lines)
  end

  vim.print(md_object)

  return md_object
end

utils.check_if_multiline_md = function(start_line, cell_lines)
  local in_multiline = false
  local md_lines = {}

  for i, line in ipairs(cell_lines) do
    if line:match [[^"""$]] or line:match [[^'''$]] then
      if not in_multiline then
        in_multiline = true
        md_lines.type = "multiline"
        md_lines.from = {
          line = start_line + i,
          col = 0,
        }
      else
        in_multiline = false
        md_lines.to = {
          line = start_line + i,
          col = #line,
        }
      end
    end
  end

  return md_lines
end

utils.check_if_linebyline_md = function(start_line, cell_lines)
  local is_linebyline = false
  local md_lines = {}

  for i, line in ipairs(cell_lines) do
    if line:match [[^# ]] then
      if not is_linebyline then
        md_lines.type = "linebyline"
        md_lines.from = {
          line = start_line + i,
          col = 0,
        }
      end

      is_linebyline = true

      if is_linebyline then
        md_lines.to = {
          line = start_line + i,
          col = #line,
        }
      end
    end
  end

  return md_lines
end

utils.convert_to_md_cell = function(buffer, cell_object)
  vim.api.nvim_buf_set_lines(buffer, cell_object.from.line, cell_object.from.line, false, { '"""' })

  vim.api.nvim_buf_set_lines(buffer, cell_object.to.line, cell_object.to.line, false, { '"""' })
end

utils.remove_md_from_cell = function(buffer, md_object)
  if md_object.type == "multiline" then
    vim.api.nvim_buf_set_lines(buffer, md_object.from.line - 1, md_object.from.line, false, {})
    vim.api.nvim_buf_set_lines(buffer, md_object.to.line - 2, md_object.to.line - 1, false, {})
  elseif md_object.type == "linebyline" then
    local cell_lines = vim.api.nvim_buf_get_lines(buffer, md_object.from.line - 1, md_object.to.line, false)

    cell_lines = vim.tbl_map(function(line)
      return line:sub(3)
    end, cell_lines)

    vim.print(cell_lines)

    vim.api.nvim_buf_set_lines(buffer, md_object.from.line - 1, md_object.to.line, false, cell_lines)
  end
end

return utils
