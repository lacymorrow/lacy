import { generateText, tool } from "ai"
import { openai } from "@ai-sdk/openai"
import { anthropic } from "@ai-sdk/anthropic"
import { z } from "zod"
import * as fs from "fs/promises"
import * as path from "path"
import { execSync } from "child_process"
import chalk from "chalk"

interface AgentConfig {
  model: string
  provider: string
  apiKey: string
  outputJson: boolean
}

export class Agent {
  private config: AgentConfig
  private cwd: string

  constructor(config: AgentConfig) {
    this.config = config
    this.cwd = process.cwd()
  }

  private getModel() {
    if (this.config.provider === "anthropic") {
      return anthropic(this.config.model, {
        apiKey: this.config.apiKey,
      })
    }
    return openai(this.config.model, {
      apiKey: this.config.apiKey,
    })
  }

  private log(message: string, type: "info" | "success" | "error" | "tool" = "info") {
    if (this.config.outputJson) return

    const prefix = {
      info: chalk.blue("ℹ"),
      success: chalk.green("✓"),
      error: chalk.red("✗"),
      tool: chalk.yellow("🔧"),
    }[type]

    console.log(`${prefix} ${message}`)
  }

  private getTools() {
    return {
      readFile: tool({
        description: "Read the contents of a file",
        parameters: z.object({
          path: z.string().describe("File path relative to current directory"),
        }),
        execute: async ({ path: filePath }) => {
          try {
            const fullPath = path.isAbsolute(filePath) 
              ? filePath 
              : path.join(this.cwd, filePath)
            
            this.log(`Reading file: ${filePath}`, "tool")
            const content = await fs.readFile(fullPath, "utf-8")
            
            // Add line numbers for better context
            const lines = content.split("\n")
            const numbered = lines.map((line, i) => `${(i + 1).toString().padStart(4)} | ${line}`).join("\n")
            
            return { success: true, content: numbered, path: filePath }
          } catch (error: any) {
            return { success: false, error: error.message }
          }
        },
      }),

      writeFile: tool({
        description: "Write content to a file",
        parameters: z.object({
          path: z.string().describe("File path relative to current directory"),
          content: z.string().describe("Content to write"),
        }),
        execute: async ({ path: filePath, content }) => {
          try {
            const fullPath = path.isAbsolute(filePath) 
              ? filePath 
              : path.join(this.cwd, filePath)
            
            this.log(`Writing file: ${filePath}`, "tool")
            
            // Create directory if it doesn't exist
            const dir = path.dirname(fullPath)
            await fs.mkdir(dir, { recursive: true })
            
            await fs.writeFile(fullPath, content, "utf-8")
            return { success: true, message: `File written: ${filePath}` }
          } catch (error: any) {
            return { success: false, error: error.message }
          }
        },
      }),

      listDirectory: tool({
        description: "List files and directories",
        parameters: z.object({
          path: z.string().default(".").describe("Directory path"),
          recursive: z.boolean().default(false).describe("List recursively"),
        }),
        execute: async ({ path: dirPath, recursive }) => {
          try {
            const fullPath = path.isAbsolute(dirPath) 
              ? dirPath 
              : path.join(this.cwd, dirPath)
            
            this.log(`Listing directory: ${dirPath}`, "tool")
            
            if (recursive) {
              const output = execSync(`find "${fullPath}" -maxdepth 3 -type f`, {
                encoding: "utf-8",
                cwd: this.cwd,
              })
              return { success: true, files: output.trim().split("\n") }
            } else {
              const entries = await fs.readdir(fullPath, { withFileTypes: true })
              const files = entries.map(entry => {
                const type = entry.isDirectory() ? "📁" : "📄"
                return `${type} ${entry.name}`
              })
              return { success: true, files }
            }
          } catch (error: any) {
            return { success: false, error: error.message }
          }
        },
      }),

      searchFiles: tool({
        description: "Search for patterns in files",
        parameters: z.object({
          pattern: z.string().describe("Search pattern or regex"),
          filePattern: z.string().default("*").describe("File pattern (e.g., *.ts)"),
        }),
        execute: async ({ pattern, filePattern }) => {
          try {
            this.log(`Searching for: ${pattern}`, "tool")
            
            // Try ripgrep first (faster), fallback to grep
            let command: string
            try {
              execSync("which rg", { stdio: "ignore" })
              command = `rg --max-count 50 -n "${pattern}"${filePattern !== "*" ? ` --glob "${filePattern}"` : ""}`
            } catch {
              command = `grep -r -n "${pattern}" .${filePattern !== "*" ? ` --include="${filePattern}"` : ""} | head -50`
            }
            
            const output = execSync(command, {
              encoding: "utf-8",
              cwd: this.cwd,
              stdio: ["ignore", "pipe", "ignore"],
            }).trim()
            
            const matches = output ? output.split("\n") : []
            return { 
              success: true, 
              matchCount: matches.length,
              matches: matches.slice(0, 20) // Limit to first 20 for readability
            }
          } catch (error: any) {
            // No matches is not an error
            if (error.status === 1) {
              return { success: true, matchCount: 0, matches: [] }
            }
            return { success: false, error: error.message }
          }
        },
      }),

      runCommand: tool({
        description: "Execute a shell command",
        parameters: z.object({
          command: z.string().describe("Command to execute"),
        }),
        execute: async ({ command }) => {
          try {
            this.log(`Running command: ${command}`, "tool")
            
            const output = execSync(command, {
              encoding: "utf-8",
              cwd: this.cwd,
              maxBuffer: 1024 * 1024 * 10, // 10MB buffer
            })
            
            return { 
              success: true, 
              output: output.slice(0, 2000), // Limit output for readability
              truncated: output.length > 2000
            }
          } catch (error: any) {
            return { 
              success: false, 
              error: error.message,
              stderr: error.stderr?.toString() || "",
              code: error.status
            }
          }
        },
      }),

      gitStatus: tool({
        description: "Get git repository status",
        parameters: z.object({}),
        execute: async () => {
          try {
            this.log("Getting git status", "tool")
            
            const status = execSync("git status --porcelain -b", {
              encoding: "utf-8",
              cwd: this.cwd,
            })
            
            const branch = execSync("git branch --show-current", {
              encoding: "utf-8",
              cwd: this.cwd,
            }).trim()
            
            return { 
              success: true, 
              branch,
              status: status || "Working tree clean"
            }
          } catch (error: any) {
            return { success: false, error: "Not a git repository" }
          }
        },
      }),

      editFile: tool({
        description: "Edit specific parts of a file",
        parameters: z.object({
          path: z.string().describe("File path"),
          oldContent: z.string().describe("Content to replace"),
          newContent: z.string().describe("New content"),
          replaceAll: z.boolean().default(false).describe("Replace all occurrences"),
        }),
        execute: async ({ path: filePath, oldContent, newContent, replaceAll }) => {
          try {
            const fullPath = path.isAbsolute(filePath) 
              ? filePath 
              : path.join(this.cwd, filePath)
            
            this.log(`Editing file: ${filePath}`, "tool")
            
            let content = await fs.readFile(fullPath, "utf-8")
            
            if (replaceAll) {
              content = content.replaceAll(oldContent, newContent)
            } else {
              if (!content.includes(oldContent)) {
                return { success: false, error: "Old content not found in file" }
              }
              content = content.replace(oldContent, newContent)
            }
            
            await fs.writeFile(fullPath, content, "utf-8")
            return { success: true, message: `File edited: ${filePath}` }
          } catch (error: any) {
            return { success: false, error: error.message }
          }
        },
      }),
    }
  }

