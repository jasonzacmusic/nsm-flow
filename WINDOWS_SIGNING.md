# Windows code signing

The Windows installers are unsigned. Everyone who downloads one sees
SmartScreen's blue "Windows protected your PC" box, has to click **More info →
Run anyway**, and is told the publisher is unknown. Most people don't get past
that — they assume the file is malicious.

This is the only remaining thing standing between NSM Flow and a clean install
on Windows. It cannot be fixed in code: it needs a certificate bought from a
certificate authority. This file records what was checked, so the purchase is
one decision rather than a research project.

## Azure Trusted Signing is not an option for Nathaniel

The build workflow already installs `trusted-signing-cli` and passes
`AZURE_CLIENT_ID` / `AZURE_CLIENT_SECRET` / `AZURE_TENANT_ID`, which suggests
Azure Trusted Signing (rebranded Azure Artifact Signing in 2026) was the
intended route. It is the cheapest managed option at about $10/month, and it
signs directly from CI with no hardware token.

It is unavailable here. Microsoft's own prerequisites state that public trust
certificates are issued only to organisations in the United States, Canada, the
European Union, the United Kingdom, Australia, New Zealand, Japan, South Korea,
Singapore, Switzerland, Norway and Israel, and that individual developers must
be in the United States or Canada. **India is not on either list.**

Source: <https://learn.microsoft.com/en-us/azure/artifact-signing/quickstart>

So the Azure wiring in `build.yml` should be treated as dead weight until that
changes. The signing step itself is provider-agnostic — see below.

## Buy OV, not EV

The usual advice is that Extended Validation certificates are worth the extra
money because they grant instant SmartScreen reputation. **That stopped being
true in 2024**, when Microsoft changed the Trusted Root Program requirements.
EV-signed applications now build SmartScreen reputation organically, exactly
like OV-signed ones.

What EV still buys is kernel-mode driver signing (irrelevant here) and a
slightly stronger identity assertion. For NSM Flow it is roughly triple the
price for no practical difference, so **Organization Validation (OV) is the
right purchase**.

Be aware of what signing does and does not fix:

- It replaces "Unknown publisher" with "Nathaniel School of Music". That alone
  is most of the trust win.
- It does **not** remove the SmartScreen prompt on day one. Reputation accrues
  per file hash from clean-install volume, so each new release starts fresh and
  warns until enough people have installed it. Signing is what lets reputation
  accumulate at all — unsigned builds never accumulate any.

## What to look for when buying

Since June 2023 every code signing private key must live on a FIPS 140-2 Level
2 device. That leaves three routes, and only one of them works with GitHub
Actions:

| Route                        | Works in CI? | Notes                                                                                                                            |
| ---------------------------- | ------------ | -------------------------------------------------------------------------------------------------------------------------------- |
| CA-shipped USB token         | **No**       | Signing needs the physical token plugged in. Would mean building Windows installers by hand on a Windows machine, every release. |
| Your own cloud HSM           | Yes          | Overkill; the CA still has to verify the HSM.                                                                                    |
| **CA cloud signing service** | **Yes**      | The CA holds the key and exposes a signing CLI. This is the one to buy.                                                          |

So the requirement is: **an OV code signing certificate with a cloud signing
service**, not a USB token. Ask the seller explicitly — token-based is still the
default offer, and it would quietly force every Windows release to become a
manual job.

Vendors that sell cloud signing to Indian entities include SSL.com (eSigner),
DigiCert (KeyLocker), and GlobalSign through Indian resellers who invoice in
INR with GST. Validation needs company registration documents and typically
takes a few business days.

## Wiring it up once the certificate exists

Everything else is already done. One repository variable turns signing on:

1. Go to **Settings → Secrets and variables → Actions**.
2. Add a **variable** named `WINDOWS_SIGN_COMMAND` containing the provider's
   signing command, with `%1` where the file path goes. For example:

   ```text
   CodeSignTool sign -credential_id=%CREDENTIAL_ID% -username=%USERNAME% -password=%PASSWORD% -totp_secret=%TOTP% -input_file_path=%1
   ```

3. Add whatever **secrets** that command reads, and reference them in the
   `Build with Tauri (signed)` step's `env:` block alongside the existing
   entries.
4. Run a release with `sign-binaries: true`.

The workflow generates `src-tauri/tauri.signing.conf.json` from that variable
and passes it to the build. This matters: `tauri-bundler` ignores signing
credentials entirely unless the config contains a `signCommand`, so before this
was added a fully configured signing run would have produced unsigned
installers and reported success.

The build then **fails** if the installers come out unsigned — it reads the PE
certificate table directly rather than trusting that the signing step ran. A
misconfigured provider, a bad credential or a silently skipped signtool all
stop the release instead of shipping a warning to users.

## Meanwhile

Until the certificate exists, the README tells Windows users plainly that the
installer is unsigned, how to get past SmartScreen, and where to verify the
SHA-256 of what they downloaded. That is the honest position, and it is better
than a warning nobody explained.
