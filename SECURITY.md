# Security Policy

## Scope

Unagi Reader is a macOS RSS reader with a local database. It has no account, backend or sync service. Subscriptions, reading history and the person's note are data to protect.

Feeds, article HTML, images, imported OPML and original web pages come from outside the app. Security reports can concern the app, its dependencies, or this repository's build and CI workflows. The [architecture](docs/architecture.md#2-input-from-the-network-is-untrusted) describes the trust boundaries and intended controls; those descriptions are not proof that a control cannot fail.

## Reporting a Vulnerability

Please [report a vulnerability privately](https://github.com/ojiman/unagi-reader/security/advisories/new) through GitHub. You can also find this form under the repository's Security → Advisories → Report a vulnerability.

Do not disclose vulnerability details in public issues.

Include what you know:

- The affected version or commit, macOS version, and how the app was built or obtained.
- Steps to reproduce the issue, expected and actual behavior, and a small synthetic feed, HTML or OPML sample when useful.
- The potential impact, what an attacker would need to control, and any required user action.

An incomplete report is welcome; you do not need to prove an exploit before contacting the maintainer. Use synthetic data where possible. Do not include credentials, personal data or your real library. Remove sensitive values from logs and URLs before attaching them. Test only with data and systems you are authorized to use.

## What to Expect

This project is maintained by an individual. Reports are reviewed on a best-effort basis, without guaranteed response or fix times. We will discuss findings and next steps through the private report.

The app is currently a beta, before its first public release. Include the exact commit or version in your report; the [README](README.md) describes the current product status and verification limits.
