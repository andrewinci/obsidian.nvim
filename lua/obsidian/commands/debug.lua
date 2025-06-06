local Workspace = require "obsidian.workspace"
local Path = require "obsidian.path"
local log = require "obsidian.log"
local util = require "obsidian.util"
local VERSION = require "obsidian.version"

---@return { available: boolean, refs: boolean|?, tags: boolean|?, new: boolean|?, sources: string[]|? }
local function check_completion_with_nvim_cmp()
  local ok, cmp = pcall(require, "cmp")
  if not ok then
    return { available = false }
  end

  local cmp_refs = false
  local cmp_tags = false
  local cmp_new = false

  ---@type string[]
  local sources = vim.tbl_map(function(source)
    if source.name == "obsidian" then
      cmp_refs = true
    elseif source.name == "obsidian_tags" then
      cmp_tags = true
    elseif source.name == "obsidian_new" then
      cmp_new = true
    end
    return source.name
  end, cmp.get_config().sources)

  return { available = true, refs = cmp_refs, tags = cmp_tags, new = cmp_new, sources = sources }
end

---@return { available: boolean, refs: boolean|?, tags: boolean|?, new: boolean|?, sources: string[]|? }
local function check_completion_with_blink()
  local require_ok, blink_sources_lib = pcall(require, "blink.cmp.sources.lib")
  if not require_ok then
    return { available = false }
  end

  local cmp_refs = pcall(blink_sources_lib.get_provider_by_id, "obsidian")
  local cmp_tags = pcall(blink_sources_lib.get_provider_by_id, "obsidian_tags")
  local cmp_new = pcall(blink_sources_lib.get_provider_by_id, "obsidian_new")

  local sources = {}
  local get_providers_ok, providers = pcall(blink_sources_lib.get_all_providers)
  if get_providers_ok then
    vim.tbl_map(function(provider)
      table.insert(sources, provider.name)
    end, providers)
  end

  return { available = true, refs = cmp_refs ~= nil, tags = cmp_tags, new = cmp_new, sources = sources }
end

---@param client obsidian.Client
---@param data CommandArgs
return function(client, data)
  data = data or {}

  local info = util.get_plugin_info() or {}
  log.lazy_info("Obsidian.nvim v%s (%s)", VERSION, info.commit or "unknown commit")

  log.lazy_info "Status:"
  log.lazy_info("  • buffer directory: %s", client.buf_dir)
  log.lazy_info("  • working directory: %s", Path.cwd())

  log.lazy_info "Workspaces:"
  log.lazy_info("  ✓ active workspace: %s", client.current_workspace)
  for _, workspace_spec in ipairs(client.opts.workspaces) do
    local workspace = Workspace.new_from_spec(workspace_spec)
    if workspace ~= client.current_workspace then
      log.lazy_info("  ✗ inactive workspace: %s", workspace)
    end
  end

  log.lazy_info "Dependencies:"

  for _, plugin in ipairs {
    "plenary.nvim",
    "nvim-cmp",
    "blink.cmp",
    "telescope.nvim",
    "fzf-lua",
    "mini.pick",
    "snacks.pick",
  } do
    local plugin_info = util.get_plugin_info(plugin)
    if plugin_info ~= nil then
      log.lazy_info("  ✓ %s: %s", plugin, plugin_info.commit or "unknown")
    end
  end

  log.lazy_info "Integrations:"
  log.lazy_info("  ✓ picker: %s", client:picker())

  if client.opts.completion.nvim_cmp then
    local nvim_cmp_status = check_completion_with_nvim_cmp()
    if nvim_cmp_status.available then
      log.lazy_info(
        "  ✓ completion: enabled (nvim-cmp) %s refs, %s tags, %s new",
        nvim_cmp_status.refs and "✓" or "✗",
        nvim_cmp_status.tags and "✓" or "✗",
        nvim_cmp_status.new and "✓" or "✗"
      )

      if nvim_cmp_status.sources then
        log.lazy_info "    all sources:"
        for _, source in ipairs(nvim_cmp_status.sources) do
          log.lazy_info("      • %s", source)
        end
      end
    else
      log.lazy_info "  ✓ completion: unavailable"
    end
  elseif client.opts.completion.blink then
    local blink_status = check_completion_with_blink()
    if blink_status.available then
      log.lazy_info(
        "  ✓ completion: enabled (blink) %s refs, %s tags, %s new",
        blink_status.refs and "✓" or "✗",
        blink_status.tags and "✓" or "✗",
        blink_status.new and "✓" or "✗"
      )

      if blink_status.sources then
        log.lazy_info "    all sources:"
        for _, source in ipairs(blink_status.sources) do
          log.lazy_info("      • %s", source)
        end
      end
    else
      log.lazy_info "  ✓ completion: unavailable"
    end
  else
    log.lazy_info "  ✗ completion: disabled"
  end

  log.lazy_info "Tools:"
  log.lazy_info("  ✓ rg: %s", util.get_external_dependency_info "rg" or "not found")

  log.lazy_info "Environment:"
  log.lazy_info("  • operating system: %s", util.get_os())

  log.lazy_info "Config:"
  log.lazy_info("  • notes_subdir: %s", client.opts.notes_subdir)

  log.flush { raw_print = data.raw_print }
end
