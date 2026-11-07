# WoW-AddOns: Repository Instructions for Coding Agents

## Purpose and scope

This Git repository contains multiple **independent World of Warcraft addons** primarily targeting **World of Warcraft: Forever**.

- The repository root is `WoW-AddOns/`.
- Each addon lives in its own top-level directory, for example `BlazeTweaks/`.
- Treat each addon as an independent project with its own `.toc` file, Lua/XML files, dependencies, settings, and conventions.
- These instructions apply repository-wide. More specific instructions in an addon's own `AGENTS.md`, if present, supplement these rules for that addon.
- Do not assume that patterns or preferences in one addon apply to all other addons.

## WoW Forever compatibility (critical)

- Target **WoW Forever**, not Classic Era, Anniversary, or standard Retail, unless the task explicitly requests additional flavors.
- Forever uses a **modern Retail/Mainline-derived addon API**, despite its Classic-like content and low interface number. Favor current `C_*` APIs where applicable; do not port in old Classic API calls without verifying they exist.
- As of November 2026, the reported interface number is **`16001`**. Verify against the actual installed client when version-sensitive work is required (in game: `/dump select(4, GetBuildInfo())`). Do not silently assume this number will remain current after patches.
- Do **not** use a check such as `select(4, GetBuildInfo()) >= 100000` to decide whether the client has modern APIs: Forever may report `16001` while using a modern API. Likewise, do not assume `WOW_PROJECT_ID == WOW_PROJECT_MAINLINE` identifies standard Retail rather than Forever.
- Prefer a verified Forever-specific flavor check or an actual feature/API check when a distinction is needed. Verify any proposed project constants against the target client before using them.
- For new addons, start with an appropriate Forever-compatible `.toc` (currently `## Interface: 16001`). Respect existing `.toc` conventions, including any Camelot-specific TOC variants. Never change all TOCs solely because one addon requires a change.
- A function present in standard Retail or in an online API listing is **not automatically proof** that it behaves identically in Forever. Account for missing, changed, disabled, or restricted functionality.

## Local WoW Forever API snapshot (required)

- The repository root contains **`api.json`**, a local API snapshot exported from the target WoW Forever client. Use this file as the **first reference** for any task involving WoW APIs, events, data types, CVars, or console commands, before relying on generic Retail/Classic examples or external documentation.
- At the beginning of an API-dependent task, inspect `api.json`'s `meta` object (especially `interface`, `build`, `buildDate`, and `exportedAt`) to understand which client build the reference describes. Treat it as a **snapshot**, not proof of compatibility with future client builds.
- Search **only relevant parts** of this large JSON file. Do not dump the entire file into the conversation or repeatedly read unrelated entries.
- The JSON structure is:
  - `systems`: API systems/namespaces and their `functions`, `arguments`, `returns`, `events`, and `tables` (including field/type information where provided). For example, a system named `Container` documents functions under `C_Container`.
  - `globals`: names and basic presence/type information for top-level globals and API namespaces; entries do **not** necessarily include callable signatures.
  - `consoleCommands`: console commands and CVars, with descriptions/defaults where present.
  - `meta`: export and client-build information.
- Before introducing, replacing, or debugging an API call, look up its **exact name**, expected arguments and returns, and any relevant types or events in `api.json`. Look up `C_` functions under the matching system name if needed.
- When a needed API is missing from or incompletely documented in the snapshot, **say so** and consult matching UI source/client documentation or propose a small in-game `/dump` or `/run` check. Do not invent signatures, event names, or return values.
- A symbol's presence in `api.json` does **not** guarantee its behavior, availability in every game context, or permission to use it during combat. Still verify protected actions, secret values, secure execution, and actual client behavior.
- **Do not modify, regenerate, or delete `api.json`** unless explicitly asked. It is a development reference, not an addon runtime dependency: never list it in an addon's `.toc` or package it inside an addon.
- In the completion summary for API-dependent changes, briefly state whether the relevant API was confirmed against `api.json` and identify any issues that still require in-game testing.

## API research and runtime restrictions

