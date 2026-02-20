-- SDKMAN JDK runtime discovery for jdtls
-- Scans ~/.sdkman/candidates/java/ and registers all installed JDKs
-- so jdtls can compile projects targeting different Java versions.

local function discover_sdkman_runtimes()
  local sdkman_java = vim.fn.expand("~/.sdkman/candidates/java")
  local runtimes = {}

  local entries = vim.fn.glob(sdkman_java .. "/*", false, true)
  for _, path in ipairs(entries) do
    local name = vim.fn.fnamemodify(path, ":t")
    -- Skip the "current" symlink
    if name ~= "current" then
      -- Extract major version: "25.0.2-tem" → 25, "17.0.10-tem" → 17
      local major = name:match("^(%d+)")
      if major then
        table.insert(runtimes, {
          name = "JavaSE-" .. major,
          path = path,
        })
      end
    end
  end

  return runtimes
end

return {
  {
    "mfussenegger/nvim-jdtls",
    opts = function(_, opts)
      local runtimes = discover_sdkman_runtimes()
      if #runtimes > 0 then
        opts.settings = vim.tbl_deep_extend("force", opts.settings or {}, {
          java = {
            configuration = {
              runtimes = runtimes,
            },
          },
        })
      end
    end,
  },
}
