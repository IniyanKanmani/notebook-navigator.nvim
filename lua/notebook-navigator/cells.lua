local M = {}

local private = {}

M.miniai_spec = function(opts, cell_marker)
  local start_line = vim.fn.search("^" .. cell_marker, "bcnW")

  -- Just in case the notebook is malformed and doesnt  have a cell marker at the start.
  if start_line == 0 then
    start_line = 1
  else
    if opts == "i" then
      start_line = start_line + 1
    end
  end

  local end_line = vim.fn.search("^" .. cell_marker, "nW") - 1
  if end_line == -1 then
    end_line = vim.fn.line "$"
  end

  local last_col = math.max(vim.fn.getline(end_line):len(), 1)

  local from = { line = start_line, col = 1 }
  local to = { line = end_line, col = last_col }

  return { from = from, to = to }
end

M.find_cells_above_cursor = function(cell_marker)
  local start_line = 1
  local end_line = vim.fn.search("^" .. cell_marker, "bcnW")

  -- Just in case the notebook is malformed and doesnt  have a cell marker at the start.
  if end_line == 0 then
    end_line = 1
  else
    end_line = end_line - 1
  end

  local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line - 1, false)

  return private.find_cell_objects(cell_marker, start_line, end_line, lines)
end

M.find_cells_below_cursor = function(cell_marker)
  local start_line = vim.fn.search("^" .. cell_marker, "bcnW")

  -- Just in case the notebook is malformed and doesnt  have a cell marker at the start.
  if start_line == 0 then
    start_line = 1
  end
  local end_line = vim.api.nvim_buf_line_count(0)

  local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)

  return private.find_cell_objects(cell_marker, start_line, end_line, lines)
end

M.check_for_markdown_cells = function(cell_marker, line_number)
  local line = vim.fn.getline(line_number)

  local md_regex = vim.regex("^" .. cell_marker .. " \\[markdown\\]")
  local s1, _ = md_regex:match_str(line)

  if s1 then
    return true
  end

  local jt_regex = vim.regex("^" .. "# ---")
  local s2, _ = jt_regex:match_str(line)

  if s2 then
    return true
  end

  return false
end

private.find_cell_objects = function(cell_marker, start_line, last_line, lines)
  local all_cell_objects = {}
  local initial_start_line = start_line
  local end_line = -1

  local regex = vim.regex("^" .. cell_marker)

  for i, line in ipairs(lines) do
    local s, _ = regex:match_str(line)
    i = initial_start_line + i - 1

    if s then
      end_line = i - 1

      local last_col = math.max(vim.fn.getline(end_line):len(), 1)

      local cell_object = {
        from = { line = start_line, col = 1 },
        to = { line = end_line, col = last_col },
      }

      table.insert(all_cell_objects, cell_object)

      start_line = i
    end
  end

  if end_line ~= last_line then
    local last_col = math.max(vim.fn.getline(last_line):len(), 1)

    local cell_object = {
      from = { line = start_line, col = 1 },
      to = { line = last_line, col = last_col },
    }

    table.insert(all_cell_objects, cell_object)
  end

  local code_cells = {}

  for _, cell_object in ipairs(all_cell_objects) do
    if not M.check_for_markdown_cells(cell_marker, cell_object.from.line) then
      table.insert(code_cells, cell_object)
    end
  end

  return code_cells
end

return M