- Verify unfamiliar API functions, events, frame names, templates, signatures, and return values before relying on them.
- Prefer evidence from the **current Forever client**, its Blizzard UI/API documentation, or its matching UI source. Useful references (secondary to live-client verification):
  - https://github.com/Gethe/wow-ui-source (locate the applicable Forever branch/build)
  - https://atraeau.github.io/WoW-Addons/ (community-generated Forever API reference; check its build date)
  - https://warcraft.wiki.gg/wiki/World_of_Warcraft_API (general API documentation; verify Forever behavior)
- If the documentation is outdated, unavailable, or conflicting, identify the uncertainty rather than inventing an API or behavior. Offer a small in-game `/dump` or `/run` diagnostic when useful.
- Respect modern WoW restrictions: secure/protected actions, combat lockdown, taint, secret values, and restricted execution. Do not try to bypass these protections.
- Do not compare, branch on, perform arithmetic on, or otherwise inspect potentially secret values without a verified safe approach. Where supported, use `issecretvalue` and the appropriate permitted UI APIs.
- Do not assume a protected action is callable from an ordinary addon event, timer, or insecure click handler. Check the relevant restrictions.
- Do not fabricate successful in-game tests. Actual runtime verification belongs in WoW Forever.

## Lua and addon structure

- Write code compatible with the Lua dialect supported by the target WoW client (typically Lua 5.1-style syntax plus Blizzard APIs). Avoid Lua 5.2+ language features unless verified as supported.
- WoW's addon environment is not general-purpose Lua: do not introduce filesystem, process, socket, package-management, or operating-system APIs into in-game addon code.
- Prefer readable, maintainable Lua and small, focused helpers over unnecessary abstraction.
- Keep addon globals to a minimum; use `local` scope and existing addon namespaces where appropriate.
- Follow the target addon's existing file organization, indentation, naming, and event-handling style.
- Ensure any new Lua/XML files are included in the correct `.toc` and loaded in a valid order.
- Reuse existing event frames, helpers, and settings systems when that keeps the implementation simpler.
- Do not introduce external addon libraries or new dependencies without a concrete reason and an explanation of their impact.
- Avoid unnecessary polling, frame creation, per-frame work, repeated event registrations, and unbounded chat/debug output.

## Settings and saved data

- Preserve an addon's existing configuration behavior and saved-variable names.
- Respect whether settings are account-wide (`SavedVariables`) or character-specific (`SavedVariablesPerCharacter` or an existing custom character-keyed design). **Do not impose one scope on every addon.**
- Add defaults, GUI controls, migration logic, and `/reload` requirements according to the individual addon's established design and the user's request.
- Avoid destructive saved-data changes. When changing a schema, consider existing users and provide a safe migration where needed.
- Never assume SavedVariables persistence has been verified just because the TOC declares it; client-specific issues may require an in-game restart test.

## Working on requests

1. Identify the requested addon and inspect only the files relevant to the task, expanding scope when necessary.
2. Check the existing implementation and conventions before editing. Preserve unrelated behavior.
3. Implement the requested change directly in the appropriate addon folder. Prefer minimal, understandable diffs over speculative refactors.
4. For client-specific work, check applicable Forever API details and state any compatibility assumptions.
5. Validate what can be validated locally: syntax, TOC entries/load order, references, and existing automated checks if available. Never claim in-game behavior has been tested unless it actually has.
6. Summarize the changed files, what changed, checks performed, and any specific `/reload`, restart, or in-game reproduction steps needed.

## Repository and deployment safety

- Keep edits within the relevant addon and necessary shared repository files unless the user requests a broader change.
- Do not rename or reorganize unrelated addons.
- Do not overwrite the live WoW installation, WTF/SavedVariables files, or the user's Git history unless explicitly requested.
- Do not commit, push to GitHub, create releases, or deploy to the game's AddOns folder unless requested.
- Do not add generated artifacts, local game paths, caches, log files, or private character/account data to Git.

## Communication

- Reply in the user's language; use Danish when the request is in Danish.
- Prefer practical explanations with exact file paths and concise validation steps.
- Clearly distinguish **verified client behavior**, **documentation-based expectations**, and **items requiring an in-game test**.
- If WoW's API restrictions make a request impossible as described, explain the restriction and propose a supported alternative.
