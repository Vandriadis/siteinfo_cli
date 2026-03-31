# SiteInfo

Modular terminal utility for website reconnaissance and security checks.

## Features

- DNS, HTTP, technology, security headers, WHOIS, and threat-intel modules
- Threat integrations: VirusTotal, Safe Browsing, AbuseIPDB, IPinfo, Shodan, urlscan
- Interactive menu with scan profiles: `quick`, `standard`, `deep`
- Built-in API response cache to reduce rate-limit usage

## Requirements

- `zsh`, `curl`, `dig`, `host`
- optional: `jq` (recommended for accurate JSON parsing)

## Setup

1. Copy env template:

```bash
cp .env.example .env
```

2. Fill API keys in `.env`.

## Run

```bash
./siteinfo.zsh
./siteinfo.zsh --profile quick
./siteinfo.zsh --profile standard
./siteinfo.zsh --profile deep
```

Shortcuts:

```bash
./siteinfo.zsh --quick
./siteinfo.zsh --deep
```

## Profiles

- `quick`: low-cost checks (Safe Browsing, AbuseIPDB, core modules)
- `standard`: adds medium-cost enrichment (VirusTotal, IPinfo)
- `deep`: full threat stack (includes Shodan + urlscan)

## Cache

- Cache path: `.cache/siteinfo/`
- Default TTL: 6 hours for threat API calls
- Cache reduces repeated requests and free-plan quota usage
