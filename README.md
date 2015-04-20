# weaboot

Weaboo XDCC Leech Bot

# SYNOPSIS

weaboot --packs 1 \[2 3 ...\] \[ --nick bob \] \[ --limit <number> \] \[ --bot <name> \] \[ --channel <name> \]

# OPTIONS

- **-help**

    Print a brief help message and exit

- **-man**

    Prints the manual page and exits

- **-nick**

    The IRC nickname to use
    Default: rycr<PID %% 1000>

- **-limit**

    The integer limit for how many packs to request at one time
    Default: 2

- **-bot**

    The name of the bot to request packs from. Default: CR-TEXAS|NEW

- **-channel**

    The channel to join before requesting packs from the bot. This is typically
    because bots will check that you are in a channel they are in before accepting
    XDCC requests.
    Default: #horriblesubs

- **-packs**

    List of packs to request expressed as space separated values.
    Required argument.
    Example: weaboot --packs 321 231 123

- **-server**

    IRC server to connect to
    Default: irc.rizon.net

- **-port**

    Port to connect to irc server on
    Default: 6667

# DESCRIPTION

**weaboot** will connect to the given irc network to request XDCC packs from a
bot within a channel. This is to facilitate mass downloads when packlist
support is not functional. (Which is all the time)
