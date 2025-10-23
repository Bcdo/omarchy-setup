return {
  "nvim-mini/mini.snippets",
  opts = function(_, opts)
    local mini_snippets = require("mini.snippets")
    
    -- Load custom snippets file
    opts.snippets = {
      mini_snippets.gen_loader.from_file(vim.fn.stdpath("config") .. "/snippets/cs.json"),
      mini_snippets.gen_loader.from_lang(),
    }
    
    return opts
  end,
}

