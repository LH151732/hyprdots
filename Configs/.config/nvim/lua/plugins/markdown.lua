return {
  -- 浏览器预览 markdown
  {
    "toppair/peek.nvim",
    build = "deno task --quiet build:fast",
    ft = { "markdown" },
    config = function()
      require("peek").setup({
        theme = "dark",
        app = "browser",
      })
      vim.api.nvim_create_user_command("PeekOpen", function()
        require("peek").open()
      end, {})
      vim.api.nvim_create_user_command("PeekClose", function()
        require("peek").close()
      end, {})
    end,
  },

  -- Inline markdown 渲染 (替代 markview.nvim, 无闪烁)
  {
    "MeanderingProgrammer/render-markdown.nvim",
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-mini/mini.icons" },
    ft = { "markdown", "quarto" },
    opts = {
      -- 所有模式 (normal/insert/visual/...) 都渲染
      render_modes = true,
      -- Obsidian Live Preview 风格: 光标所在元素显示 raw, 其他保持渲染
      anti_conceal = {
        enabled = true,
        above = 0, -- 光标行以上 0 行就恢复渲染
        below = 0, -- 光标行以下 0 行就恢复渲染
      },

      heading = {
        enabled = true,
        sign = false, -- 不在 signcolumn 放图标, 保持干净
        icons = { "󰎤 ", "󰎧 ", "󰎪 ", "󰎭 ", "󰎱 ", "󰎳 " },
        width = "block", -- 背景只覆盖标题内容, 不延伸到行尾
        left_pad = 0,
        right_pad = 2,
      },

      code = {
        enabled = true,
        style = "full", -- 完整: 语言图标 + 顶部 label + 背景色 + 边框
        position = "left",
        language_pad = 1,
        width = "block", -- 代码块背景不延伸到行尾, 看起来像真正的 "块"
        left_pad = 0,
        right_pad = 2,
        border = "thin", -- thick = 粗边框, thin = 细线, hide = 不显示
        highlight_language = nil, -- 自动根据语言上色
      },

      bullet = {
        enabled = true,
        icons = { "●", "○", "◆", "◇" },
      },

      checkbox = {
        enabled = true,
        unchecked = { icon = "󰄱 " },
        checked = { icon = " " },
      },

      quote = {
        enabled = true,
        icon = "▋",
      },

      pipe_table = {
        enabled = true,
        style = "full",
      },

      -- GFM callouts (> [!NOTE], > [!WARNING] 等)
      callout = {
        note = { raw = "[!NOTE]", rendered = "󰋽 Note" },
        tip = { raw = "[!TIP]", rendered = "󰌶 Tip" },
        important = { raw = "[!IMPORTANT]", rendered = " Important" },
        warning = { raw = "[!WARNING]", rendered = "󰀪 Warning" },
        caution = { raw = "[!CAUTION]", rendered = "󰳦 Caution" },
      },

      latex = { enabled = false }, -- 不需要 latex, 关掉省资源

      -- 强制重新 parse 的事件. gg/G 大跳跃后手动触发 User RenderMarkdownRefresh 让重渲染
      change_events = { "User" },
    },
    keys = {
      { "<leader>mh", "<CMD>RenderMarkdown toggle<CR>", desc = "切换 markdown 渲染" },
      {
        "<leader>mR",
        function()
          vim.api.nvim_exec_autocmds("User", { modeline = false })
        end,
        desc = "强制刷新 markdown 渲染",
      },
    },
    config = function(_, opts)
      require("render-markdown").setup(opts)

      -- 修复 gg/G 后 render-markdown 偶发不刷新 (非 force 事件遇到 parse 未完成被 skip)
      -- 发一个 User autocmd, 由 change_events = {"User"} 触发 force re-parse
      local function refresh()
        vim.schedule(function()
          vim.api.nvim_exec_autocmds("User", { modeline = false })
        end)
      end
      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "markdown", "quarto" },
        callback = function(ev)
          local map = function(lhs, rhs)
            vim.keymap.set("n", lhs, function()
              vim.cmd("normal! " .. rhs)
              refresh()
            end, { buffer = ev.buf, silent = true, desc = "Jump + refresh render" })
          end
          map("gg", "gg")
          map("G", "G")
        end,
      })
    end,
  },
}
