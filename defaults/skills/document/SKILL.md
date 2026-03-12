---
name: document
description: Generate or update documentation from code
user_invocable: true
---

<!-- abaris-ai-kit | Do not edit - managed by install.sh | Run install.sh --check to verify -->

# /document

Generate or update documentation from source code.

## Steps

1. **Determine scope** — Check args: specific file, folder, or "all". If no args, ask what to document.

2. **Detect documentation style** — Check existing docs for conventions:
   - TypeScript/JS: JSDoc (`/** */`) or TSDoc
   - C#: XML doc comments (`/// <summary>`)
   - Python: docstrings (Google/NumPy/Sphinx style)
   - README: existing structure and tone

3. **Analyze code** — Read the target code. Identify:
   - Exported/public functions, classes, interfaces
   - Parameters, return types, thrown exceptions
   - Side effects and important behavior
   - Usage examples from tests or calling code

4. **Generate documentation** — Write docs matching the detected style:
   - Function/method: description, params, returns, throws, example
   - Class/interface: purpose, usage pattern, key methods
   - Module/file: overview, exports, dependencies
   - README section: feature description, API reference, examples

5. **Present changes** — Show the generated docs as a diff. Ask user to approve before applying.

6. **Apply** — Write the approved documentation.

## Rules

- Match existing doc style — don't introduce JSDoc in a TSDoc project
- Document the why, not just the what — `/** Validates email format */` not `/** Checks string */`
- Skip obvious getters/setters — focus on non-trivial logic
- Include examples when the usage isn't obvious from the signature
- Never fabricate behavior — only document what the code actually does
