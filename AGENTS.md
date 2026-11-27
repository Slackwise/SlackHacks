# Project Agent Instructions

## Lua code and documentation

- Use Perl scripts when a utility script is needed (short shell scripts are fine); do not introduce Node.js or another scripting runtime for repository tasks.
- Document every Lua function with LuaDoc-style comments. Include a concise purpose and document parameters and return values when applicable. Keep documentation accurate when changing a function.
- Explain the reason behind complex or non-obvious code sections. If a change is a tweak, workaround, or hack, add a nearby comment explaining why it is needed and any relevant constraints.

## Architectural Decisions

- Attempt to use native Blizzard code / FrameXML for as much as possible.
- Otherwise try to use Ace3 libraries/features.
- We want to look as native as possible.
- We want to use as little custom code/widgets as possible.

## Ace3 configuration and saved data

- Before changing Ace3/AceDB defaults, options, profiles, or the saved-variable data shape, check the impact on existing user configurations.
- When a saved-config data change requires migration, update `CONFIG_VERSION` and add the corresponding version transition to `CONFIG_MIGRATIONS` in `Init.lua`, and map the new config version to the addon release it will ship in via `CONFIG_VERSION_RELEASES`. Bump `CONFIG_VERSION` at most once per release: if `CONFIG_VERSION_RELEASES[CONFIG_VERSION]` is already the upcoming (unreleased) addon version, extend that migration instead of adding another. Preserve existing user settings where possible, and verify the migration path for older saved data. To confirm when the last release was, look for the previous release's git tag or a commit message mentioning it.

## Updating the addon for release

- Do not add anything related to `Slackwise.lua` or `isSlackwise()` in `CHANGELOG.md` or `curseforge_description.md`. That is me and private.
- Keep the `CHANGELOG.md` entries with sections per module and keep the changes short to one or two sentences. Do not mention script changes, changes to the repository, small clean-ups, or anything a user will never notice. The only such meta changes worth mention are those that impact users like performance, bug fixes, etc.
