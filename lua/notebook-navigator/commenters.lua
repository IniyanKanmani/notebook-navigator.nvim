local commenters = {}

-- comment.nvim
commenters.comment_nvim = function(cell_object)
  local comment = require "Comment.api"
  local curr_pos = vim.api.nvim_win_get_cursor(0)
  local n_lines = 0

  local cell_lines = vim.api.nvim_buf_get_lines(0, cell_object.from.line - 1, cell_object.to.line, false)

  for i, line in ipairs(cell_lines) do
    if line:find "%S" then
      n_lines = i
    end
  end

  vim.api.nvim_win_set_cursor(0, { cell_object.from.line, 0 })
  comment.toggle.linewise.count(n_lines)
  vim.api.nvim_win_set_cursor(0, curr_pos)
end

-- mini.comment
commenters.mini_comment = function(cell_object)
  local comment = require "mini.comment"
  local end_line = cell_object.from.line

  local cell_lines = vim.api.nvim_buf_get_lines(0, cell_object.from.line - 1, cell_object.to.line, false)

  for i, line in ipairs(cell_lines) do
    if line:find "%S" then
      end_line = cell_object.from.line + i - 1
    end
  end

  comment.toggle_lines(cell_object.from.line, end_line)
end

-- no recognized comment plugin
commenters.no_comments = function(_)
  vim.notify "[Notebook Navigator] No supported comment plugin available"
end

local has_mini_comment, _ = pcall(require, "mini.comment")
local has_comment_nvim, _ = pcall(require, "Comment.api")
local commenter
if has_mini_comment then
  commenter = commenters["mini_comment"]
elseif has_comment_nvim then
  commenter = commenters["comment_nvim"]
else
  commenter = commenters["no_comments"]
end

return commenter
