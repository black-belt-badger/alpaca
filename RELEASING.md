# Releasing Kirke (maintainers)

Kirke is an **unofficial** Haskell client and CLI for Alpaca's APIs. The Haskell package remains `alpaca`; its executable is named `kirke`. The first release covers **paper account access only**.

## Versioning

- Follow the [Haskell Package Versioning Policy](https://pvp.haskell.org/).
- Keep the version in `package.yaml` and the Git tag aligned: package `0.1.0.0` -> tag `v0.1.0.0`.
- Release independently of the Rust [Medea](https://github.com/black-belt-badger/medea) repository, which uses three-part SemVer.
- Keep a GitHub milestone for each release. No calendar deadline is required.

## Release checklist

1. Finish all issues in the release milestone, including public README, correct package metadata and **confirmed** license/copyright attribution. Do not replace attribution with guesses.
2. Update `CHANGELOG.md`: move relevant entries from **Unreleased** into a dated heading for the exact package version.
3. Ensure `main` contains the release contents and the required **Build and test (GHC 9.10.3)** GitHub Actions check is green.
4. Verify locally from a clean checkout:

   ```sh
   stack build
   stack test
   ```

5. Run the paper-only integration check explicitly on a trusted machine with private local credentials:

   ```sh
   ./scripts/it.sh
   ```

   Never put Alpaca credentials, full account JSON, or integration output into CI logs or release assets. CI intentionally uses offline tests only.
6. Review public docs and release notes: state limitations, supported toolchain, unofficial status and lack of live trading or order placement.

## Create a tag and GitHub Release

After the release-readiness changes are merged, from a clean working tree:

```sh
git switch main
git pull --ff-only origin main
git status --short
git tag -a v0.1.0.0 -m "Kirke v0.1.0.0"
git push origin v0.1.0.0

gh release create v0.1.0.0 \
  --repo black-belt-badger/kirke \
  --verify-tag \
  --title "Kirke v0.1.0.0" \
  --generate-notes \
  --prerelease
```

These are **example commands for the first release**: adjust the version and verify the release checklist before executing them. Review generated release notes and clearly explain the paper-only scope. GitHub automatically provides source archives; compiled binaries are optional future work.

Finally, verify the tag and release, close the corresponding milestone, and confirm Project #7 reflects completed release tasks.

Do not rewrite published release tags; ship a new version for fixes.
