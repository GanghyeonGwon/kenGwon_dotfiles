-- tree-sitter 상태 점검. nvim 업데이트·`:Lazy update`·`:TSUpdate` 뒤에 돌린다.
--   nvim --headless -c "luafile ~/dotfiles/scripts/check-treesitter.lua" [파일 ...]
-- 또는 scripts/check-treesitter.sh [파일 ...]
--
-- 1) 설치된 모든 파서의 쿼리(highlights, injections, locals, folds, indents)를 실제로 파싱해 본다.
--    플러그인과 파서 버전이 어긋나면 여기서 "query error" 로 잡힌다(2026-11-21 diff 사례).
-- 2) ensure_installed 에 있는데 설치 안 된 파서를 찾는다.
-- 3) 인자로 준 파일을 열어 filetype → 파서 → 하이라이트가 실제로 켜지는지 본다.
-- 끝나면 "TREESITTER OK" 또는 "TREESITTER FAIL (n)" 을 출력하고 종료 코드로도 알린다.

local out, fails = {}, 0
local function say(s) table.insert(out, s) end
local function fail(s) fails = fails + 1; say("  FAIL " .. s) end

require("lazy").load({ plugins = { "nvim-treesitter" } })
local TS = require("nvim-treesitter")
local files = vim.fn.argv()

-- 0) 버전
local function cmd(c) local r = vim.system(c, { text = true }):wait(); return vim.trim((r.stdout or "") .. (r.stderr or "")) end
say(("nvim %s | tree-sitter CLI %s (%s)"):format(tostring(vim.version()), cmd({ "tree-sitter", "--version" }), vim.fn.exepath("tree-sitter")))
local tsdir = vim.fn.stdpath("data") .. "/lazy/nvim-treesitter"
say("nvim-treesitter " .. cmd({ "git", "-C", tsdir, "rev-parse", "--short", "HEAD" }))

-- 1) 쿼리 파싱
local installed = TS.get_installed("parsers")
table.sort(installed)
say(("[1] 설치된 파서 %d개 쿼리 검사"):format(#installed))
for _, lang in ipairs(installed) do
  local ok, err = pcall(vim.treesitter.language.add, lang)
  if not ok then
    fail(lang .. ": 파서 로드 실패: " .. tostring(err))
  else
    for _, q in ipairs({ "highlights", "injections", "locals", "folds", "indents" }) do
      local qok, qerr = pcall(vim.treesitter.query.get, lang, q)
      if not qok then fail(("%s/%s: %s"):format(lang, q, tostring(qerr):gsub("\n.*", ""))) end
    end
  end
end

-- 2) 빠진 파서
local spec = require("lazy.core.config").plugins["nvim-treesitter"]
local want = require("lazy.core.plugin").values(spec, "opts", false).ensure_installed or {}
local have = {}
for _, l in ipairs(installed) do have[l] = true end
local missing = vim.tbl_filter(function(l) return not have[l] end, want)
say(("[2] ensure_installed %d개 중 빠진 파서: %s"):format(#want, #missing == 0 and "없음" or table.concat(missing, ", ")))
if #missing > 0 then fail("빠진 파서가 있다. nvim 을 열어 설치를 기다리거나 :TSInstall " .. table.concat(missing, " ")) end

-- 3) 실제 파일
if #files > 0 then say(("[3] 파일 %d개 하이라이트 확인"):format(#files)) end
for _, f in ipairs(files) do
  vim.cmd("silent! edit " .. vim.fn.fnameescape(f))
  local buf = vim.api.nvim_get_current_buf()
  vim.wait(300)
  local ft = vim.bo[buf].filetype
  local lang = vim.treesitter.language.get_lang(ft)
  local active = vim.treesitter.highlighter.active[buf] ~= nil
  local line = ("  %-8s ft=%-10s lang=%-12s %s"):format(active and "ok" or "", ft, tostring(lang), vim.fn.fnamemodify(f, ":t"))
  if active then say(line) else fail(line:gsub("^%s+", "") .. " ← tree-sitter 하이라이트 꺼짐") end
end

say(fails == 0 and "TREESITTER OK" or ("TREESITTER FAIL (%d)"):format(fails))
io.stdout:write(table.concat(out, "\n") .. "\n")
vim.cmd(fails == 0 and "qa!" or "cq!")
