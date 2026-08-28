# Contributing to OpenRCT2 Touch

OpenRCT2 Touch is an independent iPadOS fork. Issues and patches that are
specific to the iPad port belong in
[`chrissotraidis/OpenRCT2Touch`](https://github.com/chrissotraidis/OpenRCT2Touch),
not in the upstream OpenRCT2 issue tracker.

## Report an iPad-port issue

Search this fork's issue tracker before filing a report. Include:

- the iPad model and iPadOS version;
- the OpenRCT2 Touch commit or build number;
- whether input used fingers, a mouse/trackpad, or a hardware keyboard;
- exact reproduction steps and the expected and actual behavior;
- a screenshot, screen recording, or crash log when useful; and
- whether the same behavior occurs in desktop upstream OpenRCT2.

Do not upload proprietary RCT/RCT2 assets, installation folders, or saves that
you do not have permission to redistribute. A minimal description or a park
made entirely from redistributable project fixtures is preferred.

## Contribute code to the port

Base port work on `ipad` or a short-lived branch intended for `ipad`. Keep
changes focused, preserve upstream file headers and attribution, prefix port
commits with `[touch]`, and run the relevant build loop plus
`./scripts/check-repo-safety.sh` before submitting a pull request to this fork.
Never submit OpenRCT2 Touch changes directly to upstream without first
coordinating with the upstream maintainers.

Changes that are general OpenRCT2 fixes rather than iPad-specific work should
follow the upstream contribution process below and be proposed to upstream
independently from the Touch port.

---

# Upstream OpenRCT2 contribution guidance

The original upstream guidance is preserved below for contributors working on
general OpenRCT2 rather than this iPad fork.

## Contributing to OpenRCT2
Any contribution to OpenRCT2 is welcome and valued. Contributions can be in the form of bug reports, translation or code
additions / changes. Please read this document to learn how to contribute as effectively as possible. If you have any
questions or concerns, please ask in the [Discord chat](https://discordapp.com/invite/fsEwSWs).

# Reporting bugs
To report a bug, ensure you have a GitHub account. Search the issues page to see if the bug has already been reported.
If not, create a new issue and write the steps to reproduce. Upload a saved game if possible as this is very helpful
for users to replicate the bug. Please state which architecture and version of the game you are running, e.g.
```
OpenRCT2, v0.0.6-develop build 84ddd12 provided by AppVeyor
Windows (x86-64)
```

This can be found either at the bottom left of the title screen or
by running:
```
openrct2 --version
```

For Windows builds, OpenRCT2 will generate a memory dump and saved game when the game crashes unexpectedly. The game
will open explorer to these files automatically for you. They are placed inside your configured user directory which
by default is `%HOMEPATH%\Documents\OpenRCT2`.

# Translation
Translation is managed in a separate repository, [OpenRCT2/Localisation](https://github.com/OpenRCT2/Localisation).
You will find more information there.

# Contributing code
Please read [How To Contribute](https://github.com/OpenRCT2/OpenRCT2/wiki/How-To-Contribute)

## Code hints
### Adding new strings
If you need to add a new localisable string to OpenRCT2, please add your new string entry to ```./data/language/en-GB.txt```.
It is important that you only edit en-GB in the OpenRCT2 repository as this is the base language that is used for
translation to other languages. A separate repository OpenRCT2/Localisation is used for translation pull requests, and changes
to that repository are merged with the OpenRCT2 main repository every night. When your pull request is merged, it is helpful
to create a new issue in the OpenRCT2/Localisation repository about the new strings you have added. This notifies translators
so that they can translate the new strings as quick as possible. Similarly if you change any existing string, it is more
important that you create an issue as this can be more easily overlooked.

When coding, please also add a string constant for your strings to ```./src/localisation/StringIds.h```.

### Coding style
Use [this](https://github.com/OpenRCT2/OpenRCT2/wiki/Coding-Style) code style as a reference for new or changed code.

### Language
For now, it is recommended that you only write C++ files as the majority of the game is currently in
C++. Exceptions are to modules that have direct relationship to original code.
