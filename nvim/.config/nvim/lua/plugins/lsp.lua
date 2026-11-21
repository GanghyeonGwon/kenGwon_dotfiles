-- LSP 로그 정책
--   nvim 은 LSP 서버가 stderr 로 내보내는 내용을 정보성 메시지까지 모두 [ERROR] 로
--   ~/.local/state/nvim/lsp.log 에 쌓는다. BSP 같은 큰 프로젝트에서 clangd 가 돌면 이 파일이
--   수백 MB 까지 커진다(2026-11-21 에 268MB 였다).
--   그래서 평소에는 로그를 끄고, clangd 도 stderr 로 오류만 내보내게 한다.
--   디버깅이 필요할 때: :lua vim.lsp.log.set_level("DEBUG")  →  :LspLog
vim.lsp.log.set_level("OFF")

return {
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.inlay_hints = opts.inlay_hints or {}
      opts.inlay_hints.enabled = false

      -- clangd: LazyVim clangd extra 의 cmd 목록 뒤에 덧붙인다(목록을 복사하면 LazyVim 변경을 못 따라간다)
      local clangd = opts.servers and opts.servers.clangd
      if clangd and clangd.cmd and not vim.tbl_contains(clangd.cmd, "--log=error") then
        table.insert(clangd.cmd, "--log=error")
      end
    end,
  },
}
