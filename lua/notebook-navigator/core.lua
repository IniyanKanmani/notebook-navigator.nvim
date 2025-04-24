local commenter = require "notebook-navigator.commenters"
local repls = require "notebook-navigator.repls"
local cells = require "notebook-navigator.cells"
local utils = require "notebook-navigator.utils"

local M = {}

M.move_cell = function(dir, cell_marker)
  local search_res
  local result

  if dir == "d" then
    search_res = vim.fn.search("^" .. cell_marker, "W")
    if search_res == 0 then
      result = "last"
    end
  else
    search_res = vim.fn.search("^" .. cell_marker, "bW")
    if search_res == 0 then
      result = "first"
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
    end
  end

  return result
end

M.run_cell = function(cell_marker, repl_provider, repl_args)
  repl_args = repl_args or nil
  repl_provider = repl_provider or "auto"
  local cell_object = cells.miniai_spec("a", cell_marker)

  local repl = repls.get_repl(repl_provider)

  -- protect ourselves against the case with no actual lines of code
  local n_lines = cell_object.to.line - cell_object.from.line + 1
  if n_lines < 1 then
    return nil
  end

  if cells.check_for_markdown_cells(cell_marker, cell_object.from.line) then
    return true
  end

  ---@diagnostic disable-next-line: redundant-parameter
  return repl(cell_object.from.line + 1, cell_object.to.line, repl_args)
end

M.run_and_move = function(cell_marker, repl_provider, repl_args)
  local success = M.run_cell(cell_marker, repl_provider, repl_args)

  if success then
    local is_last_cell = M.move_cell("d", cell_marker) == "last"

    -- insert a new cell to replicate the behaviour of jupyter notebooks
    if is_last_cell then
      vim.api.nvim_buf_set_lines(0, -1, -1, false, { cell_marker, "" })
      -- and move to it
      M.move_cell("d", cell_marker)
    end
  end
end

M.run_all_cells = function(cell_marker, repl_provider, repl_args)
  M.run_cells_above(cell_marker, repl_provider, repl_args)
  M.run_cells_below(cell_marker, repl_provider, repl_args)
end

M.run_cells_above = function(cell_marker, repl_provider, repl_args)
  local code_cells = cells.find_cells_above_cursor(cell_marker)
  local repl = repls.get_repl(repl_provider)

  for _, cell_object in ipairs(code_cells) do
    ---@diagnostic disable-next-line: redundant-parameter
    repl(cell_object.from.line + 1, cell_object.to.line, repl_args)
  end
end

M.run_cells_below = function(cell_marker, repl_provider, repl_args)
  local code_cells = cells.find_cells_below_cursor(cell_marker)
  local repl = repls.get_repl(repl_provider)

  for _, cell_object in ipairs(code_cells) do
    ---@diagnostic disable-next-line: redundant-parameter
    repl(cell_object.from.line + 1, cell_object.to.line, repl_args)
  end

  vim.cmd "normal G"
  M.move_cell("u", cell_marker)
end

M.split_cell = function(cell_marker)
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
  vim.api.nvim_buf_set_lines(0, cursor_line - 1, cursor_line - 1, false, { cell_marker })
  vim.api.nvim_win_set_cursor(0, { cursor_line + 1, 0 })
end

M.merge_cell = function(dir, cell_marker)
  local search_res
  local result

  if dir == "d" then
    search_res = vim.fn.search("^" .. cell_marker, "nW")
    vim.api.nvim_buf_set_lines(0, search_res - 1, search_res, false, { "" })
  else
    search_res = vim.fn.search("^" .. cell_marker, "nbW")
    if search_res == 0 then
      return "first"
    else
      vim.api.nvim_buf_set_lines(0, search_res - 1, search_res, false, { "" })
    end
  end

  return result
end

