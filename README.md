# WoW AddOns

> Development has moved to separate repositories:
> [BlazeMail](https://github.com/Blazeflack/BlazeMail) and
> [BlazeTweaks](https://github.com/Blazeflack/BlazeTweaks).
> Please use those repositories for new issues, source changes and future releases.
> This repository retains the original source history and published releases;
> existing download links remain available.

This repository contains small, independent World of Warcraft addons developed for WoW Forever. Each addon addresses a specific need that existing addons did not meet.

Each addon lives in its own directory and can be installed separately.

## License

This repository and its addons are licensed under the [MIT License](./LICENSE).
Copyright (c) 2026 Blazeflack. You may use, modify and redistribute the code,
including commercially, provided that the copyright and license notices are
preserved in copies or substantial portions of the code. Each addon includes
its own copy of the license.

## Addons

- [BlazeMail](./BlazeMail/) adds a searchable recipient picker to the Send Mail window. Select an alt to fill in the recipient field. In **Characters / Settings**, you can choose a theme, mark individual characters as favorites, and add notes for each character.

  Open **Characters / Settings** with `/bm` or `/blazemail`, or click the **BlazeMail** button in the mailbox window.

  **Send Mail with the BlazeMail theme**

  ![Dark BlazeMail compose window with a searchable recipient list showing alt names and notes](./BlazeMail/images/send-mail-recipients.png)

  **Send Mail with the Blizzard theme**

  ![Blizzard’s parchment mail form beside the recipient picker with matching Blizzard controls](./BlazeMail/images/send-mail-blizzard.png)

  **Characters / Settings**

  ![BlazeMail settings showing the theme dropdown, character search, favorites and notes](./BlazeMail/images/manage-characters.png)

- [BlazeTweaks](./BlazeTweaks/) adds two independent options. One automatically opens newly acquired clams and other containers on a configurable list. The other automatically selects eligible NPC dialogue options. Hold Shift when talking to an NPC to choose manually.

  **Settings** — open with `/bt` or `/blazetweaks` to configure automatic containers, the shared item list and Bank, Taxi and Vendor dialogue choices.

  ![BlazeTweaks settings showing automatic containers, the shared item list and Bank, Taxi and Vendor gossip options](./BlazeTweaks/images/settings.png)
