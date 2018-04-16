
SotA - State of the Art
=======================

- The next step in DKP!


Contents
    1.  What is Sota?
	  1.1.  DKP assignment
	  1.2.  Auctions
	  1.3.  Raid queue
	  1.4.  Transaction log
	2.  DKP
	  2.1.  Ranged DKP
	  2.2.  Shared DKP
	  2.4.  Penalizing DKP	
	3.  Configuration
	  3.1.  Bidding options
	  3.2.  Boss DKP
	  3.3.  Misc. DKP options
	4.  Command Line Interface
	  4.1.  DKP Commands
	  4.2.  Queue Commands
	  4.3.  Auction Interface
      4.4.  Other Commands	  
	5.  Miscellaneous



1. What is SotA?
----------------
SotA is an addon to manage DKP for the guild. The DKP for each player is
stored in the public guild notes or officer notes, and can thereby be exported
via addons such as RPGO_GuildProfiler.

It is an extension of the addon called GuildDKP. It is also compatible with
GuildDKP, meaning the DKP values written by GuildDKP can be read (and updated)
by SotA. You can even have both addons installed at the same time.

The overall functionality of SotA can be divided into four main categories,
each described below.


SotA is controlled by a "SOTA Master"; this is the person currently in control
of the auction and raid queue (handling "!queue" commands in gchat for
example).
There can only be one SOTA Master to avoid players are getting multiple
whispers when firing commands from the gchat.
The Master is automatically assigned and is always set to the last person
issuing a DKP or Auction command. However, any (promoted) officer can request
SOTA master status by clicking the SOTA master icon ("Blessing of Kings"), or
type "/sota master" in the console.
Note that the SOTA Master does not have more "power" than other promoted
officers, he just handles the background tasks.



1.1. DKP assignment
This part of SotA is almost a copy of the original addon called GuildDKP.
This handles all the DKP transactions: add and remove DKP from one or more
players.

This module is fully controlled from the command line.


1.2. Auctions
Items dropping in a raid can be Auctionned using this module.

The module is initated from the command line using the syntax:
    /sota <item link>

The <item link> is linked to the console by shift-clicking the item.
The rest of the auction process is done in the UI - including pausing,
cancelling and finishing the auction.


1.3. Raid queue
If the raid is full, and there are people waiting for a spot, they can join
the raid queue.
This is done by typing "!queue <role>" in guild chat. The <role> must be
either "tank", "melee", "ranged" or "healer".

When a character join the queue, he/she will get DKP when the raid gets DKP
also.
The default behavior is to restrict the DKP only being handed out to charac-
ters being outside the instance (waiting to get in).

When pressing the queue icon in the ui (icon same as Prayer of Spirit), the
raid queue interface will open.
This shows all the characters currently in queue, and divided into their
respective role.
Left-clicking on a character will invite him to the raid.
Right-clicking on a character will remove him from the queue.
Left-clicking on a role will send an invite to all players for that role.

As soon a player accepts the invite, he is removed from the raid queue again.

If a player disconnect, he will still be in the raid queue, but not recieve
DKP.

A player can change his role by typing "!queue <new role>" in gchat.


1.4. Transaction log
The transaction log can be opened from the UI (the "note" icon) or directly
from the console using "/sota log".

The log displays the recent transactions, with a "+" or "-" icon, depending
of the transaction type.
Clicking on a transaction will show the details: which characters got DKP.
You can here click on a person to include or exclude hom from the transacion.

If the transaction is a single-player transaction, then clicking on another
player will replace the target; the original player got his DKP back and the
new selected player will be reducted the same amount.
This is used to easy fix a situation where DKP was given or taken to/from a
wrong person.



2. DKP
------
Like GuildDKP, SotA operates with DKP in different forms:

 * Ranged DKP
 * Shared DKP
 * Penalizing DKP


2.1. Ranged DKP
Ranged DKP means that the DKP given will only effect (online) characters
within 100 yards range.
This type of DKP is good for e.g. OnTime DKP, allowing only people nearby
getting DKP.
Note that if you give ranged DKP outside an instance, the people inside the
instance will not get DKP, since they are technically out of range!


2.2. Shared DKP
A unique feature of GuildDKP was the ability to share DKP acros entire raid.
This feature was ported to SotA as well.
This means that you apply a certain amount of DKP per boss - for example 1000
DKP for killing a boss.
When you share this, each raid member will get (1000 divided by number of raid
members); for a 40 man raid this is 1000 / 40 = 25 DKP.
But if only 30 people were in the raid, the value would be 1000 / 30 = 33.333.
SotA rounds up, so each player recieve 34 DKP instead.

Note that GuildDKP supports ranged shared DKP - this is not supported by SotA
since this feature was never user.


2.3. Penalizing DKP
DKP is often used to punish a player for wiping the raid / whatever. And you
can of cause do this by simply subtracting 100 DKP from said player.
But if that player have 5000 DKP already, he won't really feel the punishment
at all.
Therefore you can chose to subtract a percentage instead. 100 DKP might not
hurt - but 20% penalty DKP will: 20% of 5000 is 1000 DKP.

A minimum of 50 DKP will always be subtracted, regardless of the targets
current DKP (yes, it can go into minus as well)



3. Configuration
----------------
SotA can be configured by pressing the cockwheel in the UI (if in a raid),
or opening the UI manually by typing "/sota config" in the console.

The configuration screen contains three sub-screens ("pages"), described
below.


3.1. Bidding options
The Auction timers are used to control the duration of an auction.
The default is 25 seconds before auction is closed, with 8 seconds being added
when a new bid is received.
These durations can be changed by adjusted the sliders.

