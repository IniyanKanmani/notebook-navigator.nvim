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

M.find_cells_above_cursor = function(opts, cell_marker)
  local start_line = 1
  local end_line = vim.fn.search("^" .. cell_marker, "bcnW")

  -- Just in case the notebook is malformed and doesnt  have a cell marker at the start.
  if end_line == 0 then
    end_line = 1
  else
    end_line = end_line - 1
  end

  local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line - 1, false)

  return private.find_cell_objects(opts, cell_marker, start_line, end_line, lines)
end

M.find_cells_below_cursor = function(opts, cell_marker)
  local start_line = vim.fn.search("^" .. cell_marker, "bcnW")

  -- Just in case the notebook is malformed and doesnt  have a cell marker at the start.
  if start_line == 0 then
    start_line = 1
  else
    if opts == "i" then
      start_line = start_line + 1
    end
  end
  local end_line = vim.api.nvim_buf_line_count(0)

  local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)

  return private.find_cell_objects(opts, cell_marker, start_line, end_line, lines)
end

private.find_cell_objects = function(opts, cell_marker, start_line, last_line, lines)
  local all_cell_objects = {}
  local initial_start_line = start_line
  local end_line = -1

  local regex = vim.regex("^" .. cell_marker)

  for i, line in ipairs(lines) do
    local s, _ = regex:match_str(line)
    i = initial_start_line + i

    if s then
      end_line = i - 1

      if opts == "i" then
        end_line = i - 2
      end

      local last_col = math.max(vim.fn.getline(end_line):len(), 1)

      local cell_object = {
        from = { line = start_line, col = 1 },
        to = { line = end_line, col = last_col },
      }

      table.insert(all_cell_objects, cell_object)

      start_line = i
    end
  end

  if end_line ~= last_line and start_line <= last_line then
    local last_col = math.max(vim.fn.getline(last_line):len(), 1)

    local cell_object = {
      from = { line = start_line, col = 1 },
      to = { line = last_line, col = last_col },
    }

    table.insert(all_cell_objects, cell_object)
  end

  return all_cell_objects
end

return M
