#!/bin/bash

curl -L \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $COPILOT_TOKEN" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  -H "Content-Type: application/json" \
  https://models.github.ai/inference/chat/completions \
  -d '{
    "model": "openai/gpt-4o-mini",
    "messages": [
      {
        "role": "system",
        "content": "You are a helpful assistant that writes clear, concise git commit messages."
      },
      {
        "role": "user",
        "content": "Generate a commit message for this diff:\n\n+ function hello() {\n+   console.log(\"Hello world\");\n+ }"
      }
    ]
  }'