  async execute(query: string) {
    this.log(`Processing: ${query}`, "info")

    const systemPrompt = `You are an advanced coding assistant integrated into a shell environment. You have direct access to the filesystem and can:

- Read, write, and edit files
- Search through codebases
- Execute shell commands
- Work with git repositories

Current directory: ${this.cwd}

Be concise and practical. Execute tools to accomplish tasks. When making changes, explain what you're doing.`

    try {
      const result = await generateText({
        model: this.getModel(),
        system: systemPrompt,
        prompt: query,
        tools: this.getTools(),
        maxToolRoundtrips: 5,
        temperature: 0.3,
      })

      if (this.config.outputJson) {
        // Output JSON for shell integration
        console.log(JSON.stringify({
          success: true,
          response: result.text,
          toolCalls: result.toolCalls,
        }))
      } else {
        // Pretty print for terminal
        console.log("\n" + chalk.cyan("Response:"))
        console.log(result.text)
        
        if (result.toolCalls && result.toolCalls.length > 0) {
          console.log("\n" + chalk.green(`✓ Executed ${result.toolCalls.length} tool(s)`))
        }
      }
    } catch (error: any) {
      if (this.config.outputJson) {
        console.log(JSON.stringify({
          success: false,
          error: error.message,
        }))
      } else {
        this.log(`Error: ${error.message}`, "error")
      }
      throw error
    }
  }
}