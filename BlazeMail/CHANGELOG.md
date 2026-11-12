# BlazeMail changelog

Record future release changes here, newest first. Use `Unreleased` for pending
changes, then move them under a version and date when preparing a release.
Earlier versions have not been reconstructed.

## Unreleased

## 1.4.2 - 2026-11-12

### Changed
- Removed the BlazeMail title from the mailbox window in the BlazeMail theme.
- Moved the Inbox and Send Mail tabs to the left, keeping the BlazeMail tab
  on the right beside the close button.

## 1.4.1 - 2026-11-10

### Changed
- Open Automatically also reopens the character picker after a successful send.
  The last recipient is still filled in again with the option enabled or disabled.

## 1.4.0 - 2026-11-10

### Added
- Account-wide "Open Automatically" toggle below Theme in Characters / Settings,
  with a tooltip. When enabled, entering Send Mail opens the alt list in either
  theme. On by default; changes take effect without reloading.
  Uses Blizzard's native checkbox when the Blizzard theme is active.

### Changed
- Updated the Characters / Settings screenshot to show the new toggle.

## 1.3.0 - 2026-11-09

### Added
- Account-wide theme selection at the top of Characters / Settings: keep
  the existing BlazeMail look or use Blizzard's original mailbox appearance
  with Blizzard panels, buttons, inset fields and fonts for the addon windows.
- An explicit Reload UI button for pending theme changes. The active theme
  stays unchanged until reload; existing users keep the BlazeMail theme.
- Visible keyboard-focus borders on the search and note fields.

### Changed
- Neutral Blizzard character-list rows with more text padding and taller,
  separated Favorite and Note buttons.
- Fit window height to the character count on opening, place pagination
  directly below the list and hide it for single-page lists. Keep the layout
  stable while searching or paging.
- Show a theme dropdown beside Reload UI and filter management by current ruleset.
- Show only character names and notes in list rows, and refresh the usage guide
  and screenshots for both themes.

## 1.2.2 - 2026-11-09

### Fixed
- Recognize the verified Forever ruleset suffixes `PvE`, `PvP`, `RP` and
  `RP PvP`, matching `RP PvP` before `PvP`. Migrate previously saved roleplay
  labels to the correct terms without removing characters or their metadata.

### Added
- Inbox, recipient picker and character management screenshots beneath the
  BlazeMail description in the repository's main `README.md`.

## 1.2.1 - 2026-11-08

### Added
- `HOW_TO_USE.txt` with installation, character registration, recipient selection,
  repeat recipients, favorites, notes, removal and mailbox theme instructions.
- This changelog for tracking changes between releases.

### Changed
- TOC version from `1.2.0` to `1.2.1`.
- No addon runtime behavior changed in this update.