M.swap_cell = function(dir, cell_marker)
  local buf_length = vim.api.nvim_buf_line_count(0)
  local should_insert_marker = false

  -- Get cells in their future order
  local starting_cursor = vim.api.nvim_win_get_cursor(0)
  local first_cell
  local second_cell
  if dir == "d" then
    second_cell = cells.miniai_spec("a", cell_marker)
    if second_cell.to.line + 1 > buf_length then
      return
    end
    vim.api.nvim_win_set_cursor(0, { second_cell.to.line + 2, 0 })
    first_cell = cells.miniai_spec("a", cell_marker)
  else
    first_cell = cells.miniai_spec("a", cell_marker)
    if first_cell.from.line - 1 < 1 then
      return
    end
    vim.api.nvim_win_set_cursor(0, { first_cell.from.line - 1, 0 })
    second_cell = cells.miniai_spec("a", cell_marker)

    -- The first cell may not have a marker. If this is the case and we attempt to
    -- swap it down we will be in trouble. In that case we first insert a marker at
    -- the top.
    -- If the line does not start with the cell_marker with set a marker to add
    -- the line later on.
    local first_cell_line =
      vim.api.nvim_buf_get_lines(0, second_cell.from.line - 1, second_cell.from.line, false)[1]

    if string.sub(first_cell_line, 1, string.len(cell_marker)) ~= cell_marker then
      should_insert_marker = true
    end
    --
  end

  -- Combine cells and set in place
  local first_lines = vim.api.nvim_buf_get_lines(0, first_cell.from.line - 1, first_cell.to.line, false)
  local second_lines = vim.api.nvim_buf_get_lines(0, second_cell.from.line - 1, second_cell.to.line, false)

  local final_lines = {}

  for _, v in ipairs(first_lines) do
    table.insert(final_lines, v)
  end

  -- This extra marker protects us agains malformed notebooks that don't have a cell
  -- marker at the top of the file. See the "up" case a few lines above.
  if should_insert_marker then
    table.insert(final_lines, cell_marker)
  end
  for _, v in ipairs(second_lines) do
    table.insert(final_lines, v)
  end
  vim.api.nvim_buf_set_lines(0, second_cell.from.line - 1, first_cell.to.line, false, final_lines)

  -- Put cursor in previous position
  local new_cursor = starting_cursor
  if dir == "d" then
    new_cursor[1] = new_cursor[1] + (first_cell.to.line - first_cell.from.line + 1)
  else
    new_cursor[1] = new_cursor[1] - (second_cell.to.line - second_cell.from.line + 1)
  end
  vim.api.nvim_win_set_cursor(0, new_cursor)
end

M.add_cell_below = function(cell_marker)
  local cell_object = cells.miniai_spec("a", cell_marker)

  vim.api.nvim_buf_set_lines(0, cell_object.to.line, cell_object.to.line, false, { cell_marker, "" })
  M.move_cell("d", cell_marker)
end

M.add_cell_above = function(cell_marker)
  local cell_object = cells.miniai_spec("a", cell_marker)

  -- What to do on malformed notebooks? I.e. with no upper cell marker? are they malformed?
  -- What if we have a jupytext header? Code doesn't start at top of buffer.
  vim.api.nvim_buf_set_lines(
    0,
    cell_object.from.line - 1,
    cell_object.from.line - 1,
    false,
    { cell_marker, "" }
  )
  M.move_cell("u", cell_marker)
end

M.add_text_cell_below = function(cell_marker)
  local cell_object = cells.miniai_spec("a", cell_marker)

  vim.api.nvim_buf_set_lines(
    0,
    cell_object.to.line,
    cell_object.to.line,
    false,
    { cell_marker .. " [markdown]", '"""', "", '"""', "" }
  )

  M.move_cell("d", cell_marker)
  vim.api.nvim_win_set_cursor(0, { cell_object.to.line + 3, 0 })
end

