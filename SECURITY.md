# Security policy

Kirke is an **unofficial** Haskell CLI that currently supports read-only access to Alpaca **paper trading accounts**.

## Supported versions

No formal release has been published yet. Security fixes, when available, are developed against the current `main` branch. There is no guarantee of support for earlier commits or unreleased versions.

## Report vulnerabilities privately

**Do not disclose vulnerabilities, exploits, API credentials, or private account data in public GitHub issues or pull requests.**

Use [GitHub private vulnerability reporting](https://github.com/black-belt-badger/kirke/security/advisories): select **Report a vulnerability** to send a private report to the repository maintainers. Include a description, impact, reproduction steps, and a sanitized proof of concept. Never include real keys, account numbers, or full account JSON.

We aim to acknowledge and investigate responsible reports, but do not promise a fixed response or remediation timeline.

For nonsecurity bugs or improvement proposals, use the [public issue templates](https://github.com/black-belt-badger/kirke/issues/new/choose).

## Credentials and sensitive data

The CLI reads `APCA_API_KEY_ID` and `APCA_API_SECRET_KEY` from the environment and talks only to the paper Trading API endpoint. Keep credentials outside version control, restrict local file permissions, and redact terminal output and logs. Account summaries and complete JSON responses contain potentially sensitive account data.
