-- Anaconda venv-selector configuration
-- Discovers conda environments under /opt/anaconda/envs

return {
  {
    "linux-cultist/venv-selector.nvim",
    opts = {
      settings = {
        search = {
          anaconda_envs = {
            command = "fd bin/python$ /opt/anaconda/envs --full-path --no-follow",
          },
          anaconda_base = {
            command = "fd bin/python$ /opt/anaconda --full-path --no-follow --max-depth 3",
          },
        },
      },
    },
  },
}
