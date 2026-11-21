-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- 세션 복원 후 남는 [No Name] 버퍼 제거
vim.api.nvim_create_autocmd("SessionLoadPost", {
  callback = function()
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_get_name(buf) == "" and not vim.bo[buf].modified then
        vim.api.nvim_buf_delete(buf, { force = false })
      end
    end
  end,
})

-- 세션(persistence) 과 neo-tree 충돌 방지
--   증상: `vi .` 로 연 뒤 <leader>qS 로 세션을 불러오면 neo-tree 가 화면 전체로 커지고,
--         bufferline 끝에 폴더 버퍼(neo-tree)가 하나 더 생긴다.
--   원인 1: `vi .` 직후 커서가 neo-tree 창에 있다. 세션 파일 첫 줄의 `silent only` 가
--           "현재 창만 남기기"라서 neo-tree 만 남고, 파일은 그 옆 좁은 창에 열린다.
--   원인 2: `vi .` 의 인자 `./` 가 세션에 `$argadd ./` 로 저장돼, 복원 때 폴더 버퍼가 다시 생긴다.
--   대응: 불러오기 전에 neo-tree 를 닫고, 불러온 뒤 폴더 버퍼를 지우고 neo-tree 를 다시 띄운다.
--         저장할 때는 neo-tree 와 인자 목록을 세션에 넣지 않는다.
local function neotree_is_open()
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    if vim.bo[vim.api.nvim_win_get_buf(w)].filetype == "neo-tree" then return true end
  end
  return false
end
local neotree_was_open = false
local session_grp = vim.api.nvim_create_augroup("user_session_neotree", { clear = true })

vim.api.nvim_create_autocmd("User", {
  group = session_grp,
  pattern = "PersistenceSavePre",
  callback = function()
    pcall(vim.cmd, "Neotree close")
    pcall(vim.cmd, "silent! %argdelete")
  end,
})

vim.api.nvim_create_autocmd("User", {
  group = session_grp,
  pattern = "PersistenceLoadPre",
  callback = function()
    neotree_was_open = neotree_is_open()
    pcall(vim.cmd, "Neotree close")
  end,
})

vim.api.nvim_create_autocmd("User", {
  group = session_grp,
  pattern = "PersistenceLoadPost",
  callback = function()
    -- 예전 세션에 남은 `$argadd ./` 대응: 목록에 있는 폴더 버퍼를 지운다
    pcall(vim.cmd, "silent! %argdelete")
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      local name = vim.api.nvim_buf_get_name(buf)
      if vim.bo[buf].buflisted and name ~= "" and vim.fn.isdirectory(name) == 1 then
        pcall(vim.api.nvim_buf_delete, buf, { force = false })
      end
    end
    if neotree_was_open then
      vim.schedule(function() pcall(vim.cmd, "Neotree show") end) -- 커서는 파일 창에 둔다
    end
  end,
})

-- 외부에서 파일이 변경되면 자동으로 버퍼에 반영
vim.opt.autoread = true
vim.opt.updatetime = 1000

vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold", "CursorHoldI" }, {
  pattern = "*",
  callback = function()
    if vim.fn.mode() ~= "c" then
      vim.cmd("checktime")
    end
  end,
})

-- 1초마다 타이머로 checktime 호출 (포커스 이동 없이도 실시간 반영)
local timer = vim.uv.new_timer()
timer:start(1000, 1000, function()
  vim.schedule(function()
    if vim.fn.mode() ~= "c" then
      vim.cmd("checktime")
    end
  end)
end)

