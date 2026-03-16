#!/usr/bin/env node

// ai-kit-engine CLI — Zero-dependency interactive scaffolder
// Uses only built-in Node.js modules

const readline = require("readline");
const fs = require("fs");
const path = require("path");
const { execSync } = require("child_process");

// ── ANSI Colors ──────────────────────────────────────────────────────────────

const c = {
  reset: "\x1b[0m",
  bold: "\x1b[1m",
  dim: "\x1b[2m",
  cyan: "\x1b[36m",
  green: "\x1b[32m",
  yellow: "\x1b[33m",
  red: "\x1b[31m",
  magenta: "\x1b[35m",
  gray: "\x1b[90m",
  white: "\x1b[97m",
  bgCyan: "\x1b[46m",
  bgGreen: "\x1b[42m",
};

const colorize = (color, text) => `${color}${text}${c.reset}`;
const cyan = (t) => colorize(c.cyan, t);
const green = (t) => colorize(c.green, t);
const yellow = (t) => colorize(c.yellow, t);
const red = (t) => colorize(c.red, t);
const gray = (t) => colorize(c.gray, t);
const bold = (t) => colorize(c.bold, t);
const dim = (t) => colorize(c.dim, t);

// ── Constants ────────────────────────────────────────────────────────────────

const ENGINE_ROOT = path.resolve(__dirname, "..");
const VERSION = fs.readFileSync(path.join(ENGINE_ROOT, "VERSION"), "utf8").trim();

const STACKS = [
  {
    key: "react",
    label: "React / Next.js / React Native / Expo",
    detect: ["package.json", "tsconfig.json"],
    rules_dir: "react",
  },
  {
    key: "dotnet",
    label: ".NET / C#",
    detect: ["*.csproj", "*.sln"],
    rules_dir: "dotnet",
  },
  {
    key: "python",
    label: "Python / FastAPI / Django",
    detect: ["pyproject.toml", "requirements.txt", "Pipfile"],
    rules_dir: "python",
  },
  {
    key: "go",
    label: "Go",
    detect: ["go.mod"],
    rules_dir: "go",
  },
  {
    key: "ruby",
    label: "Ruby / Rails",
    detect: ["Gemfile"],
    rules_dir: "ruby",
  },
  {
    key: "rust",
    label: "Rust",
    detect: ["Cargo.toml"],
    rules_dir: "rust",
  },
];

const INTEGRATIONS = [
  { key: "jira", label: "Jira (Atlassian MCP)" },
  { key: "azure-devops", label: "Azure DevOps (az CLI)" },
  { key: "bitbucket", label: "Bitbucket" },
  { key: "github", label: "GitHub (gh CLI)" },
  { key: "confluence", label: "Confluence (Atlassian MCP)" },
  { key: "figma", label: "Figma (MCP)" },
];

// ── Helpers ──────────────────────────────────────────────────────────────────

function printBanner() {
  console.log();
  console.log(
    `  ${c.cyan}${c.bold}╔══════════════════════════════════════╗${c.reset}`
  );
  console.log(
    `  ${c.cyan}${c.bold}║${c.reset}   ${c.bold}ai-kit-engine${c.reset} ${dim(`v${VERSION}`)}               ${c.cyan}${c.bold}║${c.reset}`
  );
  console.log(
    `  ${c.cyan}${c.bold}║${c.reset}   ${dim("Interactive Kit Scaffolder")}          ${c.cyan}${c.bold}║${c.reset}`
  );
  console.log(
    `  ${c.cyan}${c.bold}╚══════════════════════════════════════╝${c.reset}`
  );
  console.log();
}

function printHelp() {
  console.log(`
${bold("ai-kit-engine")} ${dim(`v${VERSION}`)}
${dim("Generic TUI installer engine for AI-assisted development kits")}

${bold("USAGE")}
  ${cyan("ai-kit-engine")} ${yellow("<command>")} ${dim("[options]")}

${bold("COMMANDS")}
  ${yellow("init")}       Scaffold a new AI kit project interactively

${bold("OPTIONS")}
  ${yellow("--help")}     Show this help message
  ${yellow("--version")}  Show version number

${bold("EXAMPLES")}
  ${dim("$")} npx ai-kit-engine init
  ${dim("$")} ai-kit-engine init
`);
}

function createRL() {
  return readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });
}

function ask(rl, question, defaultVal) {
  const defaultHint = defaultVal ? ` ${gray(`[${defaultVal}]`)}` : "";
  return new Promise((resolve) => {
    rl.question(`  ${cyan("?")} ${question}${defaultHint} `, (answer) => {
      resolve(answer.trim() || defaultVal || "");
    });
  });
}

