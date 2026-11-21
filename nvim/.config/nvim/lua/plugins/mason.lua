-- mason 패키지 목록 (노트북·빌드서버 공통)
--
-- LazyVim 은 nvim 을 열 때 ensure_installed 에 있는데 설치 안 된 패키지를 자동으로 설치한다.
-- 그래서 여기 적은 목록이 두 머신에서 같아진다. 버전은 고정되지 않는다(설치 시점의 최신).
-- 버전까지 맞추려면 양쪽에서 같은 날 :Mason → U.
--
-- 다른 파일·extra 가 이미 요구하는 것(여기 다시 적지 않는다):
--   clangd(lang.clangd), json-lsp(lang.json), lua-language-server, marksman / markdownlint-cli2 /
--   markdown-toc(lang.markdown), stylua / shfmt(LazyVim 기본), language-server-bitbake / oelint-adv(yocto.lua)
--
-- 아래는 예전에 :Mason 에서 손으로 깔아 설정에 없던 것이다(2026-11-21 빌드서버 기준으로 정리).
--   mason 에 설치된 LSP 서버는 mason-lspconfig 가 자동으로 켜므로, 노트북에 없으면 그쪽에서만 동작하지 않았다.
return {
  {
    "mason-org/mason.nvim",
    opts = {
      ensure_installed = {
        "bash-language-server", -- bashls: .sh 자동완성·진단
        "shellcheck",           -- bashls 가 셸 스크립트 진단에 쓴다
        "pyright",              -- python LSP
      },
    },
  },
}
