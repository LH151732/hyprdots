return {
  -- Treesitter 配置，添加对多种语言的支持
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    event = { "BufReadPost", "BufNewFile" },
    main = "nvim-treesitter",
    opts = {
      ensure_installed = {
        "lua",
        "python",
        "java",
        "javascript",
        "typescript",
        "tsx",
        "json",
        "yaml",
        "html",
        "css",
        "scss",
        "bash",
        "markdown",
        "markdown_inline",
        "vim",
        "vimdoc",
        "gitignore",
        "graphql",
        "http",
        "sql",
        "r",
        "svelte", -- Svelte (包含嵌入的 HTML/CSS/JS)
        "rust", -- Rust
        "toml", -- Cargo.toml
        "go", -- Go
        "gomod", -- go.mod
        "gosum", -- go.sum
        "gowork", -- go.work
        "cpp", -- C++
        "c", -- C
        "cmake", -- CMakeLists.txt
      },
      auto_install = true,
      highlight = {
        enable = true,
        additional_vim_regex_highlighting = { "markdown" },
      },
      indent = { enable = true },
    },
    priority = 100,
  },
  -- markdown 的语法高亮由 treesitter + render-markdown.nvim 负责,
  -- 不再使用 vim-markdown / vim-pandoc-syntax (conceal 会和 render-markdown 打架)
}
