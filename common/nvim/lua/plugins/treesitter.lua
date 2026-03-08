local ensure_installed = {
  "bash", "c", "c_sharp", "css", "diff", "go", "gomod", "gosum",
  "html", "javascript", "json", "lua", "luadoc", "markdown",
  "markdown_inline", "powershell", "python", "query", "regex", "rust",
  "toml", "tsx", "typescript", "vim", "vimdoc", "yaml",
}

return {
  "nvim-treesitter/nvim-treesitter",
  build = ":TSUpdate",
  event = { "BufReadPost", "BufNewFile" },
  config = function()
    -- Install missing parsers (new API has no ensure_installed option)
    local installed = require("nvim-treesitter").get_installed()
    local to_install = vim.tbl_filter(function(lang)
      return not vim.list_contains(installed, lang)
    end, ensure_installed)
    if #to_install > 0 then
      require("nvim-treesitter").install(to_install)
    end

    -- Enable treesitter highlighting and indentation per buffer
    vim.api.nvim_create_autocmd("FileType", {
      callback = function(args)
        if pcall(vim.treesitter.start, args.buf) then
          vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end
      end,
    })
  end,
}
