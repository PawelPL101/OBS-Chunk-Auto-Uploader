# OBS Chunk Auto-Uploader

**Record for hours without ever running out of disk space.**

Automatically uploads your OBS recording chunks to the cloud and clears them
from your local drive — while you keep recording. Built for creators who record
huge, high-quality footage and don't want a 200 GB file eating their SSD.

*Developed by **PawelPL101***

*Version 1.0.2*

---

## The Problem This Solves

High-quality recordings are massive. A single session can generate **150+ GB per
hour**. If your SSD only has a few hundred GB free, you run out of space fast and
have to stop recording.

This tool fixes that. OBS splits your recording into chunks; this uploader sends
each finished chunk to the cloud, verifies it arrived safely, then deletes the
local copy — **freeing your disk continuously while you keep recording**.

The result: your local drive usage stays low and flat, while your footage piles
up safely in the cloud.

---

## How It Works

```
OBS records and splits into chunks (e.g. every 15 min)
                 |
        Watcher detects a finished chunk
                 |
        Uploads it to your cloud (via rclone)
                 |
        Verifies the upload with a checksum
                 |
        Deletes the local copy (cloud copy stays)
                 |
        Repeats - disk space continuously reclaimed
```

Crucially, this is an **archive** workflow, not a sync. Deleting the local file
does **not** delete the cloud copy. Your cloud footage is permanent.

---

## Features

- **Automatic upload + verify + delete** — completely hands-off once recording.
- **Checksum verification** — local files are only deleted after the upload is
  confirmed byte-for-byte correct. Safe by design.
- **Live dashboard** — colored, real-time display of upload speed, progress %,
  ETA, chunks completed, disk usage, and session + all-time totals.
- **Never loses footage** — if an upload fails, the local file is kept and
  retried. Nothing is deleted unless it's safely in the cloud.
- **Continuous recording** — uploads happen in the background; you never stop.
- **One-click setup** — `SETUP.bat` auto-detects your system and configures
  everything. No code editing required.
- **No admin rights needed**, and no permanent changes to your system security.

---

## Requirements

- **Windows 10 or 11** (this tool is Windows-only)
- **OBS Studio** (with automatic file splitting enabled)
- **rclone** (free — a short install guide is included)
- **A cloud storage account** supported by rclone. This tool works with **any**
  rclone-supported provider — including Google Drive, Dropbox, OneDrive,
  Backblaze B2, Amazon S3, Mega, pCloud, Box, and 60+ others. You choose your
  provider during setup.
- Enough cloud storage for your footage, and a reasonable upload connection.

> The included `how-to-install-rclone.txt` walks through Google Drive as an
> example, but the same process works for any provider — rclone's config will
> prompt you through whichever one you pick.

> **Note:** This tool does not work on macOS or Linux. It uses Windows-specific
> PowerShell and batch scripting.

---

## Installation

### 1. Extract the folder
Extract the downloaded `OBS-Chunk-Auto-Uploader` folder and place it at the root
of your C: drive, so the full path is:

```
C:\OBS-Chunk-Auto-Uploader
```

> **Recommended location:** `C:\OBS-Chunk-Auto-Uploader` is strongly recommended
> so your setup matches this guide and makes troubleshooting easier. The tool
> *will* work from any location (it finds its own files automatically), but
> putting it on C: keeps things consistent. Avoid putting it in special folders
> like Program Files, Desktop, or OneDrive-synced folders.

### 2. Install rclone
Open **`how-to-install-rclone.txt`** and follow the step-by-step guide. It takes
about 5 minutes and you only do it once. This also connects rclone to your cloud
account.

### 3. Run SETUP
Double-click **`SETUP.bat`**. It will:
- Detect your network adapter automatically
- Confirm rclone is installed
- Ask where OBS saves your recordings
- Ask which recording format and cloud service you use
- Save your configuration

### 4. Verify (optional but recommended)
Double-click **`TEST-Uploader.bat`** to confirm everything works. It uploads a small
test file, verifies it, and cleans up. All checks should pass.

### 5. Configure OBS
In OBS: **Settings → Output → Recording**
- Set the **Recording Path** to the same folder you gave SETUP
- Set your **Recording Format** to match what you chose in SETUP (MKV recommended)

Then **Settings → Output → Recording → Split Recording**
- Enable **Automatically split recording**
- Set **Split by time** (15 minutes is a good default)

---

## Daily Use

1. Double-click **`START-Uploader.bat`** — the live dashboard opens and the
   uploader runs in the background.
2. Open OBS and **record** as long as you want.
3. When done, **stop the OBS recording**.
4. Wait for the dashboard to say **"Idle - all caught up"** (the last chunk
   finished uploading).
5. Double-click **`STOP-Uploader.bat`** and confirm.

That's it. Everything in between is automatic.

> Closing the dashboard window does **not** stop uploads — the uploader runs
> separately in the background. Use `STOP-Uploader.bat` to actually stop it.

---

## File Overview

```
OBS-Chunk-Auto-Uploader/
├── SETUP.bat                  ← run this first (one-time setup)
├── START-Uploader.bat         ← start uploading + open dashboard
├── STOP-Uploader.bat          ← stop the uploader safely
├── TEST-Uploader.bat          ← verify your setup works (optional)
├── README.md                  ← this file
├── how-to-install-rclone.txt  ← rclone install guide
├── LICENSE.txt                ← license terms
├── config.txt                 ← your settings (created by SETUP)
├── scripts/                   ← the engine (you don't need to touch these)
│   ├── Setup-Wizard.ps1
│   ├── Watch-OBSChunks.ps1
│   ├── Dashboard.ps1
│   ├── Load-Config.ps1
│   ├── Stop-Uploader.ps1
│   └── Test-Pipeline.ps1
└── data/                      ← auto-generated runtime files (logs, stats)
```

You only ever interact with the `.bat` files. Everything in `scripts/`
and `data/` runs automatically behind the scenes.

---

## Troubleshooting

**Dashboard says "config.txt not found"**
→ Run `SETUP.bat` first to create your configuration.

**"rclone not found" during setup**
→ Follow `how-to-install-rclone.txt`. rclone must be installed before setup.

**Upload speed seems capped (e.g. ~250 Mbps even on gigabit)**
→ This is normal. Most cloud providers limit single-file upload speed on their
end. Your connection isn't the bottleneck. As long as chunks upload faster than
you record them, disk space is still continuously reclaimed.

**A chunk failed to upload**
→ The local file is kept (never deleted on failure) and automatically retried.
Nothing is lost. Check `upload-log.txt` in your recordings folder for details.

**Disk filling up during a long session**
→ If your chunks are very large, they may upload slower than you record. Reduce
the OBS split time (e.g. from 15 to 10 minutes) so each chunk is smaller and
uploads faster.

---

## How Your Footage Stays Safe

- Local files are deleted **only** after a successful upload **and** a passing
  checksum verification.
- Failed uploads keep the local file and retry.
- The cloud copy is independent — deleting locally never affects it.
- Every action is logged to `upload-log.txt`.

---

## Found a bug?

If you run into a bug or something isn't working right, please email:

**contact.pawelpl101@gmail.com**

Include what happened, what you expected, and (if you can) the last few lines of
your `upload-log.txt`. That helps a lot in tracking the issue down.

---

## License

Copyright (c) 2026 **PawelPL101**

Licensed under **Creative Commons Attribution-NoDerivatives 4.0 International
(CC BY-ND 4.0)**.

You are free to **use** (including commercially) and **share** this software,
provided you give credit and do not distribute modified versions. See
`LICENSE.txt` for full terms.

---

*Made for creators who just want to hit record and not worry about storage.*
