local M = {}

local prompts = require("ai_commit_msg.prompts")
local config_mod = require("ai_commit_msg.config")
local providers = require("ai_commit_msg.providers")
local uv = vim.uv or vim.loop

local function is_tiny_diff(diff, opts)
  opts = opts or {}
  local max_changed_lines = opts.max_changed_lines or 5
  local max_files = opts.max_files or 1

  local changed = 0
  local files = 0
  for line in diff:gmatch("[^\n]+") do
    if line:match("^diff %-%-git ") then
      files = files + 1
    elseif line:match("^[+%-]") and not line:match("^%+%+%+") and not line:match("^%-%-%-") then
      changed = changed + 1
    end
    if changed > max_changed_lines or files > max_files then
      return false
    end
  end
  return changed > 0
end

local function read_file(path)
  local f = io.open(path, "r")
  if not f then
    return nil, "Failed to open " .. path
  end
  local data = f:read("*a")
  f:close()
  return data
end

local function list_diff_files(dir)
  local handle = io.popen("ls -1 '" .. dir .. "' 2>/dev/null")
  if not handle then
    return {}
  end
  local files = {}
  for file in handle:read("*a"):gmatch("([^\n]+)") do
    if file:match("%.diff$") then
      table.insert(files, dir .. "/" .. file)
    end
  end
  handle:close()
  table.sort(files)
  return files
end

local function get_models_for_provider(pcfg)
  local models = {}
  if pcfg.pricing then
    for model_name, _ in pairs(pcfg.pricing) do
      table.insert(models, model_name)
    end
    table.sort(models)
  end
  if #models == 0 and pcfg.model then
    table.insert(models, pcfg.model)
  end
  return models
end

local function build_user_prompt(cfg, diff)
  if not cfg.prompt then
    return diff
  end
  if cfg.prompt:find("{diff}", 1, true) then
    local before, after = cfg.prompt:match("^(.*)%{diff%}(.*)$")
    if before and after then
      return before .. diff .. after
    else
      return cfg.prompt .. "\n\n" .. diff
    end
  else
    return cfg.prompt .. "\n\n" .. diff
  end
end

-- Runs a matrix of (provider x model x diff) and captures outputs.
-- opts = {
--   diffs_dir = "fixtures/diffs", -- directory containing .diff files
--   auto_short = true,             -- pick short prompt for tiny diffs
--   tiny = { max_changed_lines = 5, max_files = 1 },
--   providers = { "openai", "anthropic", "gemini" },
--   dry_run = false,               -- if true, do not call network APIs; just print prompt info
--   out_file = "",                -- optional filepath to write JSONL results
-- }
function M.run_matrix(opts)
  opts = opts or {}
  local diffs_dir = opts.diffs_dir or "fixtures/diffs"
  local out_file = opts.out_file
  local auto_short = opts.auto_short ~= false

  local defaults = config_mod.default
  local provider_list = opts.providers or { "openai", "anthropic", "gemini" }
  local diff_files = list_diff_files(diffs_dir)

  if #diff_files == 0 then
    vim.notify("No .diff files found in " .. diffs_dir, vim.log.levels.WARN)
    return
  end

  local results = {}
  local pending = 0

  local function write_result(rec)
    table.insert(results, rec)
    if out_file and out_file ~= "" then
      local f = io.open(out_file, "a")
      if f then
        f:write(vim.json.encode(rec) .. "\n")
        f:close()
      end
    end
  end

  for _, diff_path in ipairs(diff_files) do
    local diff, err = read_file(diff_path)
    if not diff then
      vim.notify(err, vim.log.levels.ERROR)
    else
      local tiny = is_tiny_diff(diff, opts.tiny)
      for _, pname in ipairs(provider_list) do
        local pcfg = defaults.providers[pname]
        if not pcfg then
          vim.notify("Unknown provider in matrix: " .. tostring(pname), vim.log.levels.WARN)
        else
          local models = get_models_for_provider(pcfg)
          for _, model in ipairs(models) do
            local cfg = vim.tbl_deep_extend("force", {}, pcfg)
            cfg.provider = pname
            cfg.model = model
            cfg.system_prompt = (auto_short and tiny) and prompts.SHORT_SYSTEM_PROMPT or prompts.DEFAULT_SYSTEM_PROMPT

            if opts.dry_run then
              -- Only compute the prompt text to inspect lengths
              local start_ns = uv and uv.hrtime and uv.hrtime() or nil
              local user_prompt = build_user_prompt(cfg, diff)
              local duration_ms
              if start_ns and uv and uv.hrtime then
                duration_ms = math.floor((uv.hrtime() - start_ns) / 1e6)
              end

              write_result({
                diff = diff_path,
                provider = pname,
                model = model,
                short = (cfg.system_prompt == prompts.SHORT_SYSTEM_PROMPT),
                system_prompt_chars = #cfg.system_prompt,
                user_prompt_chars = #user_prompt,
                duration_ms = duration_ms,
              })
            else
              pending = pending + 1
              local start_ns = uv and uv.hrtime and uv.hrtime() or nil
              providers.call_api(cfg, diff, function(success, message, usage)
                local duration_ms
                if start_ns and uv and uv.hrtime then
                  duration_ms = math.floor((uv.hrtime() - start_ns) / 1e6)
                end
                write_result({
                  diff = diff_path,
                  provider = pname,
                  model = model,
                  short = (cfg.system_prompt == prompts.SHORT_SYSTEM_PROMPT),
                  success = success,
                  message = message,
                  usage = usage,
                  duration_ms = duration_ms,
                })
                pending = pending - 1
              end)
            end
          end
        end
      end
    end
  end

  if not opts.dry_run then
    -- Wait until all async calls finish (with a timeout)
    vim.wait(30000, function()
      return pending == 0
    end, 50)
  end

  return results