function askMultiSelect(rl, prompt, items) {
  return new Promise((resolve) => {
    console.log();
    console.log(`  ${cyan("?")} ${prompt}`);
    console.log();
    items.forEach((item, i) => {
      console.log(`    ${yellow(`${i + 1}.`)} ${item.label}`);
    });
    console.log();
    rl.question(
      `  ${dim("Enter numbers separated by commas (e.g. 1,2,4):")} `,
      (answer) => {
        if (!answer.trim()) {
          resolve([]);
          return;
        }
        const indices = answer
          .split(",")
          .map((s) => parseInt(s.trim(), 10))
          .filter((n) => !isNaN(n) && n >= 1 && n <= items.length);
        const selected = [...new Set(indices)].map((i) => items[i - 1]);
        resolve(selected);
      }
    );
  });
}

function toSlug(name) {
  return name
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-|-$/g, "");
}

function generateKitToml(config) {
  const stackEntries = config.stacks
    .map((s) => {
      const detectArray = s.detect.map((d) => `"${d}"`).join(", ");
      return `[stacks.${s.key}]
label = "${s.label}"
detect = [${detectArray}]
rules_dir = "${s.rules_dir}"`;
    })
    .join("\n\n");

  const integrationEntries = config.integrations
    .map((i) => `  "${i.key}"`)
    .join(",\n");

  return `# ${config.kitName} — Kit Configuration
# Generated by ai-kit-engine v${VERSION}

[kit]
name = "${config.kitName}"
short_name = "${config.shortName}"
config_dir = "${config.configDir}"
watermark = "${config.watermark}"
tagline = "${config.tagline}"
ascii_art_file = "branding/ascii.txt"

[theme]
${config.customTheme ? `custom = true\n# TODO: Define custom theme colors` : `custom = false`}

[integrations]
enabled = [
${integrationEntries}
]

${stackEntries}
`;
}

function generateInstallSh(config) {
  return `#!/bin/bash
# ${config.kitName} — Installer
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENGINE="$SCRIPT_DIR/engine/install.sh"

if [ ! -f "$ENGINE" ]; then
    echo "Fetching installer engine..."
    git -C "$SCRIPT_DIR" submodule update --init --recursive 2>/dev/null
    if [ ! -f "$ENGINE" ]; then
        echo "Error: Could not fetch engine. Run: git submodule update --init"
        exit 1
    fi
fi

_ENGINE_TMP="$(mktemp)"
cp "$ENGINE" "$_ENGINE_TMP"
trap 'rm -f "$_ENGINE_TMP"' EXIT

exec bash "$_ENGINE_TMP" --kit-dir "$SCRIPT_DIR" "$@"
`;
}

function generateGitmodules(config) {
  return `[submodule "engine"]
\tpath = engine
\turl = https://github.com/MagnusPladsen/ai-kit-engine.git
\tbranch = main
`;
}

function printSummary(config, targetDir) {
  console.log();
  console.log(`  ${c.bold}${c.cyan}── Summary ──────────────────────────────────${c.reset}`);
  console.log();
  console.log(`  ${bold("Kit Name:")}       ${config.kitName}`);
  console.log(`  ${bold("Short Name:")}     ${config.shortName}`);
  console.log(`  ${bold("Config Dir:")}     ${config.configDir}`);
  console.log(`  ${bold("Watermark:")}      ${config.watermark}`);
  console.log(`  ${bold("Tagline:")}        ${config.tagline}`);
  console.log(`  ${bold("Directory:")}      ${targetDir}`);
  console.log(
    `  ${bold("Stacks:")}        ${config.stacks.length > 0 ? config.stacks.map((s) => s.key).join(", ") : dim("none")}`
  );
  console.log(
    `  ${bold("Integrations:")} ${config.integrations.length > 0 ? config.integrations.map((i) => i.key).join(", ") : dim("none")}`
  );
  console.log(
    `  ${bold("Custom Theme:")} ${config.customTheme ? "yes" : "no"}`
  );
  console.log();
  console.log(`  ${bold("Files to create:")}`);
  console.log(`    ${dim(".")}/${config.repoDir}/`);
  console.log(`    ${dim("├──")} kit.toml`);
  console.log(`    ${dim("├──")} install.sh`);
  console.log(`    ${dim("├──")} .gitmodules`);
  console.log(`    ${dim("├──")} VERSION`);
  console.log(`    ${dim("├──")} rules/`);
  console.log(`    ${dim("├──")} skills/`);
  console.log(`    ${dim("├──")} profiles/`);
  console.log(`    ${dim("├──")} plugins/`);
  console.log(`    ${dim("├──")} defaults/`);
  console.log(`    ${dim("└──")} branding/`);
  console.log();
}

// ── Init Command ─────────────────────────────────────────────────────────────

async function runInit() {
  printBanner();

  const rl = createRL();

  try {
    console.log(
      `  ${dim("Answer the prompts below to scaffold a new AI kit.")}`
    );
    console.log(
      `  ${dim("Press Enter to accept defaults shown in brackets.")}`
    );
    console.log();

    // Gather inputs
    const kitName = await ask(rl, "Kit name:", "My AI Kit");
    const defaultShort = toSlug(kitName);
    const shortName = await ask(rl, "Short name (used in filenames):", defaultShort);
    const configDir = await ask(rl, "Config directory name:", `.${shortName}`);
    const watermark = await ask(
      rl,
      "Watermark (shown in generated files):",
      `Managed by ${kitName}`
    );
    const tagline = await ask(
      rl,
      "Tagline (one-liner description):",
      `AI-assisted development kit`
    );
    const repoDir = await ask(
      rl,
      "Repository directory name:",
      `${shortName}`
    );

    const selectedStacks = await askMultiSelect(
      rl,
      "Which stacks should this kit support?",
      STACKS
    );

    const selectedIntegrations = await askMultiSelect(
      rl,
      "Which integrations should this kit include?",
      INTEGRATIONS
    );

    console.log();
    const themeAnswer = await ask(rl, "Use a custom theme?", "no");
    const customTheme =
      themeAnswer.toLowerCase() === "yes" ||
      themeAnswer.toLowerCase() === "y";

    const config = {
      kitName,
      shortName,
      configDir,
      watermark,
      tagline,
      repoDir,
      stacks: selectedStacks,
      integrations: selectedIntegrations,
      customTheme,
    };

    const targetDir = path.resolve(process.cwd(), config.repoDir);

    // Show summary
    printSummary(config, targetDir);

    const proceed = await ask(rl, "Create this kit?", "yes");
    if (
      proceed.toLowerCase() !== "yes" &&
      proceed.toLowerCase() !== "y"
    ) {
      console.log();
      console.log(`  ${yellow("Aborted.")} No files were created.`);
      console.log();
      rl.close();
      process.exit(0);
    }

    rl.close();

    // ── Create files ───────────────────────────────────────────────────────

    console.log();
    console.log(`  ${cyan("Creating kit structure...")}`);
    console.log();

    // Create directories
    const dirs = [
      "",
      "rules",
      "skills",
      "profiles",
      "plugins",
      "defaults",
      "branding",
    ];
    for (const dir of dirs) {
      const fullPath = path.join(targetDir, dir);
      fs.mkdirSync(fullPath, { recursive: true });
      console.log(`  ${green("+")} ${dim("mkdir")} ${config.repoDir}/${dir || "."}`);
    }

    // Create stack-specific rule directories
    for (const stack of selectedStacks) {
      const rulesDir = path.join(targetDir, "rules", stack.rules_dir);
      fs.mkdirSync(rulesDir, { recursive: true });
      console.log(
        `  ${green("+")} ${dim("mkdir")} ${config.repoDir}/rules/${stack.rules_dir}/`
      );

      // Create a placeholder rule file
      const placeholderPath = path.join(rulesDir, ".gitkeep");
      fs.writeFileSync(placeholderPath, "");
    }

    // kit.toml
    const kitTomlPath = path.join(targetDir, "kit.toml");
    fs.writeFileSync(kitTomlPath, generateKitToml(config));
    console.log(`  ${green("+")} ${dim("write")} ${config.repoDir}/kit.toml`);

    // install.sh
    const installShPath = path.join(targetDir, "install.sh");
    fs.writeFileSync(installShPath, generateInstallSh(config));
    fs.chmodSync(installShPath, 0o755);
    console.log(`  ${green("+")} ${dim("write")} ${config.repoDir}/install.sh ${dim("(executable)")}`);

    // .gitmodules
    const gitmodulesPath = path.join(targetDir, ".gitmodules");
    fs.writeFileSync(gitmodulesPath, generateGitmodules(config));
    console.log(
      `  ${green("+")} ${dim("write")} ${config.repoDir}/.gitmodules`
    );

    // VERSION
    const versionPath = path.join(targetDir, "VERSION");
    fs.writeFileSync(versionPath, "0.1.0\n");
    console.log(`  ${green("+")} ${dim("write")} ${config.repoDir}/VERSION`);

    // .gitkeep files for empty dirs
    for (const dir of ["skills", "profiles", "plugins", "defaults"]) {
      const gitkeepPath = path.join(targetDir, dir, ".gitkeep");
      fs.writeFileSync(gitkeepPath, "");
    }

    // Generate default ASCII art for the kit's short name
    const asciiArt = `███╗   ███╗ ██╗   ██╗   ██╗  ██╗ ██╗ ████████╗
████╗ ████║ ╚██╗ ██╔╝   ██║ ██╔╝ ██║ ╚══██╔══╝
██╔████╔██║  ╚████╔╝    █████╔╝  ██║    ██║
██║╚██╔╝██║   ╚██╔╝     ██╔═██╗  ██║    ██║
██║ ╚═╝ ██║    ██║      ██║  ██╗ ██║    ██║
╚═╝     ╚═╝    ╚═╝      ╚═╝  ╚═╝ ╚═╝    ╚═╝
`;
    const asciiArtPath = path.join(targetDir, "branding", "ascii.txt");
    fs.writeFileSync(asciiArtPath, asciiArt);
    console.log(`  ${green("+")} ${dim("write")} ${config.repoDir}/branding/ascii.txt`);

    // ── Git init ───────────────────────────────────────────────────────────

    console.log();
    console.log(`  ${cyan("Initializing git repository...")}`);

    try {
      execSync("git init", { cwd: targetDir, stdio: "pipe" });
      console.log(`  ${green("+")} ${dim("git init")}`);
    } catch (e) {
      console.log(
        `  ${yellow("!")} Could not initialize git repo: ${e.message}`
      );
    }

    // Add engine submodule
    console.log(`  ${cyan("Adding engine submodule...")}`);
    try {
      execSync(
        "git submodule add https://github.com/MagnusPladsen/ai-kit-engine.git engine",
        { cwd: targetDir, stdio: "pipe" }
      );
      console.log(`  ${green("+")} ${dim("git submodule add")} engine`);
    } catch (e) {
      console.log(
        `  ${yellow("!")} Could not add submodule automatically.`
      );
      console.log(
        `  ${dim("   Run manually:")} git submodule add https://github.com/MagnusPladsen/ai-kit-engine.git engine`
      );
    }

    // ── Done ───────────────────────────────────────────────────────────────

    console.log();
    console.log(
      `  ${c.green}${c.bold}╔══════════════════════════════════════╗${c.reset}`
    );
    console.log(
      `  ${c.green}${c.bold}║${c.reset}   ${green(bold("Kit created successfully!"))}          ${c.green}${c.bold}║${c.reset}`
    );
    console.log(
      `  ${c.green}${c.bold}╚══════════════════════════════════════╝${c.reset}`
    );
    console.log();
    console.log(`  ${bold("Next steps:")}`);
    console.log();
    console.log(`    ${yellow("1.")} ${dim("cd")} ${config.repoDir}`);
    console.log(`    ${yellow("2.")} Add rules to ${cyan("rules/")} for your stacks`);
    console.log(`    ${yellow("3.")} Add skills to ${cyan("skills/")} for custom workflows`);
    console.log(`    ${yellow("4.")} Add profiles to ${cyan("profiles/")} for personas`);
    console.log(`    ${yellow("5.")} Edit ${cyan("kit.toml")} to fine-tune configuration`);
    console.log(`    ${yellow("6.")} Run ${cyan("bash install.sh")} to test the installer`);
    console.log();
    console.log(`  ${yellow("Tip:")} Edit ${bold("branding/ascii.txt")} to customize your logo.`);
    console.log(`  ${dim("     Use https://patorjk.com/software/taag/ (font: ANSI Shadow) to generate block text.")}`);
    console.log();
    console.log(
      `  ${dim("Documentation:")} https://github.com/MagnusPladsen/ai-kit-engine`
    );
    console.log();
  } catch (e) {
    rl.close();
    console.error(`\n  ${red("Error:")} ${e.message}\n`);
    process.exit(1);
  }
}

// ── Main ─────────────────────────────────────────────────────────────────────

function main() {
  const args = process.argv.slice(2);

  if (args.includes("--version") || args.includes("-v")) {
    console.log(VERSION);
    process.exit(0);
  }

  if (args.includes("--help") || args.includes("-h") || args.length === 0) {
    printHelp();
    process.exit(0);
  }

  const command = args[0];

  switch (command) {
    case "init":
      runInit().catch((e) => {
        console.error(`\n  ${red("Error:")} ${e.message}\n`);
        process.exit(1);
      });
      break;

    default:
      console.error(`\n  ${red("Unknown command:")} ${command}`);
      console.error(`  Run ${cyan("ai-kit-engine --help")} for usage.\n`);
      process.exit(1);
  }
}

main();
