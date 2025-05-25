local plenary = require('plenary')
local json = require('rapidjson')
local path = plenary.path

niovi = {}
niovi.path = path
niovi.json = json

local nix = json.decode(path.new(nix_path):read())
niovi.nix = nix

local lspconfig
local lsp_status
local default_lsp_capabilities

if nix.sizeAtLeast.med then
  lspconfig = require('lspconfig')
  lsp_status = require('lsp-status')
  lsp_status.register_progress()

  default_lsp_capabilities = vim.tbl_deep_extend('keep', nix.lsp_capabilities,
    lsp_status.capabilities)
end

niovi.fileUrlEdit = function(url)
  local pattern = "^file://(.*)"
  local _, _, filePath = string.find(url, pattern)
  command('new ' .. filePath)
end

niovi.lsp = {}
niovi.lsp.setup_from_nix = function(neim, datom)
  local lang_capabilities = datom.capabilities or {}

  local config = {
    cmd = datom.cmd,
    capabilities = vim.tbl_deep_extend('force', default_lsp_capabilities,
      lang_capabilities),
    on_attach = lsp_status.on_attach,
    settings = datom.settings or {}
  };

  lspconfig[neim].setup(config)

end

niovi.lsp.setup = function()
  for neim, datom in pairs(niovi.nix.langServers) do
    niovi.lsp.setup_from_nix(neim, datom)
  end
end

niovi.setup = function() if nix.sizeAtLeast.med then niovi.lsp.setup() end end

niovi.setup()