end

-- Run matrix over the provided live diff string (no fixtures).
-- Returns results array similar to run_matrix, with `diff = "<live>"`.
function M.run_live_matrix(diff, opts)
  opts = opts or {}
  local auto_short = opts.auto_short ~= false
  local defaults = config_mod.default
  local provider_list = opts.providers or { "openai", "anthropic", "gemini" }
  local tiny = is_tiny_diff(diff, opts.tiny)

  local results = {}
  local pending = 0

  local function write_result(rec)
    table.insert(results, rec)
  end

  for _, pname in ipairs(provider_list) do
    local pcfg = defaults.providers[pname]
    if pcfg then
      local models = get_models_for_provider(pcfg)
      for _, model in ipairs(models) do
        local cfg = vim.tbl_deep_extend("force", {}, pcfg)
        cfg.provider = pname
        cfg.model = model
        cfg.system_prompt = (auto_short and tiny) and prompts.SHORT_SYSTEM_PROMPT or prompts.DEFAULT_SYSTEM_PROMPT

        if opts.dry_run then
          local start_ns = uv and uv.hrtime and uv.hrtime() or nil
          local user_prompt = build_user_prompt(cfg, diff)
          local duration_ms
          if start_ns and uv and uv.hrtime then
            duration_ms = math.floor((uv.hrtime() - start_ns) / 1e6)
          end
          write_result({
            diff = "<live>",
            provider = pname,
            model = model,
            short = (cfg.system_prompt == prompts.SHORT_SYSTEM_PROMPT),
            system_prompt_chars = #cfg.system_prompt,
            user_prompt_chars = #user_prompt,
            duration_ms = duration_ms,
          })
        else
          pending = pending + 1
          local start_ns = uv and uv.hrtime and uv.hrtime() or nil
          providers.call_api(cfg, diff, function(success, message, usage)
            local duration_ms
            if start_ns and uv and uv.hrtime then
              duration_ms = math.floor((uv.hrtime() - start_ns) / 1e6)
            end
            write_result({
              diff = "<live>",
              provider = pname,
              model = model,
              short = (cfg.system_prompt == prompts.SHORT_SYSTEM_PROMPT),
              success = success,
              message = message,
              usage = usage,
              duration_ms = duration_ms,
            })
            pending = pending - 1
          end)
        end
      end
    end
  end

  if not opts.dry_run then
    vim.wait(30000, function()
      return pending == 0
    end, 50)
  end

  return results
end

return M
