# Security policy

NSM Flow is a public alpha. Current development and fixes target the newest
published alpha; older alphas are retained for rollback, not maintained security
branches. See the [audit](docs/AUDIT-2026-10-14.md) for dependency findings and
limits. No security-clean claim is made from a single scanner.

For a sensitive vulnerability, use GitHub's **Security → Report a vulnerability**
(private vulnerability reporting) when available. Do not put API keys, private
audio, account tokens or an unredacted exploit against another person's data in
a public issue. Ordinary reproducible bugs use the issue templates.

Include affected version, OS/architecture, model/provider configuration,
reproduction steps and impact using disposable data. Maintainers will review
reports; there is currently no promised response-time SLA or bounty program.

Official Mac releases use Developer ID signing and Apple notarization. Windows
alpha installers remain unsigned; a signed Tauri update payload is a different
mechanism and does not remove SmartScreen warnings. Verify checksums from the
same release and never disable platform protections as routine troubleshooting.
