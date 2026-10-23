# Project Agent Instructions

## Lua code and documentation

- Use Perl scripts when a utility script is needed (short shell scripts are fine); do not introduce Node.js or another scripting runtime for repository tasks.
- Document every Lua function with LuaDoc-style comments. Include a concise purpose and document parameters and return values when applicable. Keep documentation accurate when changing a function.
- Explain the reason behind complex or non-obvious code sections. If a change is a tweak, workaround, or hack, add a nearby comment explaining why it is needed and any relevant constraints.

## Ace3 configuration and saved data

- Before changing Ace3/AceDB defaults, options, profiles, or the saved-variable data shape, check the impact on existing user configurations.
- When a saved-config data change requires migration, update `CONFIG_VERSION` and add the corresponding version transition to `CONFIG_MIGRATIONS` in `Init.lua`, and map the new config version to the addon release it will ship in via `CONFIG_VERSION_RELEASES`. Bump `CONFIG_VERSION` at most once per release: if `CONFIG_VERSION_RELEASES[CONFIG_VERSION]` is already the upcoming (unreleased) addon version, extend that migration instead of adding another. Preserve existing user settings where possible, and verify the migration path for older saved data.
