# Releasing an addon

This guide describes the original combined repository. Future development and
releases use the separate repositories:

- https://github.com/Blazeflack/BlazeMail
- https://github.com/Blazeflack/BlazeTweaks

Follow `RELEASING.md` in the relevant new repository. Existing releases here are
retained and are not recreated or overwritten during the migration.

Pushing an addon tag runs `.github/workflows/release-addon.yml`. It packages only
that addon, checks the TOC version and required files, and creates a GitHub
release with an installable ZIP. Tests are excluded, and the ZIP has exactly one
top-level addon folder. The release notes come from that version's changelog entry.

## First-time setup

1. Commit and push the workflow, packaging script and this guide to `main` using
   GitHub Desktop. Do this before creating any release tags.
2. If Actions is disabled, enable it in the repository's GitHub Actions settings.
   The workflow requests `contents: write` for releases and uses GitHub's built-in
   token; no personal token or local GitHub CLI login is needed.

## Publish from GitHub Desktop

1. Update the addon's `## Version:` in its TOC and add a matching version section
   to its `CHANGELOG.md`. Move completed changes from `Unreleased` into that section.
2. Commit and push the changes. For the first releases below, the current TOC
   versions and versioned changelog sections are already present.
3. In **History**, right-click the commit containing both the workflow and the
   intended addon files, then choose **Create Tag...**.
4. Enter the addon's tag, using exactly this format:
   - `BlazeMail-v1.2.1`
   - `BlazeTweaks-v1.0.1`
5. Push the tag with **Push origin**. Repeat for each addon you want to release.
   Tags can point to the same commit; each runs a separate release job.
6. Check **Actions** on GitHub for the result, then **Releases** for the ZIP.
   Download the named addon ZIP, rather than GitHub's automatic source-code ZIP.

Use the new version number in both the TOC and tag for subsequent releases.
An existing published release is never overwritten. If an upload fails and
leaves a draft, rerunning that workflow can finish the draft. Inspect a failed
run's log before retrying; do not move an already published tag to another commit.

## Local package check

With Python 3.8 or newer, from the repository root:

```text
python .github/scripts/package_addon.py BlazeMail-v1.2.1 --output-dir <output-directory>
```

Use an output directory outside the repository. Only Git-tracked addon files are
included. This checks packaging, not behavior inside WoW Forever.
