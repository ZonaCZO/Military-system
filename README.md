[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/sakutoro)

# CC-Military Strategic System

A specialized collection of ComputerCraft programs for secure file management, networking, and tactical PDA enhancements.

---

## 📁 Installer

Only two complete packages are offered:

* **MSOS Command OS** — the headquarters OS, including tactical maps, radar, browsers, icons and required drivers.
* **Central Server Core** — the central network server and all required server modules.

Maps are MSOS components and are not distributed as separate user-facing downloads.

The OS also includes an optional Wake Nodes manager. It works with the separate
[CC Wake Nodes](https://github.com/cogilabs/CC-Wake-Nodes) mod when a `wake_controller`
is attached. If the mod or peripheral is absent, the manager reports that the feature is
unavailable and exits normally; no other MSOS program depends on the mod.

Central Server installations include the optional `/wake.lua` setup utility. Attach a
Wake Node directly to the server computer, run `wake setup central_server`, then authorize
the headquarters computer with `wake grant <HQ_COMPUTER_ID>`. The headquarters Wake
Controller can then load the server chunk before opening network applications. Use
`wake status`, `wake revoke <ID>`, or `wake help` for administration. If the mod is absent,
the utility exits normally and the server core remains independent from it.
These commands can be entered directly at the Central Server `ADM>` console; opening the
normal CraftOS shell is not required.

## Updating

The complete MSOS includes an `updater` application and icon. The Central Server
installs the same program as `/update.lua`. It detects the installation type,
downloads the current official installer and replaces managed programs and icons.
Network configuration and operational data are preserved. On an ambiguous computer,
run `updater os` or `update server` explicitly.
Update downloads include a cache-busting value so one update run cannot mix older cached
programs with a newer installer.

* **Installer:**.
`wget run https://raw.githubusercontent.com/ZonaCZO/Military-system/main/install/install.lua`


### 🛠 Installation Instructions

1. Open your ComputerCraft terminal.
2. Enable CC:Tweaked HTTP downloads for installation. Attach a wireless or wired modem for the in-game network; a modem does not enable HTTP access.
3. Run the command and select `1` for MSOS or `2` for Central Server Core.
4. Existing network configuration and saved operational data are preserved when program files are updated.


---

**PS:** if you see some russian words in code, i know about this but i am lazy ass and i will translate in other lang later. 

If you have some questions, i can answer on ru, ua and eng languages. Discord: zonaczo; Email: nikitaprox93@gmail.com