M.add_text_cell_above = function(cell_marker)
  local cell_object = cells.miniai_spec("a", cell_marker)

  -- What to do on malformed notebooks? I.e. with no upper cell marker? are they malformed?
  -- What if we have a jupytext header? Code doesn't start at top of buffer.
  vim.api.nvim_buf_set_lines(
    0,
    cell_object.from.line - 1,
    cell_object.from.line - 1,
    false,
    { cell_marker .. " [markdown]", '"""', "", '"""', "" }
  )

  M.move_cell("u", cell_marker)
  vim.api.nvim_win_set_cursor(0, { cell_object.from.line + 2, 0 })
end

-- We keep this two for backwards compatibility but the prefered way is to use
-- the above/below functions for consistency with jupyter nomenclature
M.add_cell_before = function(cell_marker)
  M.add_cell_above(cell_marker)
end

M.add_cell_after = function(cell_marker)
  M.add_cell_below(cell_marker)
end

M.comment_cell = function(cell_marker)
  local cell_object = cells.miniai_spec("i", cell_marker)

  -- protect against empty cells
  local n_lines = cell_object.to.line - cell_object.from.line + 1
  if n_lines < 1 then
    return nil
  end
  commenter(cell_object)
end

M.convert_to_code_cell = function(cell_marker)
  local cell_object = cells.miniai_spec("a", cell_marker)

  vim.api.nvim_buf_set_lines(0, cell_object.from.line - 1, cell_object.from.line, false, { cell_marker })

  local md_object = utils.is_markdown_cell(0, cell_object)

  if next(md_object) then
    utils.remove_md_from_cell(0, md_object)
  end
end

M.convert_to_markdown_cell = function(cell_marker)
  local cell_object = cells.miniai_spec("a", cell_marker)

  vim.api.nvim_buf_set_lines(
    0,
    cell_object.from.line - 1,
    cell_object.from.line,
    false,
    { cell_marker .. " [markdown]" }
  )

  local md_object = utils.is_markdown_cell(0, cell_object)

  if not next(md_object) then
    utils.convert_to_md_cell(0, cell_object)
  end
end

M.visually_select_cell = function(ai, cell_marker)
  local cell_object = cells.miniai_spec(ai, cell_marker)

  vim.fn.setpos("'<", { 0, cell_object.from.line, cell_object.from.col, 0 })
  vim.fn.setpos("'>", { 0, cell_object.to.line, cell_object.to.col, 0 })

  vim.cmd "normal! gv"
end

M.change_cell = function(ai, cell_marker)
  local cell_object = cells.miniai_spec(ai, cell_marker)

  vim.api.nvim_buf_set_lines(0, cell_object.from.line - 1, cell_object.to.line, false, {})
  vim.api.nvim_buf_set_lines(0, cell_object.from.line - 1, cell_object.from.line - 1, false, { "" })

  vim.api.nvim_win_set_cursor(0, { cell_object.from.line, 0 })

  vim.cmd "startinsert"
end

M.delete_cell = function(ai, cell_marker)
  local cell_object = {}

  if ai == "a" then
    cell_object = cells.miniai_spec("a", cell_marker)

    vim.api.nvim_buf_set_lines(0, cell_object.from.line - 1, cell_object.to.line, false, {})

    if cell_object.from.line < vim.api.nvim_buf_line_count(0) then
      vim.api.nvim_win_set_cursor(0, { cell_object.from.line, 0 })
    else
      M.move_cell("u", cell_marker)
    end
  elseif ai == "i" then
    cell_object = cells.miniai_spec("i", cell_marker)

    vim.api.nvim_buf_set_lines(0, cell_object.from.line - 1, cell_object.to.line, false, {})
    vim.api.nvim_buf_set_lines(0, cell_object.from.line - 1, cell_object.from.line - 1, false, { "" })

    if cell_object.from.line > 1 then
      vim.api.nvim_win_set_cursor(0, { cell_object.from.line - 1, 0 })
    else
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
    end
  end
end

return M
