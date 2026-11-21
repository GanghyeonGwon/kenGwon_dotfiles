-- Yocto / BitBake (.bb .bbappend .bbclass .inc .conf 중 bitbake filetype)
--
-- 공식 도구만 쓴다. 사용법과 한계는 README "Yocto / BitBake" 참고.
--   - language-server-bitbake: Yocto 프로젝트 공식 LSP. nvim 에서는 자동완성 + 변수 문서(hover)가 주 기능이다.
--     inherit/require/레시피 "정의로 이동"은 VS Code 확장 쪽 스캔이 있어야 해서 아직 안 된다
--     (https://github.com/yoctoproject/vscode-bitbake/issues/380). 지원되면 서버 업데이트만 하면 된다.
--   - oelint-adv: OpenEmbedded 레시피 linter. 저장할 때 nvim-lint 가 돌린다.
return {
  {
    "mason-org/mason.nvim",
    opts = { ensure_installed = { "language-server-bitbake", "oelint-adv" } },
  },
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        -- nvim-lspconfig 의 lsp/ 목록에는 이 서버 설정이 없어서 직접 적는다(LazyVim 이 vim.lsp.config/enable 한다)
        bitbake_ls = {
          cmd = { "language-server-bitbake", "--stdio" },
          filetypes = { "bitbake" },
          root_markers = { "conf/layer.conf", ".git" },
        },
      },
    },
  },
  {
    "mfussenegger/nvim-lint",
    opts = {
      linters_by_ft = { bitbake = { "oelint-adv" } },
      linters = {
        -- info 수준("BUGTRACKER 를 설정하라", 여러 줄 들여쓰기 권장 등)은 숨기고 warning/error 만 본다.
        -- 규칙별로 끄려면 레이어 최상단에 .oelint.cfg 를 둔다(oelint-adv 표준 방식).
        ["oelint-adv"] = { prepend_args = { "--hide", "info" } },
      },
    },
  },
}
