# Releasing Kirke (maintainers)

Kirke is an **unofficial Haskell CLI** for read-only paper Trading API state and historical crypto market data. Its package and executable are both named `kirke`; the Haskell modules remain under `Alpaca.*`.

## Versioning

- Follow the [Haskell Package Versioning Policy](https://pvp.haskell.org/). Keep `package.yaml` and the release tag aligned (package `0.2.0.0` → tag `v0.2.0.0`).
- Release independently of Rust [Medea](https://github.com/black-belt-badger/medea), whose version is `0.2.0` under SemVer.
- Do not rewrite existing published tags. Create a new version for corrections.

## Release readiness

1. Verify the scoped work is reviewed and merged. M2 Account and Trading State is closed; this release also includes historical bars and trades delivered ahead of M4 completion. **Historical quotes remain out of scope.**
2. Update the package version, generated lockfile where relevant, and the dated `CHANGELOG.md`. Review the version-specific release notes in `docs/releases/v0.2.0.0.md` for accuracy and limitations.
3. Ensure `main` is clean and the required **Build and test (GHC 9.10.3)** GitHub Actions check succeeds on the **exact** commit to be tagged.
4. Verify on a trusted development system:

   ```sh
   stack build
   stack test
   ./scripts/it.sh
   ```

   The integration script exercises paper account, positions, assets, orders, and bounded crypto bars/trades. It sources local secrets; **never publish credentials or account/data responses**.
5. Confirm public docs, copyright and license, supported toolchain, privacy of exported JSON, and the unofficial/non-trading limitations. GitHub supplies source archives; no Hackage package or compiled binaries are published by this procedure.

## Tag and publish after the release-preparation PR is merged

```sh
git switch main
git pull --ff-only origin main
git status --short
git tag -a v0.2.0.0 -m "Kirke v0.2.0.0"
git push origin v0.2.0.0

gh release create v0.2.0.0 \
  --repo black-belt-badger/kirke \
  --verify-tag \
  --title "Kirke v0.2.0.0" \
  --notes-file docs/releases/v0.2.0.0.md \
  --prerelease
```

**Do not tag a release branch or open PR commit.** Tag only the exact tested `main` revision after the release PR is merged and post-merge CI is green. Verify the tag/release URL and that its notes match the source. Future changes belong in a new release; do not amend published tags.
