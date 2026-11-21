return {
  "nvim-neo-tree/neo-tree.nvim",
  opts = {
    filesystem = {
      filtered_items = {
        hide_dotfiles = false, -- .bashrc, .config 같은 숨김 파일도 표시
        hide_gitignored = false,
      },
    },
  },
}
