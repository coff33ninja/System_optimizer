# ESET NOD32 Antivirus & Internet Security — Complete Installer Reference

> Documented: July 9, 2026
> Source: Official ESET CDN, ESET help portal, and binary analysis of downloaded installers

---

## Table of Contents

1. [Installer Types Explained](#installer-types-explained)
2. [ESET NOD32 Antivirus — Official Links](#eset-nod32-antivirus--official-links)
3. [ESET Internet Security — Official Links](#eset-internet-security--official-links)
4. [All ESET Home Products — Official Links](#all-eset-home-products--official-links)
5. [NOD32 Antivirus — Version History](#nod32-antivirus--version-history)
6. [Internet Security — Version History](#internet-security--version-history)
7. [Third-Party Archives for Older Versions](#third-party-archives-for-older-versions)
8. [Product Comparison](#product-comparison)

---

## Installer Types Explained

| Type | Description | File Size | Internet Required |
|------|-------------|-----------|-------------------|
| **Live Installer** | Small bootstrap/stub that downloads all components during install | ~5-10 MB | Yes |
| **Offline Installer (64-bit)** | Complete self-contained installer for 64-bit Windows | ~85 MB | No (for install) |
| **Offline Installer (32-bit)** | Complete self-contained installer for 32-bit Windows | ~74 MB | No (for install) |
| **Offline Installer (ARM64)** | Complete self-contained installer for Windows on ARM | ~84 MB | No (for install) |

**Important:** All official ESET download URLs use `/latest/` and always serve the current version. The URLs do NOT change between versions. There is no official way to download a specific older version from ESET directly.

---

## CDN Probe Results (Tested July 9, 2026)

### What was tested

50+ URL pattern variations were probed against `download.eset.com`:

| Pattern | Result |
|---------|--------|
| Version in path: `/19.2/`, `/19.2.7.0/`, `/v19.2/`, `/19/` | **All 404** |
| Versioned filename: `eav_nt64_19.2.7.0.exe` | **404** |
| Language suffix: `eav_nt64_enu.exe`, `_en.exe`, `_eng.exe` | **All 404** |
| Alternative formats: `.msi`, `.zip` | **404** |
| Directory names: `/archive/`, `/releases/`, `/old/`, `/stable/`, `/beta/` | **All 404** |
| Query params: `?version=`, `?v=`, `?lang=`, `?channel=` | **All ignored** (returns same file) |
| Parent directories | **404** (no directory listing) |
| robots.txt | **Exists** — only disallows `/manuals/` |
| sitemap.xml | **404** |
| API endpoints | **404** |
| Other subdomains (cdn.eset.com, resources.eset.com) | **DNS failure** |

### Conclusion: No version-specific URLs exist

ESET's CDN serves **only** `/latest/` paths. There is **zero** way to pin or request a specific version via URL. The CDN is an Azure Front Door (`x-azure-ref` headers) with `TCP_HIT` caching.

---

## Binary Analysis: Installer Internals

### All installers are "Bootstrapper.exe"

Every ESET offline installer is the same program: `Bootstrapper.exe` — a universal bootstrapper that extracts and runs an embedded MSI package.

```
InternalName:     Bootstrapper.exe
OriginalFilename: Bootstrapper.exe
ProductName:      ESET Security
CompanyName:      ESET
```

### Embedded XML config (identical across ALL products)

All installers share this XML config block:
```xml
<eset>
  <flow>
    <sequence name="entry">
      <task cmd="rc.extract" id="2000" />
      <task cmd="rc.extract" id="2010" exclude="bootstrapper.exe" />
      <task cmd="rc.extract" id="2030" />
      <task cmd="vfs.mount.resource" type="zip" id="3000" />
      <task cmd="vfs.mount.resource" id="4000" type="raw"
            path="vfs:\.pkg\0\ehs_nt64.msi" />
    </sequence>
    <sequence name="main">
      <task cmd="execute" file="BootHelper.exe"
            args="--watchdog ${bts.process.id} --product
            &quot;${bts.product.name}&quot; ${bts.product.version} 1033" />
      <task cmd="lib.load" file="sciter-x.dll" />
      <task cmd="lib.load" file="plgInstaller.dll" />
      <task cmd="lib.call" file="plgInstaller.dll" proc="PluginExtProc" action="init" />
      <task cmd="lib.call" file="plgInstaller.dll" proc="PluginExtProc" action="start" />
    </sequence>
  </flow>
</eset>
```

Note: The MSI name `ehs_nt64.msi` is the **same** for all 4 products (EAV/EIS/ESSP/ESU). Product differentiation happens at runtime via the license key, not the installer binary.

### Live Installers differ

The live installers (10.5 MB) lack the embedded MSI (no `vfs.mount.resource` line for `.msi`) — they download everything at runtime.

### SHA256 Hashes (all 8 installers)

| Installer | Size | SHA256 |
|-----------|------|--------|
| EAV x64 | 90,238,896 | `BC11996B2F75B4E1C8998A9EFD810A82F3DF436914F360B0EEC9A7F6028B6255` |
| EIS x64 | 90,238,896 | `2D440087D87A888AE6911952F32E9721DE8B46A40D5CB71073A224663CEABA6C` |
| ESSP x64 | 90,238,896 | `2FB2430C628EC4A4C84DA145FB0614C422A99957AA2EEB7FA0199739578BFEEB` |
| ESU x64 | 90,238,896 | `A7453F4C345C538FEC42BFC1C27425B0194AC8C390CFF3C68DBC981DE820D1FD` |
| EAV 32-bit | 78,133,168 | `23FB8EAE75FCDA3091AEB55E78D6F711001AB735CB2308FD1F67A180C4CCC0DE` |
| EAV ARM64 | 89,401,776 | `620BA63B347D103748D6669C79F33C87F1BFC75CAB435B4382C2FCE03D507647` |
| Live EAV | 11,015,600 | `F2B8F1519865483996C5A5BDBF5E188107A17A44970F6CA9EBCF90C10D0C97FA` |
| Live EIS | 11,015,600 | `3D5DC868933DA8D6140914922B7E1377E439B15C0F0BE625DD81A58A53BC3CF6` |

**Key finding:** All x64 offline installers are **exactly the same size** (90,238,896 bytes) but have **different SHA256 hashes**. Only ~0.51% of bytes differ between products. The difference is in embedded resource data, not the bootstrapper code.

### PE Version Info

| Installer | ProductVersion | FileVersion | Last-Modified |
|-----------|---------------|-------------|---------------|
| EAV x64 | 19.2.7.0 | 10.67.13.0 | Jun 22, 2026 |
| EIS x64 | 19.2.7.0 | 10.67.13.0 | Jun 22, 2026 |
| ESSP x64 | 19.2.7.0 | 10.67.13.0 | Jun 22, 2026 |
| ESU x64 | 19.2.7.0 | 10.67.13.0 | Jun 22, 2026 |
| EAV 32-bit | **18.2.18.0** | **10.56.11.0** | Sep 4, 2025 |
| EAV ARM64 | 19.2.7.0 | 10.67.13.0 | Jun 22, 2026 |
| Live EAV | **19.0.3.0** | **10.60.20.0** | Sep 24, 2025 |
| Live EIS | **19.0.3.0** | **10.60.20.0** | Sep 24, 2025 |

**Warning:** The 32-bit installer is stuck on **18.2.18.0** (frozen since 32-bit was dropped in v19.0). Live installers are also on an older bootstrapper version.

### Digital Signature (identical across all files)

```
Signer:   CN="ESET, spol. s r.o.", L=Bratislava, C=SK
Issuer:   CN=DigiCert Trusted G4 Code Signing RSA4096 SHA384 2021 CA1
Valid:    2023-08-16 to 2026-08-17
Type:     sha256RSA
Thumbprint: 87A8825374628D1F6E27117EDD09DB089C9509DB
```

---

## Summary: What This Means for Your Project

1. **There are NO version-specific download URLs** — ESET's CDN only serves `/latest/`
2. **Query parameters are ignored** — `?version=19.2.7.0` still downloads whatever is current
3. **All products share one bootstrapper** — product selection is via license key at activation
4. **No way to programmatically fetch older versions** from ESET directly
5. **The 32-bit installer is permanently frozen** at v18.2.18.0
6. **File hashes change with each release** but sizes stay the same
7. **ETag headers are not unique per-file** — CDN returns the same ETag for different products

### For automated deployments, use:
```
# These URLs always give the latest version
EAV:  https://download.eset.com/com/eset/apps/home/eav/windows/latest/eav_nt64.exe
EIS:  https://download.eset.com/com/eset/apps/home/eis/windows/latest/eis_nt64.exe
ESSP: https://download.eset.com/com/eset/apps/home/essp/windows/latest/essp_nt64.exe
ESU:  https://download.eset.com/com/eset/apps/home/esu/windows/latest/esu_nt64.exe
```

---

## ESET NOD32 Antivirus — Official Links

### Live Installer (Online)
```
https://download.eset.com/com/eset/tools/installers/live_eav/latest/eset_nod32_antivirus_live_installer.exe
```

### Offline Installer — 64-bit
```
https://download.eset.com/com/eset/apps/home/eav/windows/latest/eav_nt64.exe
```
- **Filename:** eav_nt64.exe
- **File size:** ~85.5 MB
- **SHA256 (19.2.7.0):** bc11996b2f75b4e1c8998a9efd810a82f3df436914f360b0eec9a7f6028b6255

### Offline Installer — 32-bit
```
https://download.eset.com/com/eset/apps/home/eav/windows/latest/eav_nt32.exe
```

### Offline Installer — ARM64
```
https://download.eset.com/com/eset/apps/home/eav/windows/latest/eav_arm64.exe
```

---

## ESET Internet Security — Official Links

### Live Installer (Online)
```
https://download.eset.com/com/eset/tools/installers/live_eis/latest/eset_internet_security_live_installer.exe
```

### Offline Installer — 64-bit
```
https://download.eset.com/com/eset/apps/home/eis/windows/latest/eis_nt64.exe
```
- **Filename:** eis_nt64.exe
- **File size:** ~86 MB

### Offline Installer — 32-bit
```
https://download.eset.com/com/eset/apps/home/eis/windows/latest/eis_nt32.exe
```

### Offline Installer — ARM64
```
https://download.eset.com/com/eset/apps/home/eis/windows/latest/eis_arm64.exe
```

---

## All ESET Home Products — Official Links

### ESET Smart Security Premium

| Architecture | Offline Link |
|-------------|-------------|
| 64-bit | `https://download.eset.com/com/eset/apps/home/essp/windows/latest/essp_nt64.exe` |
| 32-bit | `https://download.eset.com/com/eset/apps/home/essp/windows/latest/essp_nt32.exe` |
| ARM64 | `https://download.eset.com/com/eset/apps/home/essp/windows/latest/essp_arm64.exe` |

### ESET Security Ultimate

| Architecture | Offline Link |
|-------------|-------------|
| 64-bit | `https://download.eset.com/com/eset/apps/home/esu/windows/latest/esu_nt64.exe` |
| 32-bit | `https://download.eset.com/com/eset/apps/home/esu/windows/latest/esu_nt32.exe` |
| ARM64 | `https://download.eset.com/com/eset/apps/home/esu/windows/latest/esu_arm64.exe` |

### ESET Small Business Security

| Architecture | Offline Link |
|-------------|-------------|
| 64-bit | `https://download.eset.com/com/eset/apps/home/esbs/windows/latest/esbs_nt64.exe` |
| 32-bit | `https://download.eset.com/com/eset/apps/home/esbs/windows/latest/esbs_nt32.exe` |
| ARM64 | `https://download.eset.com/com/eset/apps/home/esbs/windows/latest/esbs_arm64.exe` |

### ESET Safe Server

| Architecture | Offline Link |
|-------------|-------------|
| 64-bit | `https://download.eset.com/com/eset/apps/home/essv/windows/latest/essv_nt64.exe` |
| 32-bit | `https://download.eset.com/com/eset/apps/home/essv/windows/latest/essv_nt32.exe` |
| ARM64 | `https://download.eset.com/com/eset/apps/home/essv/windows/latest/essv_arm64.exe` |

---

## NOD32 Antivirus — Version History

Current latest: **19.2.7.0** (released June 30, 2026 per official ESET changelog)

| Version | Build | Release Date | Key Changes |
|---------|-------|-------------|-------------|
| 19.2 | 19.2.7.0 | Jun 30, 2026 | SOHO web control, Network attack protection, AI Conversation Security, SHA256 default, import/export split |
| 19.1 | 19.1.12.0 | — | Browser Screen Protection, Audit log, Win11 context menu integration, reconfigured Parental Control |
| 19.0 | 19.0.14.0 | — | VPN for ESET Smart Security Premium, Monthly schedule, Gamer mode logging, **Dropped 32-bit support** |
| 18.2 | 18.2.18.0 | Sep 10, 2025 | Win11 context menu fix (RDP), Microphone Monitor PDF fix |
| 18.2 | 18.2.17.0 | — | BSOD/memory leak fixes (Microphone Monitor), Safe Banking icon fix |
| 18.2 | 18.2.14.0 | Jul 1, 2025 | — |
| 18.1 | 18.1.13.0 | Apr 29, 2025 | — |
| 18.1 | 18.1.10.0 | Apr 1, 2025 | Untrusted extensions handling in SBB, Updater logs section |
| 18.0 | 18.0.11.0 | Oct 23, 2024 | ESET Folder Guard, Catalan language, accessibility improvements, drag-and-drop tiles |
| 17.2 | 17.2.8.0 | Aug 29, 2024 | — |
| 17.2 | 17.2.7.0 | Jul 2, 2024 | Brave browser support, CVE-2024-3779 fix, Gamer mode improvements |
| 17.1 | 17.1.13.0 | Jun 4, 2024 | — |
| 17.1 | 17.1.11.0 | Apr 24, 2024 | Transparency lag fix, BSOD on Win10 RTM fix |
| 17.1 | 17.1.1.0 | Mar 29, 2024 | — |
| 17.0 | 17.0.16.0 | Dec 18, 2023 | — |
| 17.0 | 17.0.15.0 | — | Browser privacy & security extension, new logos, Safe Banking & Browsing rename |
| 16.2 | 16.2.15.0 | Sep 27, 2023 | — |
| 16.1 | 16.1.14.0 | Apr 4, 2023 | — |
| 16.0 | 16.0.26.0 | Jan 16, 2023 | — |
| 16.0 | 16.0.24.0 | Nov 14, 2022 | — |
| 14.2 | 14.2.23.0 | Aug 3, 2021 | — |
| 14.2 | 14.2.19.0 | Jun 29, 2021 | — |

---

## Internet Security — Version History

Current latest: **19.2.7.0** (July 1, 2026)

| Version | Build | Release Date |
|---------|-------|-------------|
| 19.0 | 19.0.14.0 | Mar 12, 2026 |
| 19.0 | 19.0.11.0 | Oct 21, 2025 |
| 18.0 | 18.0.11.0 | Oct 23, 2024 |
| 17.2 | 17.2.8.0 | Aug 29, 2024 |
| 17.2 | 17.2.7.0 | Jul 3, 2024 |
| 17.1 | 17.1.13.0 | Jun 5, 2024 |
| 17.0 | 17.0.16.0 | Dec 20, 2023 |
| 16.2 | 16.2.15.0 | Sep 26, 2023 |
| 16.2 | 16.2.13.0 | Aug 9, 2023 |
| 16.0 | 16.0.26.0 | Jan 16, 2023 |
| 15.2 | 15.2.17.0 | Aug 24, 2022 |
| 14.0 | 14.0.22.0 | Oct 27, 2020 |
| 13.1 | 13.1.21.0 | Jun 16, 2020 |
| 13.1 | 13.1.16.0 | Mar 19, 2020 |

---

## Third-Party Archives for Older Versions

Since ESET only serves `/latest/`, use these for specific older builds:

### Uptodown (Most Comprehensive)
- **NOD32 Antivirus:** https://nod32.en.uptodown.com/windows/versions
- **Internet Security:** https://eset-smart-security.en.uptodown.com/windows/versions

### Softonic
- **NOD32 Antivirus:** https://eset-nod32-antivirus.en.softonic.com/versions
- **Internet Security:** https://eset-internet-security.en.softonic.com/versions

### Softpedia
- **NOD32 Antivirus:** https://www.softpedia.com/get/Antivirus/NOD.shtml
- **Internet Security:** https://www.softpedia.com/get/Security/Security-Related/Eset-Smart-Security.shtml

### Neowin (Release Notes + Links)
- Search "ESET NOD32" or "ESET Internet Security" at https://www.neowin.net/software/
- Each release post contains changelog and direct download links

### FileHorse
- **NOD32 32-bit:** https://www.filehorse.com/download-nod32-32/
- **NOD32 64-bit:** https://www.filehorse.com/download-nod32-64/
- **Internet Security 64-bit:** https://www.filehorse.com/download-eset-internet-security-64/

### ESET Singapore Reseller (Old Versions v7-v11)
- https://eset.version-2.sg/download/detail?product=EAV11
- https://eset.version-2.sg/download/detail?product=EAV8

### Internet Archive (Ancient Versions)
- https://archive.org/details/nod-32-antivirus (v2.x from 2006, ISO image)

---

## Product Comparison

> **Note:** All 4 home products (EAV/EIS/ESSP/ESU) share **identical changelogs** — they are the same codebase differentiated only by the license key applied at activation.

### v19.2.7.0 Changelog (Jun 30, 2026)

```
New:     SOHO: Web control in ESET Small Business Security
New:     SOHO: Network attack protection in ESET Safe Server
New:     Browser privacy & security: AI Conversation Security
         (available for Premium, Ultimate, Small Business Security)
Improved: SHA256 enabled by default - initial scan must run
Improved: Import export split into two separate windows
Improved: Added unified option to adjust headers in lists
Bugfixes
```

| Feature | NOD32 Antivirus | Internet Security | Smart Security Premium | Security Ultimate |
|---------|----------------|-------------------|----------------------|-------------------|
| Antivirus/Antispyware | Yes | Yes | Yes | Yes |
| Personal Firewall | No | Yes | Yes | Yes |
| Anti-Phishing | Yes | Yes | Yes | Yes |
| Webcam Protection | No | Yes | Yes | Yes |
| Banking & Payment Protection | No | Yes | Yes | Yes |
| Parental Control | No | Yes | Yes | Yes |
| Password Manager | No | No | Yes | Yes |
| File Encryption | No | No | Yes | Yes |
| VPN | No | No | No | Yes |
| Home Network Protection | No | Yes | Yes | Yes |
| Ransomware Shield | Yes | Yes | Yes | Yes |
| UEFI Scanner | Yes | Yes | Yes | Yes |
| **Price (1yr, 1 PC)** | $59.99 | ~$59.99 | $89.99 | $179.99 (5 devices) |

---

## System Requirements

- **OS:** Windows 10, Windows 11 (32-bit dropped in v19.0)
- **RAM:** 512 MB (2 GB recommended)
- **Disk:** 300 MB free space
- **Internet:** Required for activation and updates
- **ARM:** Native ARM64 support available

---

## ESET Official References

- **Homepage:** https://www.eset.com/
- **Download Page:** https://www.eset.com/us/download/home/
- **Offline Install KB:** https://support.eset.com/en/kb2885-download-and-install-eset-offline-or-install-older-versions-of-eset-products
- **Latest Versions:** https://help.eset.com/latestVersions
- **Changelog:** https://help.eset.com/changelogs/
- **End of Life Policy:** https://go.eset.com/eol_home
- **Binary Analysis Notes:** All installers are `Bootstrapper.exe` (identical XML config, same embedded MSI `ehs_nt64.msi`). Product differentiation is via license key, not the installer binary. Only ~0.51% of bytes differ between products.

---

*End of document.*
