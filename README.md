# Agent Hops: The Dart Discord bot for beer lovers in Sweden

Agent Hops is a Discord bot written in Dart utilizing the [Nyxx Framework](https://github.com/l7ssha/nyxx), which fetches beer release information from [Systembevakningsagenten.se](https://systembevakningsagenten.se/). It also has the ability to get info from [untappd](https://untappd.com/) and send updates to specified channel when a user posts a new checkin.

## Getting started

Included in this repo is a `Dockerfile` and a `docker-compose.yaml` file to run the bot on a raspberry ARMv7.

And no, I wont go into details on how to register a developer account and get a dev token for discord. There are plenty of tutorials on that already. But you should probably start [here.](https://discord.com/developers/docs/intro)

### 1. Clone the repo to your raspberry

```bash
git clone https://github.com/oelburk/agentsbot.git
```

### 2. Run your favorite text-editor and open up the compose file (nano ftw)

```bash
cd agentsbot
nano docker-compose.yml
```

### 3. Set your discord token and optional data path

```yaml
...
    environment:
      ## Set your discord token here
      - DISCORD_TOKEN=YOUR TOKEN GOES HERE
    volumes:
      ## Optional: Set data path here, e.g ./my/data/path:/data
      - ./data:/data
```

### 4. Run compose up

```bash
docker-compose up -d
```

If you are having build issues, see the chapter **Known issues** further down.

### 5. Magic

You're done, the bot should be running in a minute! :magic_wand:

## Available commands

The bot is built on using global slash commands, all commands are available to all users in your discord except `/setup` which only will work for admins.

| Command    | Parameter          | Description                                                                                                                                                  |
| ---------- | ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `/help`    | -                  | Lists all available commands.                                                                                                                                |
| `/oel`     | -                  | Posts the latest beer releases available at systembevakningsagenten.se                                                                                       |
| `/regga`   | -                  | Register for automatic beer release reminders.se                                                                                                             |
| `/stopp`   | -                  | Unregister for automatic beer release reminders.                                                                                                             |
| `/release` | `YYYY-MM-dd`       | Posts the release for given date in the format YYYY-MM-dd.                                                                                                   |
| `/untappd` | `untappd username` | Let the bot know your untappd username so it can post automatic updates from your untappd account.                                                           |
| `/setup`   | -                  | Setup the bot to post untappd updates to the current channel. Only admins can issue this command. Also, this is needed before any untappd updates can occur. |

## Known issues

The Dockerfile can fail in some `os_linux.cc` file when running the pub get command, if that's the case be sure to update the `libseccom2` lib on the raspberry. See below for workaround.

> Thanks @a-siva
>
> That led me to [Raspberry Pi: clock_gettime(CLOCK_MONOTONIC, _) failed: Operation not permitted (1)](https://github.com/adriankumpf/teslamate/issues/2302) and from there to [Fix/Workaround - libseccomp2](https://blog.samcater.com/fix-workaround-rpi4-docker-libseccomp2-docker-20/). So I've installed the backported libseccomp2 and now my Dart app is building OK again with Dart 2.16.1 inside Docker on Raspberry Pi OS 10 Buster.
>
> ```shell
> # Get signing keys to verify the new packages, otherwise they will not install
> sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 04EE7237B7D453EC 648ACFD622F3D138
> 
> # Add the Buster backport repository to apt sources.list
> echo 'deb http://httpredir.debian.org/debian buster-backports main contrib non-free' \
>  | sudo tee -a /etc/apt/sources.list.d/debian-backports.list
> 
> sudo apt update
> sudo apt install libseccomp2 -t buster-backports
> ```
>
> Seems like a Raspberry Pi OS thing more than a Dart thing, so closing this issue. But hopefully other people who trip across the problem will find the workaround here.
