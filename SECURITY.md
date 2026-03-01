# Security Policy

## Supported PowerShell Versions

Security fixes are provided for the current release line (`2.x`) on the following runtimes:

| PowerShell Runtime           | Supported |
| --------------------------- | --------- |
| Windows PowerShell `5.1`    | Yes       |
| PowerShell (Core) `7.2+`    | Yes       |
| Older than `5.1`            | No        |

Notes:
- This project is Windows-focused and should be run on Windows.
- Some features rely on Windows-specific modules/cmdlets and may behave differently across runtime editions.

## Reporting a Vulnerability

If you discover a security vulnerability:

1. Open a **private GitHub Security Advisory** for this repository.
2. Include clear reproduction steps, impact, and affected files/modules.
3. If advisory submission is unavailable, open a GitHub issue and mark it clearly as `SECURITY` (avoid posting exploit details publicly).

Response targets:
- Initial acknowledgement: within 72 hours.
- Status updates: at least weekly until resolution.