"Enable OS bidding" will - if ticked ON (default) - prioritize bids by MS/OS.
If ticked OFF, the OS bidding will not be possible.

"Enable Raid Queue Zonecheck" - if enabled, queue DKP will only be given ti
characters which are currently online and outside the instance (in the same
zone as the instance).

"Disable (hide) Dashboard" - will hide the dashboard from the UI in raids.



3.2. Boss DKP
Each instance can be configured with a Boss DKP value between 0 and 4000 DKP.
When boss DKP is shared by pressing the Money icon in the UI, the suggested
amount of DKP is given will be taken from these sliders.



3.3. Misc. DKP options
"Store DKP in Public Guild Notes" - if enabled, the DKP will be stored in the
public guild notes, otherwise the Officer notes will be used.

Bid rules:
SotA currently supports 4 different bid rules: rules for how much to increase
each bid in an auction.
- "No minimum bid rules":
People can bid whatever they want, as long the bid is higher than the previous
one.

- "Minimum increase by 10 DKP":
Next bid must be at least 10 DKP higher.

- "Minimum increase by 10 %":
Next bid must be at least 10% higher.

- "GGC rules":
Next bid must be at least 10 DKP higher if current bid is 200 or less.
If current bid is between 200 and 1000, then next bid must be increased by (at
least) 50, else bid must be increased by at least 100 DKP.


"DKP String length"
The length of the DKP string written in guild/officer notes can be set using
this slider. having a fixed length makes sorting by DKP easy in the guild
roster.

"Minimum DKP penalty"
If penalty DKP is used, the amount withdrawn cannot be lower than this number.
This prevents people with negative DKP to actually gain DKP by wiping the
raid!



4. Command Line Interface
The following commands can be used from the Console.

4.1. DKP Commands

/sota dkp [player]
Show how much DKP [player] currently have. If [player] is left out, the
current player is used.
This command is same as the "/dkp" command in GuildDKP.

/sota class [class]
Show top 10 DKP for [class]. If [class] is left out, the class of the current
player is used.
This command is same as the "/classdkp" in GuildDKP.

/sota +<n> <player>
Add <n> DKP to <player>.
Same as "/gdplus" in GuildDKP.

/sota -<n> <player>
Subtract <n> DKP from <player>.
Same as "/gdminus" in GuildDKP.

/sota -<n>% <player>
Subtract <n> percent DKP from <player>. The minus sign is optional.
Same as "/gdminuspct" in GuildDKP.

/sota raid +<n>
Add <n> DKP to all players in the raid (including the raid queue).
Same as "/addraid" in GuildDKP, except that GuildDKP does not support raid
queues.

/sota raid -<n>
Subtract <n> DKP from all players in the raid (including the raid queue).
Same as "/subtractraid" in GuildDKP, except that GuildDKP does not support
raid queues.

/sota range +<n>
Add <n> DKP tp all online players in range, and all online players in raid
queue (no range check). The plus sign is optional.
This is same as the command "/addrange" in guild dkp, except that GuildDKP
does not support raid queues.

/sota share +<n>
Share <n> DKP across all raid players. Online players in raid queue will be
given same amount.
This is same as the command "/shareraid" in the GuildDKP addon, except that 
GuildDKP does not support raid queues.

/sota sharerange +<n>
Same as "/sota share +<n>", but only shares to online players within range.
Players in raid queue will receive same amount. This command is same as the
"/sharerange" command in the GuildDKP addon, except that  GuildDKP does not 
support raid queues.

/sota decay <n>%
Remove <n> percent DKP from ALL players in the guild.
Same as "/gddecay" in GuildDKP.



4.2. Queue Commands
The queue commands sometimes uses <role> as parameter. <role> can be one of
the following: "tank", "melee", "ranged" or "healer".

/sota queue
Display current queue status: How many players are in queue of each role.
This command can also be triggered by typing "!queue" in guild chat.

/sota queue <role>
Put yourself in queue as <role>.
Note: you cannot put others into the queue this way - for that, use  "/sota
addqueue" below.

/sota addqueue <player> <role>
Add <player> to the raid queue as <role>.

/sota leave
Leave the raid queue. Can also be done from gchat: "!leave"



4.3. Auction Interface
<item> is here the Item link, which can be set by shift-clicking the item.

/sota <item>
Starts an auction for <item>.

/sota bid <n>
Bid <n> DKP for the item currently being auctioned.
If <n> is "min", the minimum allowed bid is used.
If <n> is "max", the maximum bid (All out) is used.
This command can be used from the Raid (or Guild) chat witn "!bid <n>".



4.4. Other Commands

/sota config
Open the configuration interface.

/sota log
Open the transaction log interface

/sota version
Check the SOTA versions running

/sota master
Force player to become Master (if he is raid leader or assistant)

/sota help
Show HELP page (more or less this page!)



5. Miscellaneous
----------------
SOTA was developed by Mimma <VanillaGaming / Nostalrius>, and is one
of many addons named after famous priests on VanillaGaming.org.
Thus SOTA refers to the dwarf priest named Sotason, which has given (and
taken) many DKP to/from us using GuildDKP.

Other addons are:
* Captain - named after Sheyliny @ Vanillagaming.org
A GM addon to process tickets and other GM utilities.

* Monet - named after Gfk/Monet @ Vanillagaming.org
An addon to assign priest, mage, druid buffing and buff groups in general.

* PiTTY - named after Pitzwald @ Vanillagaming.org
An addon to "bust" people using QuickHeal.

* Thaliz - named after Thaliz @ Vanillagaming.org (may his soul rest in peace)
An addon to resurrect people with automatic target detection and random
resurrection texts.

