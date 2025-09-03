local M = {}

function M.call_api(config, diff, callback)
  local api_key = os.getenv("GEMINI_API_KEY")
  if not api_key or api_key == "" then
    callback(false, "GEMINI_API_KEY environment variable not set")
    return
  end

  local prompt
  if config.prompt:find("{diff}", 1, true) then
    local before, after = config.prompt:match("^(.*)%{diff%}(.*)$")
    if before and after then
      prompt = before .. diff .. after
    else
      prompt = config.prompt .. "\n\n" .. diff
    end
  else
    prompt = config.prompt .. "\n\n" .. diff
  end

  vim.notify("ai-commit-msg.nvim: Prompt length: " .. #prompt .. " chars", vim.log.levels.DEBUG)

  local max_tokens = config.max_tokens or 1000

  -- Prefer using systemInstruction + user content for clarity
  local payload_tbl = {
    systemInstruction = {
      parts = {
        { text = config.system_prompt or "" },
      },
    },
    contents = {
      {
        role = "user",
        parts = {
          { text = prompt },
        },
      },
    },
    generationConfig = {
      maxOutputTokens = max_tokens,
      temperature = config.temperature or 0.3,
    },
  }

  -- Do not include reasoningEffort: Gemini API rejects unknown fields

  local payload = vim.json.encode(payload_tbl)

  local curl_args = {
    "curl",
    "-X",
    "POST",
    "https://generativelanguage.googleapis.com/v1beta/models/" .. config.model .. ":generateContent?key=" .. api_key,
    "-H",
    "Content-Type: application/json",
    "-d",
    payload,
    "--silent",
    "--show-error",
  }

  vim.system(curl_args, {}, function(res)
    if res.code ~= 0 then
      callback(false, "API request failed: " .. (res.stderr or "Unknown error"))
      return
    end

    local ok, response = pcall(vim.json.decode, res.stdout)
    if not ok then
      callback(false, "Failed to parse API response: " .. tostring(response))
      return
    end

    if response.error then
      callback(false, "Gemini API error: " .. (response.error.message or "Unknown error"))
      return
    end

    -- Handle safety blocks and prompt feedback
    if response.promptFeedback and response.promptFeedback.blockReason then
      local reason = response.promptFeedback.blockReason
      callback(false, "Gemini blocked: " .. tostring(reason))
      return
    end

    vim.notify("ai-commit-msg.nvim: Full API response: " .. vim.inspect(response), vim.log.levels.DEBUG)

    if response.candidates and response.candidates[1] then
      local cand = response.candidates[1]
      local text
      -- Primary: parts with text
      if cand.content and cand.content.parts then
        local parts = cand.content.parts
        local accum = {}
        for _, p in ipairs(parts) do
          if type(p) == "table" and p.text then
            table.insert(accum, p.text)
          end
        end
        if #accum > 0 then
          text = table.concat(accum, "\n")
        end
      end
      -- Alternate: content as array of parts-like tables
      if not text and cand.content and cand.content[1] and cand.content[1].text then
        text = cand.content[1].text
      end
      -- Fallback: some responses may include text directly
      if not text and cand.text then
        text = cand.text
      end

      if text then
        local commit_msg = text
      commit_msg = commit_msg:gsub("^```%w*\n", ""):gsub("\n```$", ""):gsub("^`", ""):gsub("`$", "")
      commit_msg = vim.trim(commit_msg)

      -- Extract token usage if available
      local usage = nil
      if response.usageMetadata then
        usage = {
          input_tokens = response.usageMetadata.promptTokenCount or 0,
          output_tokens = response.usageMetadata.candidatesTokenCount or 0,
        }
      end

        callback(true, commit_msg, usage)
        return
      end

      -- Provide more helpful diagnostics
      local finish = cand.finishReason or "unknown"
      callback(false, "Unexpected Gemini response (finishReason=" .. tostring(finish) .. ")")
      return
    end

    callback(false, "Unexpected Gemini response shape (no candidates)")
  end)
end

return M
