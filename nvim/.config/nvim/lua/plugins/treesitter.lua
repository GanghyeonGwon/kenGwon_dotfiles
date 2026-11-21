-- tree-sitter 파서 목록
--   LazyVim 은 ensure_installed 에 있는 언어만 tree-sitter 로 하이라이트한다.
--   파서가 없는 언어는 vim 의 옛 정규식 syntax 로 떨어져서 덜 정확하다.
--   아래는 LazyVim 기본 목록(c, bash, python, lua, markdown, json, yaml ...)에 더하는 것이다.
--   기준: 2026-11-21 yocto 커널 BSP 트리의 파일 분포(.dts/.dtsi 1.4만, Makefile 7천, Kconfig 4천, .S 3천 ...).
return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = {
        "t32",          -- TRACE32 PRACTICE (.cmm)
        "cpp",          -- .cpp / .hh
        "devicetree",   -- .dts / .dtsi / .dtso
        "make",         -- Makefile / Kbuild / .mk
        "kconfig",      -- Kconfig
        "asm",          -- .S / .s
        "linkerscript", -- .lds / .ld
        "cmake",        -- CMakeLists.txt / .cmake
        "bitbake",      -- yocto .bb / .bbappend / .bbclass
        "rst",          -- 커널 문서
        "rust",         -- 커널 rust 코드
        "gitcommit", "git_rebase", "git_config", "gitignore", "gitattributes",
      },
    },
    init = function()
      vim.filetype.add({
        extension = {
          cmm = "trace32", -- t32 파서가 filetype "trace32" 에 등록돼 있다
          lds = "ld",      -- nvim 은 *.ld 만 링커 스크립트로 인식한다
          -- .h: nvim 기본값은 무조건 cpp 다. C++ 파서로 커널 C 헤더를 읽으면 변수명 new/class/this 를
          -- 키워드로 보고 파싱 오류가 난다(커널 트리 535개 헤더). 반대로 Qt 같은 C++ 헤더는 C 로 읽으면 깨진다.
          -- 그래서 앞부분 내용으로 판정한다. C++ 흔적이 없으면 C.
          h = function(_, bufnr)
            local lines = vim.api.nvim_buf_get_lines(bufnr, 0, 300, false)
            for _, l in ipairs(lines) do
              l = l:gsub("//.*", "") -- 주석 속 std:: 등은 무시
              if l:match("^%s*/?%*") then l = "" end
              if l:match("^%s*class%s+[%w_]+") or l:match("^%s*namespace[%s{]") or l:match("^%s*template%s*<")
                or l:match("std::") or l:match("^%s*public:") or l:match("^%s*private:") then
                return "cpp"
              end
            end
            return "c"
          end,
        },
      })
    end,
  },
}
