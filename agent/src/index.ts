#!/usr/bin/env bun

import { Agent } from "./agent"
import { parseArgs } from "util"

async function main() {
  const { values, positionals } = parseArgs({
    args: process.argv.slice(2),
    options: {
      model: { type: "string", default: "gpt-4" },
      provider: { type: "string", default: "openai" },
      "api-key": { type: "string" },
      json: { type: "boolean", default: false },
      help: { type: "boolean", default: false },
    },
    strict: false,
    allowPositionals: true,
  })

  if (values.help || positionals.length === 0) {
    console.log(`
Lacy Agent - AI-powered coding assistant

Usage: lacy-agent [options] <query>

Options:
  --model <model>      AI model to use (default: gpt-4)
  --provider <provider> Provider (openai or anthropic, default: openai)
  --api-key <key>      API key (or set OPENAI_API_KEY/ANTHROPIC_API_KEY)
  --json               Output JSON for shell integration
  --help               Show this help

Examples:
  lacy-agent "read the package.json file"
  lacy-agent "search for TODO comments in the codebase"
  lacy-agent "create a new function to parse JSON"
`)
    process.exit(0)
  }

  const query = positionals.join(" ")
  const apiKey = values["api-key"] || 
    (values.provider === "anthropic" ? process.env.ANTHROPIC_API_KEY : process.env.OPENAI_API_KEY)

  if (!apiKey) {
    console.error("Error: No API key provided. Set --api-key or environment variable")
    process.exit(1)
  }

  try {
    const agent = new Agent({
      model: values.model as string,
      provider: values.provider as string,
      apiKey: apiKey as string,
      outputJson: values.json as boolean,
    })

    await agent.execute(query)
  } catch (error) {
    console.error("Error:", error)
    process.exit(1)
  }
}

main().catch(console.error)