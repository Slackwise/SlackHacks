setfenv(1, _G.SlackHacks)

ITEM_NAMES = {
  ["Sunfire Silk Spellthread"] = 240133,
  ["Arcanoweave Spellthread"] = 240155,
  ["Flawless Versatile Peridot"] = 240894,
  ["Flawless Deadly Peridot"] = 240890,
  ["Flawless Masterful Peridot"] = 240892,
  ["Flawless Deadly Amethyst"] = 240898,
  ["Flawless Quick Amethyst"] = 240900,
  ["Flawless Quick Garnet"] = 240906,
  ["Flawless Masterful Garnet"] = 240908,
  ["Flawless Versatile Garnet"] = 240910,
  ["Flawless Deadly Lapis"] = 240914,
  ["Flawless Quick Lapis"] = 240916,
  ["Flawless Masterful Lapis"] = 240918,
  ["Powerful Eversong Diamond"] = 240967,
  ["Telluric Eversong Diamond"] = 240968,
  ["Indecipherable Eversong Diamond"] = 240983,
  ["Flask of the Magisters"] = 241322,
  ["Flask of the Blood Knights"] = 241324,
  ["Flask of the Shattered Sun"] = 241326,
  ["Flask of Thalassian Resistance"] = 241320,
  ["Royal Roast"] = 242275,
  ["Thalassian Phoenix Oil"] = 243734,
  ["Enchant Boots - Lynx's Dexterity"] = 243953,
  ["Enchant Ring - Eyes of the Eagle"] = 243957,
  ["Enchant Ring - Silvermoon's Tenacity"] = 244017,
  ["Enchant Shoulders - Akil'zon's Swiftness"] = 243963,
  ["Enchant Weapon - Berserker's Rage"] = 243973,
  ["Enchant Chest - Mark of the Worldsoul"] = 243977,
  ["Enchant Helm - Empowered Blessing of Speed"] = 243981,
  ["Enchant Helm - Empowered Hex of Leeching"] = 243951,
  ["Enchant Boots - Shaladrassil's Roots"] = 243983,
  ["Enchant Ring - Nature's Fury"] = 243987,
  ["Enchant Shoulders - Amirdrassil's Grace"] = 243991,
  ["Enchant Helm - Empowered Rune of Avoidance"] = 244007,
  ["Enchant Boots - Farstrider's Hunt"] = 244009,
  ["Enchant Ring - Silvermoon's Alacrity"] = 244015,
  ["Enchant Shoulders - Silvermoon's Mending"] = 244021,
  ["Enchant Weapon - Acuity of the Ren'dorei"] = 244029,
  ["Forest Hunter's Armor Kit"] = 244641,
  ["Blood Knight's Armor Kit"] = 244643,
  ["Void-Touched Augment Rune"] = 259085,
  ["Enchant Weapon - Rite of the Hash'ey"] = 273072,
  ["Enchant Weapon - Jan'alai's Precision"] = 243971,
  ["Enchant Weapon - Arcane Mastery"] = 244031,
  ["Enchant Ring - Zul'jin's Mastery"] = 243959,
  ["Enchant Shoulders - Flight of the Eagle"] = 243961,
  ["Enchant Chest - Mark of the Magister"] = 244003,
}

ITEM_NAMES_BY_ID = {}
for itemName, itemID in pairs(ITEM_NAMES) do
  ITEM_NAMES_BY_ID[itemID] = itemName
end

SLOT_IDS = {
  HEAD = 1,
  NECK = 2,
  SHOULDER = 3,
  SHIRT = 4,
  CHEST = 5,
  WAIST = 6,
  LEGS = 7,
  FEET = 8,
  WRIST = 9,
  HANDS = 10,
  FINGER1 = 11,
  FINGER2 = 12,
  TRINKET1 = 13,
  TRINKET2 = 14,
  BACK = 15,
  MAINHAND = 16,
  OFFHAND = 17,
}

SECONDARY_GEM_QUANTITY = 6
DEFAULT_ENHANCEMENT_SOURCE = "murlok"

SELF_VENDOR_TRIGGER_EMOTES = {}
local function addSelfVendorTriggerEmotes(entries)
  for token, slashCommands, example in entries:gmatch("([A-Z]+)|([^|]+)|([^\n]+)") do
    SELF_VENDOR_TRIGGER_EMOTES[token] = {
      slashCommands = slashCommands,
      example = example,
      trigger = example:lower(),
    }
  end
end

addSelfVendorTriggerEmotes([[ABSENT|/absent|You look at %s absently.
AGREE|/agree|You agree with %s.
AMAZE|/amaze|You are amazed by %s!
ANGRY|/angry /mad|You raise your fist in anger at %s.
APOLOGIZE|/apologize /sorry|You apologize to %s. Sorry!
APPLAUD|/applaud /bravo /applause|You applaud at %s. Bravo!
ARM|/arm|You put your arm around %s's shoulder.
ATTACKTARGET|/attacktarget|You tell everyone to attack %s.
AWE|/awe|You stare at %s in awe.
BADFEELING|/badfeeling /bad|You have a bad feeling about %s.
BARK|/bark|You bark at %s.
BASHFUL|/bashful|You are so bashful...too bashful to get %s's attention.
BECKON|/beckon|You beckon %s over.
BEG|/beg|You beg %s. How pathetic!
BITE|/bite|You bite %s. Ouch!
BLAME|/blame|You blame %s for everything.
BLANK|/blank|You stare blankly at %s.
BLINK|/blink|You blink at %s.
BLUSH|/blush|You blush at %s.
BOGGLE|/boggle|You boggle at %s.
BONK|/bonk /doh|You bonk %s on the noggin. Doh!
BOOP|/boop|You boop %s's nose.
BOOT|/boot|You kick at %s.
BORED|/bored|You are terribly bored with %s.
BOUNCE|/bounce|You bounce up and down in front of %s.
BOW|/bow|You bow before %s.
BRANDISH|/brandish|You brandish your weapon fiercely at %s.
BRB|/brb|You let %s know you'll be right back.
BREATH|/breath|You tell %s to take a deep breath.
BURP|/burp /belch|You burp rudely in %s's face.
BYE|/bye /goodbye /farewell|You wave goodbye to %s. Farewell!
CACKLE|/cackle|You cackle maniacally at %s.
CALM|/calm|You try to calm %s down.
CHALLENGE|/challenge|You challenge %s to a duel.
CHARM|/charm|You think %s is charming.
CHEER|/cheer /woot|You cheer at %s.
CHICKEN|/chicken /flap /strut|With arms flapping, you strut around %s. Cluck, Cluck, Chicken!
CHUCKLE|/chuckle|You chuckle at %s.
CHUG|/chug|You encourage %s to chug. CHUG! CHUG! CHUG!
CLAP|/clap|You clap excitedly for %s.
COLD|/cold|You let %s know that you are cold.
COMFORT|/comfort|You comfort %s.
COMMEND|/commend|You commend %s on a job well done.
CONFUSED|/confused|You look at %s with a confused look.
CONGRATULATE|/congratulate /congrats /grats|You congratulate %s.
COUGH|/cough|You cough at %s.
COVEREARS|/coverears|You cover %s's ears.
COWER|/cower /fear|You cower in fear at the sight of %s.
CRACK|/crack /knuckles|You crack your knuckles while staring at %s.
CRINGE|/cringe|You cringe away from %s.
CROSSARMS|/crossarms|You cross your arms at %s. Hmph!
CRY|/cry /sob /weep|You cry on %s's shoulder.
CUDDLE|/cuddle /spoon|You cuddle up against %s.
CURIOUS|/curious|You are curious what %s is up to.
CURTSEY|/curtsey|You curtsey before %s.
DANCE|/dance|You dance with %s.
DING|/ding|You congratulate %s on a new level. DING!
DISAGREE|/disagree|You disagree with %s.
THREATEN|/threaten /doom /threat /wrath|You threaten %s with the wrath of doom.
DOUBT|/doubt|You doubt %s.
DRINK|/drink /shindig|You raise a drink to %s. Cheers!
DROOL|/drool|You look at %s and begin to drool.
DUCK|/duck|You duck behind %s.
EAT|/eat /chew /feast|You begin to eat in front of %s.
EMBARRASS|/embarrass|You are embarrassed by %s.
ENCOURAGE|/encourage|You encourage %s.
ENEMY|/enemy|You warn %s that an enemy is near.
EYE|/eye|You eye %s up and down.
EYEBROW|/eyebrow /brow|You raise your eyebrow inquisitively at %s.
FACEPALM|/facepalm /palm|You look at %s and cover your face with your palm.
FAINT|/faint|You faint at the sight of %s.
FART|/fart|You brush up against %s and fart loudly.
FIDGET|/fidget /impatient|You fidget impatiently while waiting for %s.
FLEE|/flee /retreat|You yell for %s to flee!
FLEX|/flex /strong|You flex at %s. Oooooh so strong!
FLIRT|/flirt|You flirt with %s.
FLOP|/flop|You flop about helplessly around %s.
FOLLOWME|/followme|You motion for %s to follow.
FROWN|/frown /disappointed|You frown with disappointment at %s.
GASP|/gasp|You gasp at %s.
GAZE|/gaze|You gaze longingly at %s.
GIGGLE|/giggle|You giggle at %s.
GLARE|/glare|You glare angrily at %s.
GLOAT|/gloat|You gloat over %s's misfortune.
GLOWER|/glower|You glower at %s.
GO|/go|You tell %s to go.
GOING|/going|You tell %s that you must be going.
GOLFCLAP|/golfclap|You clap for %s, clearly unimpressed.
GREET|/greet /greetings|You greet %s warmly.
GRIN|/grin /wicked /wickedly|You grin wickedly at %s.
GROAN|/groan|You look at %s and groan.
GROVEL|/grovel /peon|You grovel before %s like a subservient peon.
GROWL|/growl|You growl menacingly at %s.
GUFFAW|/guffaw|You take one look at %s and let out a guffaw!
HAIL|/hail|You hail %s.
HAPPY|/happy /glad /yay|You are very happy with %s!
HEADACHE|/headache|You are getting a headache from %s's antics.
HELLO|/hello /hi|You greet %s with a hearty hello!
HIGHFIVE|/highfive|You give %s a high five!
HISS|/hiss|You hiss at %s.
HOLDHAND|/holdhand|You hold %s's hand.
HUG|/hug|You hug %s.
HUNGRY|/hungry /food /pizza|You are hungry. Maybe %s has some food...
HURRY|/hurry|You tell %s to hurry up.
HUZZAH|/huzzah|You cheer boisterously for %s! Huzzah!
IMPRESSED|/impressed|You clap vigorously for %s, clearly impressed.
INCOMING|/incoming|You point out %s as an incoming enemy!
INSULT|/insult|You think %s is the son of a motherless ogre.
INTRODUCE|/introduce|You introduce yourself to %s.
JEALOUS|/jealous|You are jealous of %s.
JK|/jk|You let %s know that you were just kidding!
KISS|/kiss /blow|You blow a kiss to %s.
KNEEL|/kneel|You kneel before %s.
LAUGH|/laugh /lol|You laugh at %s.
LAYDOWN|/laydown /liedown /lay /lie|You lie down before %s.
LICK|/lick|You lick %s.
LISTEN|/listen|You listen intently to %s.
LOOK|/look|You look at %s.
LOST|/lost|You want %s to know that you are hopelessly lost.
LOVE|/love|You love %s.
LUCK|/luck|You wish %s the best of luck.
MAGNIFICENT|/magnificent|You nod approvingly at %s. Magnificent job!
MASSAGE|/massage|You massage %s's shoulders.
MEOW|/meow|You meow at %s.
MERCY|/mercy|You plead with %s for mercy.
MOAN|/moan|You moan suggestively at %s.
MOCK|/mock|You mock the foolishness of %s.
MOO|/moo|You moo at %s. Mooooooooooo.
MOON|/moon|You drop your trousers and moon %s.
MOURN|/mourn|In quiet contemplation, you mourn the death of %s.
MUTTER|/mutter|You mutter angrily at %s. Hmmmph!
NERVOUS|/nervous|You look at %s nervously.
NO|/no|You tell %s NO. Not going to happen.
NOD|/nod /yes|You nod at %s.
NOSEPICK|/nosepick /pick|You pick your nose and show it to %s.
OBJECT|/object /objection /holdit|You object to %s.
OFFER|/offer|You attempt to make %s an offer they can't refuse.
PANIC|/panic|You take one look at %s and panic.
PAT|/pat|You gently pat %s.
PEER|/peer|You peer at %s searchingly.
PET|/pet|You pet %s.
PINCH|/pinch|You pinch %s.
PITY|/pity|You look down upon %s with pity.
PLEAD|/plead|You plead with %s.
POINT|/point|You point at %s.
POKE|/poke|You poke %s. Hey!
PONDER|/ponder|You ponder %s's actions.
POUNCE|/pounce|You pounce on top of %s.
POUT|/pout|You pout at %s.
PRAISE|/praise /lavish|You lavish praise upon %s.
PRAY|/pray|You say a prayer for %s.
PROMISE|/promise|You make %s a promise.
PROUD|/proud|You are proud of %s.
PULSE|/pulse|You check %s for a pulse. Oh no!
PUNCH|/punch|You punch %s's shoulder.
PURR|/purr|You purr at %s.
PUZZLED|/puzzled|You are puzzled by %s.
QUACK|/quack|You quack at %s. Quack!
RAISE|/raise /volunteer|You look at %s and raise your hand.
RASP|/rasp|You make a rude gesture at %s.
READY|/ready /rdy|You let %s know that you are ready!
REGRET|/regret|You think that %s will regret it.
REVENGE|/revenge|You vow revenge on %s.
ROAR|/roar /rawr|You roar with bestial vigor at %s. So fierce!
ROFL|/rofl|You roll on the floor laughing at %s.
ROLLEYES|/rolleyes /eyeroll|You roll your eyes at %s.
RUDE|/rude|You make a rude gesture at %s.
RUFFLE|/ruffle|You ruffle %s's hair.
SALUTE|/salute|You salute %s with respect.
SCARED|/scared|You are scared of %s.
SCOFF|/scoff|You scoff at %s.
SCOLD|/scold|You scold %s.
SCOWL|/scowl|You scowl at %s.
SCRATCH|/scratch /cat /catty|You scratch %s. How catty!
SEARCH|/search|You search %s for something.
SEXY|/sexy|You think %s is a sexy devil.
SHAKE|/shake /rear|You shake your rear at %s.
SHAKEFIST|/shakefist /fist|You shake your fist at %s.
SHIFTY|/shifty|You give %s a shifty look.
SHIMMY|/shimmy|You shimmy before %s.
SHIVER|/shiver|You shiver beside %s. Chilling!
SHOO|/shoo /pest|You shoo %s away. Be gone pest!
HOLLER|/holler|You shout at %s.
SHRUG|/shrug|You shrug at %s. Who knows?
SHUDDER|/shudder|You shudder at the sight of %s.
SHY|/shy|You smile shyly at %s.
SIGH|/sigh|You sigh at %s.
SIGNAL|/signal|You give %s the signal.
SILENCE|/silence /shush|You tell %s to be quiet. Shhh!
SILLY|/silly|You tell %s a joke.
SING|/sing|You serenade %s with a song.
SLAP|/slap|You slap %s across the face. Ouch!
SMACK|/smack|You smack %s upside the head.
SMILE|/smile|You smile at %s.
SMIRK|/smirk|You smirk slyly at %s.
SNAP|/snap|You snap your fingers at %s.
SNARL|/snarl|You bare your teeth and snarl at %s.
SNEAK|/sneak|You try to sneak away from %s.
SNEEZE|/sneeze|You sneeze on %s. Achoo!
SNICKER|/snicker|You snicker at %s.
SNIFF|/sniff|You sniff %s.
SNORT|/snort|You snort derisively at %s.
SNUB|/snub|You snub %s.
SOOTHE|/soothe|You soothe %s. There, there...things will be ok.
SPIT|/spit|You spit on %s.
SQUEAL|/squeal|You squeal at %s.
STARE|/stare|You stare %s down.
STINK|/stink /smell|You smell %s. Wow, someone stinks!
SURPRISED|/surprised|You are surprised by %s's actions.
SURRENDER|/surrender|You surrender before %s. Such is the agony of defeat...
SUSPICIOUS|/suspicious|You are suspicious of %s.
SWEAT|/sweat|You sweat at the sight of %s.
TALK|/talk|You want to talk things over with %s.
TALKEX|/talkex /excited|You talk excitedly with %s.
TALKQ|/talkq /question|You question %s.
TAP|/tap|You tap your foot as you wait for %s.
TAUNT|/taunt|You make a taunting gesture at %s. Bring it!
TEASE|/tease|You tease %s.
THANK|/thank /thanks /ty|You thank %s.
THINK|/think|You think about %s.
THIRSTY|/thirsty|You let %s know you are thirsty. Spare a drink?
TICKLE|/tickle|You tickle %s. Hee hee!
TIRED|/tired|You let %s know that you are tired.
TRUCE|/truce|You offer %s a truce.
VETO|/veto|You veto %s's motion.
VICTORY|/victory|You bask in the glory of victory with %s.
VIOLIN|/violin|You play the world's smallest violin for %s.
WAIT|/wait|You ask %s to wait.
WARN|/warn|You warn %s.
WAVE|/wave|You wave at %s.
WELCOME|/welcome|You welcome %s.
WHINE|/whine|You whine pathetically at %s.
WHISTLE|/whistle|You whistle at %s.
WHOA|/whoa|You are blown away by %s.
WINCE|/wince|You wince sympathetically at %s. That looked like it hurt!
WINK|/wink|You wink slyly at %s.
WORK|/work|You work with %s.
YAWN|/yawn|You yawn sleepily at %s.
YW|/yw|You were happy to help %s.
ATTACKMYTARGET|DoEmote("ATTACKMYTARGET")|You tell everyone to attack %s.
FAIL|DoEmote("FAIL")|You think %s has failed.
FOLLOW|DoEmote("FOLLOW")|You motion for %s to follow.
GOODLUCK|DoEmote("GOODLUCK")|You wish %s good luck.
PUZZLE|DoEmote("PUZZLE")|You are puzzled by %s.
SHOUT|DoEmote("SHOUT")|You shout at %s.
SERIOUS|DoEmote("SERIOUS")|You think %s is serious.
STOPATTACK|DoEmote("STOPATTACK")|You tell %s to stop attacking.
TOAST|DoEmote("TOAST")|You raise a drink to %s. Cheers!]])

SELF_VENDOR_MODES = {
  [Enum.SelfVendorMode.CONSUMABLES_MISSING] = { key = "consumablesmissing", name = "Consumables (Missing Only)", description = "Trades a flask, oil, and five runes only when the target is missing the flask or runes.", command = "consumablesmissing" },
  [Enum.SelfVendorMode.CONSUMABLES_ALL] = { key = "consumables", name = "Consumables", description = "Always trades a flask, oil, and five runes.", command = "consumables" },
  [Enum.SelfVendorMode.CONSUMABLES_PERSISTENT] = { key = "flaskandoil", name = "Flask and Oil", description = "Always trades one flask and one oil.", command = "flaskandoil" },
  [Enum.SelfVendorMode.OIL] = { key = "oil", name = "Oil", description = "Always trades one oil.", command = "oil" },
  [Enum.SelfVendorMode.RUNES] = { key = "runes", name = "Runes", description = "Always trades the selected number of runes as one stack.", command = "runes" },
  [Enum.SelfVendorMode.AUGMENTS] = { key = "augments", name = "Augments", description = "Trades the target's missing recommended enchants, gems, and armor kits.", command = "augments" },
}

ENHANCEMENTS_BIS = {
  icyveins = {
    DEATHKNIGHT = {
      BLOOD = {
        Flask = "Flask of the Blood Knights",
        Gems = {
          Primary = "Powerful Eversong Diamond",
          Secondary = "Flawless Deadly Amethyst",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Rune of Avoidance",
          SHOULDER = "Enchant Shoulders - Amirdrassil's Grace",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Forest Hunter's Armor Kit",
          FEET = "Enchant Boots - Lynx's Dexterity",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
          MAINHAND = "Enchant Weapon - Rite of the Hash'ey",
        },
      },
      FROST = {
        Flask = "Flask of the Magisters",
        Gems = {
          Primary = "Powerful Eversong Diamond",
          Secondary = "Flawless Deadly Amethyst",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Rune of Avoidance",
          SHOULDER = "Enchant Shoulders - Amirdrassil's Grace",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Forest Hunter's Armor Kit",
          FEET = "Enchant Boots - Lynx's Dexterity",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
          MAINHAND = "Enchant Weapon - Rite of the Hash'ey",
        },
      },
      UNHOLY = {
        Flask = "Flask of the Magisters",
        Gems = {
          Primary = "Powerful Eversong Diamond",
          Secondary = "Flawless Deadly Amethyst",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Rune of Avoidance",
          SHOULDER = "Enchant Shoulders - Amirdrassil's Grace",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Forest Hunter's Armor Kit",
          FEET = "Enchant Boots - Lynx's Dexterity",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
          MAINHAND = "Enchant Weapon - Rite of the Hash'ey",
        },
      },
      },
    DRUID = {
      BALANCE = {
        Flask = "Flask of the Blood Knights",
        Gems = {
          Primary = "Powerful Eversong Diamond",
          Secondary = "Flawless Quick Amethyst",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Rune of Avoidance",
          SHOULDER = "Enchant Shoulders - Silvermoon's Mending",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Arcanoweave Spellthread",
          FEET = "Enchant Boots - Shaladrassil's Roots",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
          MAINHAND = "Enchant Weapon - Acuity of the Ren'dorei",
        },
      },
      FERAL = {
        Flask = "Flask of the Magisters",
        Gems = {
          Primary = "Powerful Eversong Diamond",
          Secondary = "Flawless Deadly Amethyst",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Rune of Avoidance",
          SHOULDER = "Enchant Shoulders - Amirdrassil's Grace",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Forest Hunter's Armor Kit",
          FEET = "Enchant Boots - Lynx's Dexterity",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
          MAINHAND = "Enchant Weapon - Rite of the Hash'ey",
        },
      },
      GUARDIAN = {
        Flask = "Flask of the Blood Knights",
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Versatile Peridot",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Blessing of Speed",
          SHOULDER = "Enchant Shoulders - Akil'zon's Swiftness",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Blood Knight's Armor Kit",
          FEET = "Enchant Boots - Farstrider's Hunt",
          FINGER1 = "Enchant Ring - Silvermoon's Alacrity",
          FINGER2 = "Enchant Ring - Silvermoon's Alacrity",
          MAINHAND = "Enchant Weapon - Berserker's Rage",
  
        },
      },
      RESTORATION = {
        Flask = "Flask of the Shattered Sun",
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Versatile Garnet",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Hex of Leeching",
          SHOULDER = "Enchant Shoulders - Silvermoon's Mending",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Sunfire Silk Spellthread",
          FEET = "Enchant Boots - Shaladrassil's Roots",
          FINGER1 = "Enchant Ring - Nature's Fury",
          FINGER2 = "Enchant Ring - Nature's Fury",
          MAINHAND = "Enchant Weapon - Acuity of the Ren'dorei",
  
        },
      },
    },
    DEMONHUNTER = {
      HAVOC = {
        Flask = "Flask of the Magisters",
        Gems = {
          Primary = "Powerful Eversong Diamond",
          Secondary = "Flawless Deadly Amethyst",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Rune of Avoidance",
          SHOULDER = "Enchant Shoulders - Amirdrassil's Grace",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Forest Hunter's Armor Kit",
          FEET = "Enchant Boots - Lynx's Dexterity",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
          MAINHAND = "Enchant Weapon - Rite of the Hash'ey",
        },
      },
      VENGEANCE = {
        Flask = "Flask of the Blood Knights",
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Versatile Peridot",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Blessing of Speed",
          SHOULDER = "Enchant Shoulders - Akil'zon's Swiftness",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Blood Knight's Armor Kit",
          FEET = "Enchant Boots - Farstrider's Hunt",
          FINGER1 = "Enchant Ring - Silvermoon's Alacrity",
          FINGER2 = "Enchant Ring - Silvermoon's Alacrity",
          MAINHAND = "Enchant Weapon - Berserker's Rage",
        },
      },
    },
    EVOKER = {
      DEVASTATION = {
        Flask = "Flask of the Blood Knights",
        Gems = {
          Primary = "Powerful Eversong Diamond",
          Secondary = "Flawless Quick Amethyst",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Rune of Avoidance",
          SHOULDER = "Enchant Shoulders - Silvermoon's Mending",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Arcanoweave Spellthread",
          FEET = "Enchant Boots - Shaladrassil's Roots",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
          MAINHAND = "Enchant Weapon - Acuity of the Ren'dorei",
        },
      },
      AUGMENTATION = {
        Flask = "Flask of the Blood Knights",
        Gems = {
          Primary = "Powerful Eversong Diamond",
          Secondary = "Flawless Quick Amethyst",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Rune of Avoidance",
          SHOULDER = "Enchant Shoulders - Silvermoon's Mending",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Arcanoweave Spellthread",
          FEET = "Enchant Boots - Shaladrassil's Roots",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
          MAINHAND = "Enchant Weapon - Acuity of the Ren'dorei",
        },
      },
      PRESERVATION = {
        Flask = "Flask of the Shattered Sun",
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Versatile Garnet",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Hex of Leeching",
          SHOULDER = "Enchant Shoulders - Silvermoon's Mending",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Sunfire Silk Spellthread",
          FEET = "Enchant Boots - Shaladrassil's Roots",
          FINGER1 = "Enchant Ring - Nature's Fury",
          FINGER2 = "Enchant Ring - Nature's Fury",
          MAINHAND = "Enchant Weapon - Acuity of the Ren'dorei",
        },
      },
    },
    HUNTER = {
      BEAST_MASTERY = {
        Flask = "Flask of the Magisters",
        Gems = {
          Primary = "Powerful Eversong Diamond",
          Secondary = "Flawless Deadly Amethyst",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Rune of Avoidance",
          SHOULDER = "Enchant Shoulders - Amirdrassil's Grace",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Forest Hunter's Armor Kit",
          FEET = "Enchant Boots - Lynx's Dexterity",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
          MAINHAND = "Enchant Weapon - Rite of the Hash'ey",
  
        },
      },
      MARKSMANSHIP = {
        Flask = "Flask of the Magisters",
        Gems = {
          Primary = "Powerful Eversong Diamond",
          Secondary = "Flawless Deadly Amethyst",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Rune of Avoidance",
          SHOULDER = "Enchant Shoulders - Amirdrassil's Grace",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Forest Hunter's Armor Kit",
          FEET = "Enchant Boots - Lynx's Dexterity",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
          MAINHAND = "Enchant Weapon - Rite of the Hash'ey",
        },
      },
      SURVIVAL = {
        Flask = "Flask of the Magisters",
        Gems = {
          Primary = "Powerful Eversong Diamond",
          Secondary = "Flawless Deadly Amethyst",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Rune of Avoidance",
          SHOULDER = "Enchant Shoulders - Amirdrassil's Grace",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Forest Hunter's Armor Kit",
          FEET = "Enchant Boots - Lynx's Dexterity",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
          MAINHAND = "Enchant Weapon - Rite of the Hash'ey",
        },
      },
    },
    MAGE = {
      ARCANE = {
        Flask = "Flask of the Blood Knights",
        Gems = {
          Primary = "Powerful Eversong Diamond",
          Secondary = "Flawless Quick Amethyst",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Rune of Avoidance",
          SHOULDER = "Enchant Shoulders - Silvermoon's Mending",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Arcanoweave Spellthread",
          FEET = "Enchant Boots - Shaladrassil's Roots",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
          MAINHAND = "Enchant Weapon - Acuity of the Ren'dorei",
  
        },
      },
      FIRE = {
        Flask = "Flask of the Blood Knights",
        Gems = {
          Primary = "Powerful Eversong Diamond",
          Secondary = "Flawless Quick Amethyst",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Rune of Avoidance",
          SHOULDER = "Enchant Shoulders - Silvermoon's Mending",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Arcanoweave Spellthread",
          FEET = "Enchant Boots - Shaladrassil's Roots",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
          MAINHAND = "Enchant Weapon - Acuity of the Ren'dorei",
  
        },
      },
      FROST = {
        Flask = "Flask of the Blood Knights",
        Gems = {
          Primary = "Powerful Eversong Diamond",
          Secondary = "Flawless Quick Amethyst",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Rune of Avoidance",
          SHOULDER = "Enchant Shoulders - Silvermoon's Mending",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Arcanoweave Spellthread",
          FEET = "Enchant Boots - Shaladrassil's Roots",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
          MAINHAND = "Enchant Weapon - Acuity of the Ren'dorei",
  
        },
      },
    },
    MONK = {
      BREWMASTER = {
        Flask = "Flask of the Blood Knights",
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Versatile Peridot",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Blessing of Speed",
          SHOULDER = "Enchant Shoulders - Akil'zon's Swiftness",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Blood Knight's Armor Kit",
          FEET = "Enchant Boots - Farstrider's Hunt",
          FINGER1 = "Enchant Ring - Silvermoon's Alacrity",
          FINGER2 = "Enchant Ring - Silvermoon's Alacrity",
          MAINHAND = "Enchant Weapon - Berserker's Rage",
        },
      },
      MISTWEAVER = {
        Flask = "Flask of the Shattered Sun",
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Versatile Garnet",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Hex of Leeching",
          SHOULDER = "Enchant Shoulders - Silvermoon's Mending",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Sunfire Silk Spellthread",
          FEET = "Enchant Boots - Shaladrassil's Roots",
          FINGER1 = "Enchant Ring - Nature's Fury",
          FINGER2 = "Enchant Ring - Nature's Fury",
          MAINHAND = "Enchant Weapon - Acuity of the Ren'dorei",
        },
      },
      WINDWALKER = {
        Flask = "Flask of the Magisters",
        Gems = {
          Primary = "Powerful Eversong Diamond",
          Secondary = "Flawless Deadly Amethyst",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Rune of Avoidance",
          SHOULDER = "Enchant Shoulders - Amirdrassil's Grace",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Forest Hunter's Armor Kit",
          FEET = "Enchant Boots - Lynx's Dexterity",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
          MAINHAND = "Enchant Weapon - Rite of the Hash'ey",
  
        },
      },
    },
    PALADIN = {
      HOLY = {
        Flask = "Flask of the Shattered Sun",
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Versatile Garnet",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Hex of Leeching",
          SHOULDER = "Enchant Shoulders - Silvermoon's Mending",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Sunfire Silk Spellthread",
          FEET = "Enchant Boots - Shaladrassil's Roots",
          FINGER1 = "Enchant Ring - Nature's Fury",
          FINGER2 = "Enchant Ring - Nature's Fury",
          MAINHAND = "Enchant Weapon - Acuity of the Ren'dorei",
  
        },
      },
      PROTECTION = {
        Flask = "Flask of the Blood Knights",
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Versatile Peridot",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Blessing of Speed",
          SHOULDER = "Enchant Shoulders - Akil'zon's Swiftness",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Blood Knight's Armor Kit",
          FEET = "Enchant Boots - Farstrider's Hunt",
          FINGER1 = "Enchant Ring - Silvermoon's Alacrity",
          FINGER2 = "Enchant Ring - Silvermoon's Alacrity",
          MAINHAND = "Enchant Weapon - Berserker's Rage",
  
        },
      },
      RETRIBUTION = {
        Flask = "Flask of the Magisters",
        Gems = {
          Primary = "Powerful Eversong Diamond",
          Secondary = "Flawless Deadly Amethyst",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Rune of Avoidance",
          SHOULDER = "Enchant Shoulders - Amirdrassil's Grace",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Forest Hunter's Armor Kit",
          FEET = "Enchant Boots - Lynx's Dexterity",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
          MAINHAND = "Enchant Weapon - Rite of the Hash'ey",
  
        },
      },
    },
    PRIEST = {
      DISCIPLINE = {
        Flask = "Flask of the Shattered Sun",
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Versatile Garnet",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Hex of Leeching",
          SHOULDER = "Enchant Shoulders - Silvermoon's Mending",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Sunfire Silk Spellthread",
          FEET = "Enchant Boots - Shaladrassil's Roots",
          FINGER1 = "Enchant Ring - Nature's Fury",
          FINGER2 = "Enchant Ring - Nature's Fury",
          MAINHAND = "Enchant Weapon - Acuity of the Ren'dorei",
        },
      },
      HOLY = {
        Flask = "Flask of the Shattered Sun",
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Versatile Garnet",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Hex of Leeching",
          SHOULDER = "Enchant Shoulders - Silvermoon's Mending",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Sunfire Silk Spellthread",
          FEET = "Enchant Boots - Shaladrassil's Roots",
          FINGER1 = "Enchant Ring - Nature's Fury",
          FINGER2 = "Enchant Ring - Nature's Fury",
          MAINHAND = "Enchant Weapon - Acuity of the Ren'dorei",
        },
      },
      SHADOW = {
        Flask = "Flask of the Blood Knights",
        Gems = {
          Primary = "Powerful Eversong Diamond",
          Secondary = "Flawless Quick Amethyst",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Rune of Avoidance",
          SHOULDER = "Enchant Shoulders - Silvermoon's Mending",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Arcanoweave Spellthread",
          FEET = "Enchant Boots - Shaladrassil's Roots",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
          MAINHAND = "Enchant Weapon - Acuity of the Ren'dorei",
  
        },
      },
    },
    ROGUE = {
      ASSASSINATION = {
        Flask = "Flask of the Magisters",
        Gems = {
          Primary = "Powerful Eversong Diamond",
          Secondary = "Flawless Deadly Amethyst",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Rune of Avoidance",
          SHOULDER = "Enchant Shoulders - Amirdrassil's Grace",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Forest Hunter's Armor Kit",
          FEET = "Enchant Boots - Lynx's Dexterity",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
          MAINHAND = "Enchant Weapon - Rite of the Hash'ey",
        },
      },
      OUTLAW = {
        Flask = "Flask of the Magisters",
        Gems = {
          Primary = "Powerful Eversong Diamond",
          Secondary = "Flawless Deadly Amethyst",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Rune of Avoidance",
          SHOULDER = "Enchant Shoulders - Amirdrassil's Grace",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Forest Hunter's Armor Kit",
          FEET = "Enchant Boots - Lynx's Dexterity",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
          MAINHAND = "Enchant Weapon - Rite of the Hash'ey",
        },
      },
      SUBTLETY = {
        Flask = "Flask of the Magisters",
        Gems = {
          Primary = "Powerful Eversong Diamond",
          Secondary = "Flawless Deadly Amethyst",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Rune of Avoidance",
          SHOULDER = "Enchant Shoulders - Amirdrassil's Grace",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Forest Hunter's Armor Kit",
          FEET = "Enchant Boots - Lynx's Dexterity",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
          MAINHAND = "Enchant Weapon - Rite of the Hash'ey",
  
        },
      },
    },
    SHAMAN = {
      ELEMENTAL = {
        Flask = "Flask of the Blood Knights",
        Gems = {
          Primary = "Powerful Eversong Diamond",
          Secondary = "Flawless Quick Amethyst",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Rune of Avoidance",
          SHOULDER = "Enchant Shoulders - Silvermoon's Mending",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Arcanoweave Spellthread",
          FEET = "Enchant Boots - Shaladrassil's Roots",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
          MAINHAND = "Enchant Weapon - Acuity of the Ren'dorei",
        },
      },
      ENHANCEMENT = {
        Flask = "Flask of the Magisters",
        Gems = {
          Primary = "Powerful Eversong Diamond",
          Secondary = "Flawless Deadly Amethyst",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Rune of Avoidance",
          SHOULDER = "Enchant Shoulders - Amirdrassil's Grace",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Forest Hunter's Armor Kit",
          FEET = "Enchant Boots - Lynx's Dexterity",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
          MAINHAND = "Enchant Weapon - Rite of the Hash'ey",
        },
      },
      RESTORATION = {
        Flask = "Flask of the Shattered Sun",
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Versatile Garnet",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Hex of Leeching",
          SHOULDER = "Enchant Shoulders - Silvermoon's Mending",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Sunfire Silk Spellthread",
          FEET = "Enchant Boots - Shaladrassil's Roots",
          FINGER1 = "Enchant Ring - Nature's Fury",
          FINGER2 = "Enchant Ring - Nature's Fury",
          MAINHAND = "Enchant Weapon - Acuity of the Ren'dorei",
  
        },
      },
    },
    WARLOCK = {
      AFFLICTION = {
        Flask = "Flask of the Blood Knights",
        Gems = {
          Primary = "Powerful Eversong Diamond",
          Secondary = "Flawless Quick Amethyst",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Rune of Avoidance",
          SHOULDER = "Enchant Shoulders - Silvermoon's Mending",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Arcanoweave Spellthread",
          FEET = "Enchant Boots - Shaladrassil's Roots",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
          MAINHAND = "Enchant Weapon - Acuity of the Ren'dorei",
        },
      },
      DEMONOLOGY = {
        Flask = "Flask of the Blood Knights",
        Gems = {
          Primary = "Powerful Eversong Diamond",
          Secondary = "Flawless Quick Amethyst",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Rune of Avoidance",
          SHOULDER = "Enchant Shoulders - Silvermoon's Mending",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Arcanoweave Spellthread",
          FEET = "Enchant Boots - Shaladrassil's Roots",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
          MAINHAND = "Enchant Weapon - Acuity of the Ren'dorei",
        },
      },
      DESTRUCTION = {
        Flask = "Flask of the Blood Knights",
        Gems = {
          Primary = "Powerful Eversong Diamond",
          Secondary = "Flawless Quick Amethyst",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Rune of Avoidance",
          SHOULDER = "Enchant Shoulders - Silvermoon's Mending",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Arcanoweave Spellthread",
          FEET = "Enchant Boots - Shaladrassil's Roots",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
          MAINHAND = "Enchant Weapon - Acuity of the Ren'dorei",
  
        },
      },
    },
    WARRIOR = {
      ARMS = {
        Flask = "Flask of the Magisters",
        Gems = {
          Primary = "Powerful Eversong Diamond",
          Secondary = "Flawless Deadly Amethyst",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Rune of Avoidance",
          SHOULDER = "Enchant Shoulders - Amirdrassil's Grace",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Forest Hunter's Armor Kit",
          FEET = "Enchant Boots - Lynx's Dexterity",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
          MAINHAND = "Enchant Weapon - Rite of the Hash'ey",
        },
      },
      FURY = {
        Flask = "Flask of the Magisters",
        Gems = {
          Primary = "Powerful Eversong Diamond",
          Secondary = "Flawless Deadly Amethyst",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Rune of Avoidance",
          SHOULDER = "Enchant Shoulders - Amirdrassil's Grace",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Forest Hunter's Armor Kit",
          FEET = "Enchant Boots - Lynx's Dexterity",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
          MAINHAND = "Enchant Weapon - Rite of the Hash'ey",
  
        },
      },
      PROTECTION = {
        Flask = "Flask of the Blood Knights",
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Versatile Peridot",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Blessing of Speed",
          SHOULDER = "Enchant Shoulders - Akil'zon's Swiftness",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Blood Knight's Armor Kit",
          FEET = "Enchant Boots - Farstrider's Hunt",
          FINGER1 = "Enchant Ring - Silvermoon's Alacrity",
          FINGER2 = "Enchant Ring - Silvermoon's Alacrity",
          MAINHAND = "Enchant Weapon - Berserker's Rage",
        },
      },
      },
    },
  wowhead = {
    DEATHKNIGHT = {
      BLOOD = {
        Flask = "Flask of the Blood Knights",
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Deadly Peridot",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Blessing of Speed",
          SHOULDER = "Enchant Shoulders - Akil'zon's Swiftness",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Forest Hunter's Armor Kit",
          FEET = "Enchant Boots - Farstrider's Hunt",
          FINGER1 = "Enchant Ring - Nature's Fury",
          FINGER2 = "Enchant Ring - Nature's Fury",
        },
      },
      FROST = {
        Flask = "Flask of the Magisters",
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Masterful Garnet",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Blessing of Speed",
          SHOULDER = "Enchant Shoulders - Akil'zon's Swiftness",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Forest Hunter's Armor Kit",
          FEET = "Enchant Boots - Farstrider's Hunt",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
        },
      },
      UNHOLY = {
        Flask = "Flask of the Magisters",
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Masterful Garnet",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Blessing of Speed",
          SHOULDER = "Enchant Shoulders - Akil'zon's Swiftness",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Forest Hunter's Armor Kit",
          FEET = "Enchant Boots - Farstrider's Hunt",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
        },
      },
    },
    DRUID = {
      BALANCE = {
        Flask = "Flask of the Magisters",
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Quick Amethyst",
        },
        Enchants = {
          MAINHAND = "Enchant Weapon - Rite of the Hash'ey",
          HEAD = "Enchant Helm - Empowered Rune of Avoidance",
          SHOULDER = "Enchant Shoulders - Amirdrassil's Grace",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Sunfire Silk Spellthread",
          FEET = "Enchant Boots - Lynx's Dexterity",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
        },
      },
      FERAL = {
        Flask = "Flask of the Shattered Sun",
        Gems = {
          Primary = "Powerful Eversong Diamond",
          Secondary = "Flawless Quick Amethyst",
        },
        Enchants = {
          MAINHAND = "Enchant Weapon - Acuity of the Ren'dorei",
          HEAD = "Enchant Helm - Empowered Rune of Avoidance",
          SHOULDER = "Enchant Shoulders - Amirdrassil's Grace",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Forest Hunter's Armor Kit",
          FEET = "Enchant Boots - Lynx's Dexterity",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
        },
      },
      GUARDIAN = {
        Flask = "Flask of the Blood Knights",
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Versatile Peridot",
        },
        Enchants = {
          MAINHAND = "Enchant Weapon - Berserker's Rage",
          HEAD = "Enchant Helm - Empowered Blessing of Speed",
          SHOULDER = "Enchant Shoulders - Akil'zon's Swiftness",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Forest Hunter's Armor Kit",
          FEET = "Enchant Boots - Farstrider's Hunt",
          FINGER1 = "Enchant Ring - Silvermoon's Alacrity",
          FINGER2 = "Enchant Ring - Silvermoon's Alacrity",
        },
      },
      RESTORATION = {
        Flask = "Flask of the Blood Knights",
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Masterful Peridot",
        },
        Enchants = {
          MAINHAND = "Enchant Weapon - Berserker's Rage",
          HEAD = "Enchant Helm - Empowered Hex of Leeching",
          SHOULDER = "Enchant Shoulders - Silvermoon's Mending",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Arcanoweave Spellthread",
          FEET = "Enchant Boots - Shaladrassil's Roots",
          FINGER1 = "Enchant Ring - Silvermoon's Alacrity",
          FINGER2 = "Enchant Ring - Silvermoon's Alacrity",
        },
      },
    },
    DEMONHUNTER = {
      HAVOC = {
        Flask = "Flask of the Shattered Sun",
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Masterful Garnet",
        },
        Enchants = {
          MAINHAND = "Enchant Weapon - Rite of the Hash'ey",
          HEAD = "Enchant Helm - Empowered Rune of Avoidance",
          SHOULDER = "Enchant Shoulders - Amirdrassil's Grace",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Forest Hunter's Armor Kit",
          FEET = "Enchant Boots - Lynx's Dexterity",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
        },
      },
      VENGEANCE = {
        Flask = "Flask of the Blood Knights",
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Deadly Peridot",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Blessing of Speed",
          SHOULDER = "Enchant Shoulders - Akil'zon's Swiftness",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Forest Hunter's Armor Kit",
          FEET = "Enchant Boots - Farstrider's Hunt",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
        },
      },
    },
    EVOKER = {
      DEVASTATION = {
        Flask = "Flask of the Shattered Sun",
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Quick Garnet",
        },
        Enchants = {
          MAINHAND = "Enchant Weapon - Acuity of the Ren'dorei",
          HEAD = "Enchant Helm - Empowered Rune of Avoidance",
          SHOULDER = "Enchant Shoulders - Amirdrassil's Grace",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Sunfire Silk Spellthread",
          FEET = "Enchant Boots - Lynx's Dexterity",
          FINGER1 = "Enchant Ring - Nature's Fury",
          FINGER2 = "Enchant Ring - Nature's Fury",
        },
      },
      AUGMENTATION = {
        Flask = "Flask of the Magisters",
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Deadly Amethyst",
        },
        Enchants = {
          MAINHAND = "Enchant Weapon - Arcane Mastery",
          HEAD = "Enchant Helm - Empowered Rune of Avoidance",
          SHOULDER = "Enchant Shoulders - Amirdrassil's Grace",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Sunfire Silk Spellthread",
          FEET = "Enchant Boots - Lynx's Dexterity",
          FINGER1 = "Enchant Ring - Zul'jin's Mastery",
          FINGER2 = "Enchant Ring - Zul'jin's Mastery",
        },
      },
      PRESERVATION = {
        Flask = "Flask of the Magisters",
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Quick Amethyst",
        },
        Enchants = {
          MAINHAND = "Enchant Weapon - Arcane Mastery",
          HEAD = "Enchant Helm - Empowered Hex of Leeching",
          SHOULDER = "Enchant Shoulders - Silvermoon's Mending",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Arcanoweave Spellthread",
          FEET = "Enchant Boots - Shaladrassil's Roots",
          FINGER1 = "Enchant Ring - Zul'jin's Mastery",
          FINGER2 = "Enchant Ring - Zul'jin's Mastery",
        },
      },
    },
    HUNTER = {
      BEAST_MASTERY = {
        Flask = "Flask of the Magisters",
        Gems = {
          Primary = "Powerful Eversong Diamond",
          Secondary = "Flawless Deadly Amethyst",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Rune of Avoidance",
          SHOULDER = "Enchant Shoulders - Amirdrassil's Grace",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Forest Hunter's Armor Kit",
          FEET = "Enchant Boots - Lynx's Dexterity",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
          MAINHAND = "Enchant Weapon - Rite of the Hash'ey",
        },
      },
      MARKSMANSHIP = {
        Flask = "Flask of the Shattered Sun",
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Masterful Garnet",
        },
        Enchants = {
          MAINHAND = "Enchant Weapon - Rite of the Hash'ey",
          HEAD = "Enchant Helm - Empowered Hex of Leeching",
          SHOULDER = "Enchant Shoulders - Silvermoon's Mending",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Forest Hunter's Armor Kit",
          FEET = "Enchant Boots - Shaladrassil's Roots",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
        },
      },
      SURVIVAL = {
        Flask = "Flask of the Magisters",
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Deadly Amethyst",
        },
        Enchants = {
          MAINHAND = "Enchant Weapon - Rite of the Hash'ey",
          HEAD = "Enchant Helm - Empowered Rune of Avoidance",
          SHOULDER = "Enchant Shoulders - Amirdrassil's Grace",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Forest Hunter's Armor Kit",
          FEET = "Enchant Boots - Lynx's Dexterity",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
        },
      },
    },
    MAGE = {
      ARCANE = {
        Flask = "Flask of the Blood Knights",
        Gems = {
          Primary = "Powerful Eversong Diamond",
          Secondary = "Flawless Quick Amethyst",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Rune of Avoidance",
          SHOULDER = "Enchant Shoulders - Silvermoon's Mending",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Arcanoweave Spellthread",
          FEET = "Enchant Boots - Shaladrassil's Roots",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
          MAINHAND = "Enchant Weapon - Acuity of the Ren'dorei",
        },
      },
      FIRE = {
        Flask = "Flask of the Magisters",
        Gems = {
          Primary = "Powerful Eversong Diamond",
          Secondary = "Flawless Masterful Peridot",
        },
        Enchants = {
          MAINHAND = "Enchant Weapon - Acuity of the Ren'dorei",
          HEAD = "Enchant Helm - Empowered Rune of Avoidance",
          SHOULDER = "Enchant Shoulders - Amirdrassil's Grace",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Sunfire Silk Spellthread",
          FEET = "Enchant Boots - Lynx's Dexterity",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
        },
      },
      FROST = {
        Flask = "Flask of the Magisters",
        Gems = {
          Primary = "Powerful Eversong Diamond",
          Secondary = "Flawless Deadly Amethyst",
        },
        Enchants = {
          MAINHAND = "Enchant Weapon - Acuity of the Ren'dorei",
          HEAD = "Enchant Helm - Empowered Rune of Avoidance",
          SHOULDER = "Enchant Shoulders - Amirdrassil's Grace",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Sunfire Silk Spellthread",
          FEET = "Enchant Boots - Lynx's Dexterity",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
        },
      },
    },
    MONK = {
      BREWMASTER = {
        Flask = "Flask of Thalassian Resistance",
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Deadly Lapis",
        },
        Enchants = {
          MAINHAND = "Enchant Weapon - Acuity of the Ren'dorei",
          HEAD = "Enchant Helm - Empowered Hex of Leeching",
          SHOULDER = "Enchant Shoulders - Silvermoon's Mending",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Forest Hunter's Armor Kit",
          FEET = "Enchant Boots - Shaladrassil's Roots",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
        },
      },
      MISTWEAVER = {
        Flask = "Flask of the Blood Knights",
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Deadly Peridot",
        },
        Enchants = {
          MAINHAND = "Enchant Weapon - Acuity of the Ren'dorei",
          HEAD = "Enchant Helm - Empowered Hex of Leeching",
          SHOULDER = "Enchant Shoulders - Silvermoon's Mending",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Sunfire Silk Spellthread",
          FEET = "Enchant Boots - Shaladrassil's Roots",
          FINGER1 = "Enchant Ring - Silvermoon's Alacrity",
          FINGER2 = "Enchant Ring - Silvermoon's Alacrity",
        },
      },
      WINDWALKER = {
        Flask = "Flask of the Blood Knights",
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Deadly Peridot",
        },
        Enchants = {
          MAINHAND = "Enchant Weapon - Rite of the Hash'ey",
          HEAD = "Enchant Helm - Empowered Rune of Avoidance",
          SHOULDER = "Enchant Shoulders - Amirdrassil's Grace",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Forest Hunter's Armor Kit",
          FEET = "Enchant Boots - Lynx's Dexterity",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
        },
      },
    },
    PALADIN = {
      HOLY = {
        Flask = "Flask of the Magisters",
        Gems = {
          Primary = "Telluric Eversong Diamond",
          Secondary = "Flawless Quick Amethyst",
        },
        Enchants = {
          MAINHAND = "Enchant Weapon - Rite of the Hash'ey",
          HEAD = "Enchant Helm - Empowered Hex of Leeching",
          SHOULDER = "Enchant Shoulders - Silvermoon's Mending",
          CHEST = "Enchant Chest - Mark of the Magister",
          LEGS = "Arcanoweave Spellthread",
          FEET = "Enchant Boots - Shaladrassil's Roots",
          FINGER1 = "Enchant Ring - Zul'jin's Mastery",
          FINGER2 = "Enchant Ring - Zul'jin's Mastery",
        },
      },
      PROTECTION = {
        Flask = "Flask of the Blood Knights",
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Versatile Peridot",
        },
        Enchants = {
          MAINHAND = "Enchant Weapon - Berserker's Rage",
          HEAD = "Enchant Helm - Empowered Blessing of Speed",
          SHOULDER = "Enchant Shoulders - Akil'zon's Swiftness",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Forest Hunter's Armor Kit",
          FEET = "Enchant Boots - Farstrider's Hunt",
          FINGER1 = "Enchant Ring - Silvermoon's Alacrity",
          FINGER2 = "Enchant Ring - Silvermoon's Alacrity",
        },
      },
      RETRIBUTION = {
        Flask = "Flask of the Magisters",
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Masterful Peridot",
        },
        Enchants = {
          MAINHAND = "Enchant Weapon - Rite of the Hash'ey",
          HEAD = "Enchant Helm - Empowered Rune of Avoidance",
          SHOULDER = "Enchant Shoulders - Amirdrassil's Grace",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Forest Hunter's Armor Kit",
          FEET = "Enchant Boots - Lynx's Dexterity",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
        },
      },
    },
    PRIEST = {
      DISCIPLINE = {
        Flask = "Flask of the Blood Knights",
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Deadly Peridot",
        },
        Enchants = {
          MAINHAND = "Enchant Weapon - Berserker's Rage",
          HEAD = "Enchant Helm - Empowered Hex of Leeching",
          SHOULDER = "Enchant Shoulders - Silvermoon's Mending",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Sunfire Silk Spellthread",
          FEET = "Enchant Boots - Shaladrassil's Roots",
          FINGER1 = "Enchant Ring - Silvermoon's Alacrity",
          FINGER2 = "Enchant Ring - Silvermoon's Alacrity",
        },
      },
      HOLY = {
        Flask = "Flask of the Shattered Sun",
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Versatile Garnet",
        },
        Enchants = {
          MAINHAND = "Enchant Weapon - Acuity of the Ren'dorei",
          HEAD = "Enchant Helm - Empowered Hex of Leeching",
          SHOULDER = "Enchant Shoulders - Silvermoon's Mending",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Sunfire Silk Spellthread",
          FEET = "Enchant Boots - Shaladrassil's Roots",
          FINGER1 = "Enchant Ring - Nature's Fury",
          FINGER2 = "Enchant Ring - Nature's Fury",
        },
      },
      SHADOW = {
        Flask = "Flask of the Magisters",
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Quick Garnet",
        },
        Enchants = {
          MAINHAND = "Enchant Weapon - Arcane Mastery",
          HEAD = "Enchant Helm - Empowered Rune of Avoidance",
          SHOULDER = "Enchant Shoulders - Akil'zon's Swiftness",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Sunfire Silk Spellthread",
          FEET = "Enchant Boots - Lynx's Dexterity",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
        },
      },
    },
    ROGUE = {
      ASSASSINATION = {
        Flask = "Flask of the Blood Knights",
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Masterful Peridot",
        },
        Enchants = {
          MAINHAND = "Enchant Weapon - Rite of the Hash'ey",
          HEAD = "Enchant Helm - Empowered Hex of Leeching",
          SHOULDER = "Enchant Shoulders - Silvermoon's Mending",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Forest Hunter's Armor Kit",
          FEET = "Enchant Boots - Shaladrassil's Roots",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
        },
      },
      OUTLAW = {
        Flask = "Flask of the Shattered Sun",
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Deadly Peridot",
        },
        Enchants = {
          MAINHAND = "Enchant Weapon - Acuity of the Ren'dorei",
          HEAD = "Enchant Helm - Empowered Hex of Leeching",
          SHOULDER = "Enchant Shoulders - Silvermoon's Mending",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Forest Hunter's Armor Kit",
          FEET = "Enchant Boots - Shaladrassil's Roots",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
        },
      },
      SUBTLETY = {
        Flask = "Flask of the Magisters",
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Quick Amethyst",
        },
        Enchants = {
          MAINHAND = "Enchant Weapon - Rite of the Hash'ey",
          HEAD = "Enchant Helm - Empowered Rune of Avoidance",
          SHOULDER = "Enchant Shoulders - Amirdrassil's Grace",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Forest Hunter's Armor Kit",
          FEET = "Enchant Boots - Lynx's Dexterity",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
        },
      },
    },
    SHAMAN = {
      ELEMENTAL = {
        Flask = "Flask of the Magisters",
        Gems = {
          Primary = "Powerful Eversong Diamond",
          Secondary = "Flawless Masterful Garnet",
        },
        Enchants = {
          MAINHAND = "Enchant Weapon - Berserker's Rage",
          HEAD = "Enchant Helm - Empowered Rune of Avoidance",
          SHOULDER = "Enchant Shoulders - Amirdrassil's Grace",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Sunfire Silk Spellthread",
          FEET = "Enchant Boots - Lynx's Dexterity",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
        },
      },
      ENHANCEMENT = {
        Flask = "Flask of the Magisters",
        Gems = {
          Primary = "Powerful Eversong Diamond",
          Secondary = "Flawless Deadly Amethyst",
        },
        Enchants = {
          MAINHAND = "Enchant Weapon - Rite of the Hash'ey",
          OFFHAND = "Enchant Weapon - Rite of the Hash'ey",
          HEAD = "Enchant Helm - Empowered Rune of Avoidance",
          SHOULDER = "Enchant Shoulders - Amirdrassil's Grace",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Forest Hunter's Armor Kit",
          FEET = "Enchant Boots - Lynx's Dexterity",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
        },
      },
      RESTORATION = {
        Flask = "Flask of the Shattered Sun",
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Versatile Garnet",
        },
        Enchants = {
          MAINHAND = "Enchant Weapon - Acuity of the Ren'dorei",
          HEAD = "Enchant Helm - Empowered Hex of Leeching",
          SHOULDER = "Enchant Shoulders - Silvermoon's Mending",
          CHEST = "Enchant Chest - Mark of the Magister",
          LEGS = "Arcanoweave Spellthread",
          FEET = "Enchant Boots - Shaladrassil's Roots",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
        },
      },
    },
    WARLOCK = {
      AFFLICTION = {
        Flask = "Flask of the Blood Knights",
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Quick Garnet",
        },
        Enchants = {
          MAINHAND = "Enchant Weapon - Jan'alai's Precision",
          HEAD = "Enchant Helm - Empowered Rune of Avoidance",
          SHOULDER = "Enchant Shoulders - Flight of the Eagle",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Sunfire Silk Spellthread",
          FEET = "Enchant Boots - Lynx's Dexterity",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
        },
      },
      DEMONOLOGY = {
        Flask = "Flask of the Shattered Sun",
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Quick Garnet",
        },
        Enchants = {
          MAINHAND = "Enchant Weapon - Jan'alai's Precision",
          HEAD = "Enchant Helm - Empowered Rune of Avoidance",
          SHOULDER = "Enchant Shoulders - Flight of the Eagle",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Sunfire Silk Spellthread",
          FEET = "Enchant Boots - Lynx's Dexterity",
          FINGER1 = "Enchant Ring - Silvermoon's Alacrity",
          FINGER2 = "Enchant Ring - Silvermoon's Alacrity",
        },
      },
      DESTRUCTION = {
        Flask = "Flask of the Shattered Sun",
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Quick Garnet",
        },
        Enchants = {
          MAINHAND = "Enchant Weapon - Acuity of the Ren'dorei",
          HEAD = "Enchant Helm - Empowered Rune of Avoidance",
          SHOULDER = "Enchant Shoulders - Amirdrassil's Grace",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Sunfire Silk Spellthread",
          FEET = "Enchant Boots - Lynx's Dexterity",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
        },
      },
    },
    WARRIOR = {
      ARMS = {
        Flask = "Flask of the Blood Knights",
        Gems = {
          Primary = "Powerful Eversong Diamond",
          Secondary = "Flawless Quick Garnet",
        },
        Enchants = {
          MAINHAND = "Enchant Weapon - Rite of the Hash'ey",
          HEAD = "Enchant Helm - Empowered Hex of Leeching",
          SHOULDER = "Enchant Shoulders - Amirdrassil's Grace",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Blood Knight's Armor Kit",
          FEET = "Enchant Boots - Lynx's Dexterity",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
        },
      },
      FURY = {
        Flask = "Flask of the Blood Knights",
        Gems = {
          Primary = "Powerful Eversong Diamond",
          Secondary = "Flawless Quick Amethyst",
        },
        Enchants = {
          MAINHAND = "Enchant Weapon - Rite of the Hash'ey",
          HEAD = "Enchant Helm - Empowered Hex of Leeching",
          SHOULDER = "Enchant Shoulders - Amirdrassil's Grace",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Blood Knight's Armor Kit",
          FEET = "Enchant Boots - Lynx's Dexterity",
          FINGER1 = "Enchant Ring - Zul'jin's Mastery",
          FINGER2 = "Enchant Ring - Zul'jin's Mastery",
        },
      },
      PROTECTION = {
        Flask = "Flask of the Blood Knights",
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Versatile Peridot",
        },
        Enchants = {
          MAINHAND = "Enchant Weapon - Berserker's Rage",
          HEAD = "Enchant Helm - Empowered Blessing of Speed",
          SHOULDER = "Enchant Shoulders - Akil'zon's Swiftness",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Forest Hunter's Armor Kit",
          FEET = "Enchant Boots - Farstrider's Hunt",
          FINGER1 = "Enchant Ring - Silvermoon's Alacrity",
          FINGER2 = "Enchant Ring - Silvermoon's Alacrity",
        },
      },
    },
  },
  murlok = {
    DEATHKNIGHT = {
      BLOOD = {
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Deadly Peridot",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Blessing of Speed",
          SHOULDER = "Enchant Shoulders - Silvermoon's Mending",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Forest Hunter's Armor Kit",
          FEET = "Enchant Boots - Farstrider's Hunt",
          FINGER1 = "Enchant Ring - Silvermoon's Tenacity",
          FINGER2 = "Enchant Ring - Silvermoon's Tenacity",
        },
      },
      FROST = {
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Masterful Garnet",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Blessing of Speed",
          SHOULDER = "Enchant Shoulders - Amirdrassil's Grace",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Forest Hunter's Armor Kit",
          FEET = "Enchant Boots - Farstrider's Hunt",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
        },
      },
      UNHOLY = {
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Masterful Garnet",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Rune of Avoidance",
          SHOULDER = "Enchant Shoulders - Amirdrassil's Grace",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Forest Hunter's Armor Kit",
          FEET = "Enchant Boots - Lynx's Dexterity",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
        },
      },
    },
    DEMONHUNTER = {
      HAVOC = {
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Masterful Garnet",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Rune of Avoidance",
          SHOULDER = "Enchant Shoulders - Amirdrassil's Grace",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Forest Hunter's Armor Kit",
          FEET = "Enchant Boots - Lynx's Dexterity",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
          MAINHAND = "Enchant Weapon - Jan'alai's Precision",
          OFFHAND = "Enchant Weapon - Jan'alai's Precision",
        },
      },
      VENGEANCE = {
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Deadly Peridot",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Hex of Leeching",
          SHOULDER = "Enchant Shoulders - Silvermoon's Mending",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Forest Hunter's Armor Kit",
          FEET = "Enchant Boots - Shaladrassil's Roots",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
          MAINHAND = "Enchant Weapon - Acuity of the Ren'dorei",
          OFFHAND = "Enchant Weapon - Acuity of the Ren'dorei",
        },
      },
    },
    DRUID = {
      BALANCE = {
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Quick Amethyst",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Rune of Avoidance",
          SHOULDER = "Enchant Shoulders - Amirdrassil's Grace",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Sunfire Silk Spellthread",
          FEET = "Enchant Boots - Lynx's Dexterity",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
          MAINHAND = "Enchant Weapon - Acuity of the Ren'dorei",
        },
      },
      FERAL = {
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Quick Amethyst",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Rune of Avoidance",
          SHOULDER = "Enchant Shoulders - Amirdrassil's Grace",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Forest Hunter's Armor Kit",
          FEET = "Enchant Boots - Lynx's Dexterity",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
          MAINHAND = "Enchant Weapon - Acuity of the Ren'dorei",
        },
      },
      GUARDIAN = {
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Versatile Peridot",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Hex of Leeching",
          SHOULDER = "Enchant Shoulders - Silvermoon's Mending",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Forest Hunter's Armor Kit",
          FEET = "Enchant Boots - Shaladrassil's Roots",
          FINGER1 = "Enchant Ring - Silvermoon's Alacrity",
          FINGER2 = "Enchant Ring - Silvermoon's Alacrity",
          MAINHAND = "Enchant Weapon - Acuity of the Ren'dorei",
        },
      },
      RESTORATION = {
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Masterful Peridot",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Hex of Leeching",
          SHOULDER = "Enchant Shoulders - Silvermoon's Mending",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Arcanoweave Spellthread",
          FEET = "Enchant Boots - Shaladrassil's Roots",
          FINGER1 = "Enchant Ring - Silvermoon's Alacrity",
          FINGER2 = "Enchant Ring - Silvermoon's Alacrity",
          MAINHAND = "Enchant Weapon - Acuity of the Ren'dorei",
        },
      },
    },
    EVOKER = {
      DEVASTATION = {
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Quick Garnet",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Rune of Avoidance",
          SHOULDER = "Enchant Shoulders - Amirdrassil's Grace",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Sunfire Silk Spellthread",
          FEET = "Enchant Boots - Lynx's Dexterity",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
          MAINHAND = "Enchant Weapon - Acuity of the Ren'dorei",
        },
      },
      AUGMENTATION = {
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Deadly Amethyst",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Rune of Avoidance",
          SHOULDER = "Enchant Shoulders - Amirdrassil's Grace",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Sunfire Silk Spellthread",
          FEET = "Enchant Boots - Lynx's Dexterity",
          FINGER1 = "Enchant Ring - Zul'jin's Mastery",
          FINGER2 = "Enchant Ring - Zul'jin's Mastery",
          MAINHAND = "Enchant Weapon - Acuity of the Ren'dorei",
        },
      },
      PRESERVATION = {
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Deadly Amethyst",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Hex of Leeching",
          SHOULDER = "Enchant Shoulders - Silvermoon's Mending",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Arcanoweave Spellthread",
          FEET = "Enchant Boots - Shaladrassil's Roots",
          FINGER1 = "Enchant Ring - Zul'jin's Mastery",
          FINGER2 = "Enchant Ring - Zul'jin's Mastery",
          MAINHAND = "Enchant Weapon - Acuity of the Ren'dorei",
        },
      },
    },
    HUNTER = {
      BEAST_MASTERY = {
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Deadly Amethyst",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Rune of Avoidance",
          SHOULDER = "Enchant Shoulders - Amirdrassil's Grace",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Forest Hunter's Armor Kit",
          FEET = "Enchant Boots - Lynx's Dexterity",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
          MAINHAND = "Enchant Weapon - Rite of the Hash'ey",
        },
      },
      MARKSMANSHIP = {
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Masterful Garnet",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Rune of Avoidance",
          SHOULDER = "Enchant Shoulders - Amirdrassil's Grace",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Forest Hunter's Armor Kit",
          FEET = "Enchant Boots - Lynx's Dexterity",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
          MAINHAND = "Enchant Weapon - Jan'alai's Precision",
        },
      },
      SURVIVAL = {
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Deadly Amethyst",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Rune of Avoidance",
          SHOULDER = "Enchant Shoulders - Amirdrassil's Grace",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Forest Hunter's Armor Kit",
          FEET = "Enchant Boots - Lynx's Dexterity",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
          MAINHAND = "Enchant Weapon - Arcane Mastery",
          OFFHAND = "Enchant Weapon - Arcane Mastery",
        },
      },
    },
    MAGE = {
      ARCANE = {
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Versatile Peridot",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Rune of Avoidance",
          SHOULDER = "Enchant Shoulders - Amirdrassil's Grace",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Sunfire Silk Spellthread",
          FEET = "Enchant Boots - Lynx's Dexterity",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
          MAINHAND = "Enchant Weapon - Acuity of the Ren'dorei",
        },
      },
      FIRE = {
        Gems = {
          Primary = "Powerful Eversong Diamond",
          Secondary = "Flawless Masterful Peridot",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Rune of Avoidance",
          SHOULDER = "Enchant Shoulders - Amirdrassil's Grace",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Sunfire Silk Spellthread",
          FEET = "Enchant Boots - Lynx's Dexterity",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
          MAINHAND = "Enchant Weapon - Acuity of the Ren'dorei",
        },
      },
      FROST = {
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Masterful Garnet",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Rune of Avoidance",
          SHOULDER = "Enchant Shoulders - Amirdrassil's Grace",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Sunfire Silk Spellthread",
          FEET = "Enchant Boots - Lynx's Dexterity",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
          MAINHAND = "Enchant Weapon - Acuity of the Ren'dorei",
        },
      },
    },
    MONK = {
      BREWMASTER = {
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Versatile Garnet",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Hex of Leeching",
          SHOULDER = "Enchant Shoulders - Silvermoon's Mending",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Forest Hunter's Armor Kit",
          FEET = "Enchant Boots - Shaladrassil's Roots",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
          MAINHAND = "Enchant Weapon - Acuity of the Ren'dorei",
        },
      },
      MISTWEAVER = {
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Deadly Peridot",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Hex of Leeching",
          SHOULDER = "Enchant Shoulders - Silvermoon's Mending",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Sunfire Silk Spellthread",
          FEET = "Enchant Boots - Shaladrassil's Roots",
          FINGER1 = "Enchant Ring - Silvermoon's Alacrity",
          FINGER2 = "Enchant Ring - Silvermoon's Alacrity",
          MAINHAND = "Enchant Weapon - Acuity of the Ren'dorei",
        },
      },
      WINDWALKER = {
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Masterful Peridot",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Rune of Avoidance",
          SHOULDER = "Enchant Shoulders - Amirdrassil's Grace",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Forest Hunter's Armor Kit",
          FEET = "Enchant Boots - Lynx's Dexterity",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
          MAINHAND = "Enchant Weapon - Acuity of the Ren'dorei",
          OFFHAND = "Enchant Weapon - Acuity of the Ren'dorei",
        },
      },
    },
    PALADIN = {
      HOLY = {
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Quick Amethyst",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Hex of Leeching",
          SHOULDER = "Enchant Shoulders - Silvermoon's Mending",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Arcanoweave Spellthread",
          FEET = "Enchant Boots - Shaladrassil's Roots",
          FINGER1 = "Enchant Ring - Zul'jin's Mastery",
          FINGER2 = "Enchant Ring - Zul'jin's Mastery",
          MAINHAND = "Enchant Weapon - Acuity of the Ren'dorei",
        },
      },
      PROTECTION = {
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Quick Garnet",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Hex of Leeching",
          SHOULDER = "Enchant Shoulders - Silvermoon's Mending",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Forest Hunter's Armor Kit",
          FEET = "Enchant Boots - Shaladrassil's Roots",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
          MAINHAND = "Enchant Weapon - Acuity of the Ren'dorei",
        },
      },
      RETRIBUTION = {
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Masterful Peridot",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Rune of Avoidance",
          SHOULDER = "Enchant Shoulders - Amirdrassil's Grace",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Forest Hunter's Armor Kit",
          FEET = "Enchant Boots - Lynx's Dexterity",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
          MAINHAND = "Enchant Weapon - Acuity of the Ren'dorei",
        },
      },
    },
    PRIEST = {
      DISCIPLINE = {
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Masterful Peridot",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Hex of Leeching",
          SHOULDER = "Enchant Shoulders - Silvermoon's Mending",
          CHEST = "Enchant Chest - Mark of the Magister",
          LEGS = "Arcanoweave Spellthread",
          FEET = "Enchant Boots - Shaladrassil's Roots",
          FINGER1 = "Enchant Ring - Silvermoon's Alacrity",
          FINGER2 = "Enchant Ring - Silvermoon's Alacrity",
          MAINHAND = "Enchant Weapon - Acuity of the Ren'dorei",
        },
      },
      HOLY = {
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Versatile Garnet",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Hex of Leeching",
          SHOULDER = "Enchant Shoulders - Silvermoon's Mending",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Sunfire Silk Spellthread",
          FEET = "Enchant Boots - Shaladrassil's Roots",
          FINGER1 = "Enchant Ring - Nature's Fury",
          FINGER2 = "Enchant Ring - Nature's Fury",
          MAINHAND = "Enchant Weapon - Acuity of the Ren'dorei",
        },
      },
      SHADOW = {
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Masterful Peridot",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Rune of Avoidance",
          SHOULDER = "Enchant Shoulders - Amirdrassil's Grace",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Sunfire Silk Spellthread",
          FEET = "Enchant Boots - Lynx's Dexterity",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
          MAINHAND = "Enchant Weapon - Arcane Mastery",
        },
      },
    },
    ROGUE = {
      ASSASSINATION = {
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Quick Garnet",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Rune of Avoidance",
          SHOULDER = "Enchant Shoulders - Amirdrassil's Grace",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Forest Hunter's Armor Kit",
          FEET = "Enchant Boots - Lynx's Dexterity",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
          MAINHAND = "Enchant Weapon - Berserker's Rage",
          OFFHAND = "Enchant Weapon - Jan'alai's Precision",
        },
      },
      OUTLAW = {
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Quick Garnet",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Hex of Leeching",
          SHOULDER = "Enchant Shoulders - Silvermoon's Mending",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Forest Hunter's Armor Kit",
          FEET = "Enchant Boots - Shaladrassil's Roots",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
          MAINHAND = "Enchant Weapon - Acuity of the Ren'dorei",
          OFFHAND = "Enchant Weapon - Rite of the Hash'ey",
        },
      },
      SUBTLETY = {
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Quick Amethyst",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Rune of Avoidance",
          SHOULDER = "Enchant Shoulders - Amirdrassil's Grace",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Forest Hunter's Armor Kit",
          FEET = "Enchant Boots - Lynx's Dexterity",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
          MAINHAND = "Enchant Weapon - Arcane Mastery",
          OFFHAND = "Enchant Weapon - Arcane Mastery",
        },
      },
    },
    SHAMAN = {
      ELEMENTAL = {
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Deadly Amethyst",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Rune of Avoidance",
          SHOULDER = "Enchant Shoulders - Amirdrassil's Grace",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Sunfire Silk Spellthread",
          FEET = "Enchant Boots - Lynx's Dexterity",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
          MAINHAND = "Enchant Weapon - Jan'alai's Precision",
        },
      },
      ENHANCEMENT = {
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Quick Amethyst",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Rune of Avoidance",
          SHOULDER = "Enchant Shoulders - Amirdrassil's Grace",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Forest Hunter's Armor Kit",
          FEET = "Enchant Boots - Lynx's Dexterity",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
          MAINHAND = "Enchant Weapon - Arcane Mastery",
          OFFHAND = "Enchant Weapon - Arcane Mastery",
        },
      },
      RESTORATION = {
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Versatile Garnet",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Hex of Leeching",
          SHOULDER = "Enchant Shoulders - Silvermoon's Mending",
          CHEST = "Enchant Chest - Mark of the Magister",
          LEGS = "Arcanoweave Spellthread",
          FEET = "Enchant Boots - Shaladrassil's Roots",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
          MAINHAND = "Enchant Weapon - Acuity of the Ren'dorei",
        },
      },
    },
    WARLOCK = {
      AFFLICTION = {
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Quick Garnet",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Rune of Avoidance",
          SHOULDER = "Enchant Shoulders - Amirdrassil's Grace",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Sunfire Silk Spellthread",
          FEET = "Enchant Boots - Lynx's Dexterity",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
          MAINHAND = "Enchant Weapon - Acuity of the Ren'dorei",
        },
      },
      DEMONOLOGY = {
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Quick Garnet",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Rune of Avoidance",
          SHOULDER = "Enchant Shoulders - Amirdrassil's Grace",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Sunfire Silk Spellthread",
          FEET = "Enchant Boots - Lynx's Dexterity",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
          MAINHAND = "Enchant Weapon - Acuity of the Ren'dorei",
        },
      },
      DESTRUCTION = {
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Quick Garnet",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Rune of Avoidance",
          SHOULDER = "Enchant Shoulders - Amirdrassil's Grace",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Sunfire Silk Spellthread",
          FEET = "Enchant Boots - Lynx's Dexterity",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
          MAINHAND = "Enchant Weapon - Acuity of the Ren'dorei",
        },
      },
    },
    WARRIOR = {
      ARMS = {
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Quick Garnet",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Rune of Avoidance",
          SHOULDER = "Enchant Shoulders - Amirdrassil's Grace",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Blood Knight's Armor Kit",
          FEET = "Enchant Boots - Lynx's Dexterity",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
          MAINHAND = "Enchant Weapon - Berserker's Rage",
        },
      },
      FURY = {
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Quick Amethyst",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Rune of Avoidance",
          SHOULDER = "Enchant Shoulders - Amirdrassil's Grace",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Blood Knight's Armor Kit",
          FEET = "Enchant Boots - Lynx's Dexterity",
          FINGER1 = "Enchant Ring - Eyes of the Eagle",
          FINGER2 = "Enchant Ring - Eyes of the Eagle",
          MAINHAND = "Enchant Weapon - Arcane Mastery",
          OFFHAND = "Enchant Weapon - Arcane Mastery",
        },
      },
      PROTECTION = {
        Gems = {
          Primary = "Indecipherable Eversong Diamond",
          Secondary = "Flawless Versatile Peridot",
        },
        Enchants = {
          HEAD = "Enchant Helm - Empowered Hex of Leeching",
          SHOULDER = "Enchant Shoulders - Silvermoon's Mending",
          CHEST = "Enchant Chest - Mark of the Worldsoul",
          LEGS = "Forest Hunter's Armor Kit",
          FEET = "Enchant Boots - Shaladrassil's Roots",
          FINGER1 = "Enchant Ring - Silvermoon's Alacrity",
          FINGER2 = "Enchant Ring - Silvermoon's Alacrity",
          MAINHAND = "Enchant Weapon - Berserker's Rage",
        },
      },
    },
  },
}

MOUNT_IDS = { -- from https://wowpedia.fandom.com/wiki/MountID (Use the ID from the leftmost column)
  ["Charger"]                      = 84,
  ["Swift Razzashi Raptor"]        = 110,
  ["Ashes of Al'ar"]               = 183,
  ["Time-Lost Proto-Drake"]        = 265,
  ["Mekgineer's Chopper"]          = 275,
  ["Ironbound Proto-Drake"]        = 306,
  ["Sea Turtle"]                   = 312,
  ["X-45 Heartbreaker"]            = 352,
  ["Celestial Steed"]              = 376,
  ["Sandstone Drake"]              = 407,
  ["Tyrael's Charger"]             = 439,
  ["Grand Expedition Yak"]         = 460,
  ["Sky Golem"]                    = 522,
  ["Highlord's Golden Charger"]    = 885,
  ["Lightforged Warframe"]         = 932,
  ["Highland Drake"]               = 1563,
  ["Winding Slitherdrake"]         = 1588,
  ["Renewed Proto-Drake"]          = 1589,
  ["Grotto Netherwing Drake"]      = 1744,
  ["Algarian Stormrider"]          = 1792,
  ["Auspicious Arborwyrm"]         = 1795,
  ["Incognitro, the Indecipherable Felcycle"] = 1943,
  ["Grizzly Hills Packmaster"]     = 2237,
  ["Coldflame Tempest"]            = 2261,
  ["Trader's Gilded Brutosaur"]    = 2265,
  ["Chaos-Forged Gryphon"]         = 2304,
  ["Lightwing Dragonhawk"]         = 2568,
  ["Royal Voidwing"]               = 2606,
  ["Starspark Netherdrake"]        = 2719,
}

ACTUALLY_FLYABLE_MAP_IDS = {
  CONTINENTS = {
    619, -- Broken Isles
  },
  ZONES = {
  },
  MAPS = {
    627,   -- Legion Dalaran, but as a dungeon due to phasing for the Harbinger questline
  }
}

NOT_ACTUALLY_FLYABLE_MAP_IDS = {
  CONTINENTS = {
    905,	-- Argus
  },
  ZONES = {
    94,    -- Eversong Woods
    95,    -- Ghostlands
    97,    -- Azuremyst Isle
    103,   -- The Exodar
    106,   -- Bloodmyst Isle
    110,   -- Silvermoon City
    122,   -- Isle of Quel'Danas
    747,   -- The Dreamgrove (Druid Legion Hall)
    946,   -- "Cosmic" (Ashran BG)
    1334,  -- Wintergrasp (BG)
    1543,  -- The Maw
    1961,  -- Korthia, The Maw
  },
  MAPS = {
    715,   -- Emerald Dreamway, The Dreamgrove (Druid Legion Hall)
    747,   -- The Dreamgrove (Druid Legion Hall)
    1478,  -- Ashran (BG)
  }
}

-- Alchemists have equal strength potions but they're cheaper to make,
-- so we're adding an amount to make them be used first when equal strength potions:
ALCHEMIST_VALUE_OFFSET = 1000 

BEST_ITEMS = {
  BEST_HEALING_POTIONS = {
    BINDING_NAME = "SLACKHACKS_BEST_HEALING_POTION",

    -- Mapping of:
    -- ITEM_ID = MAX_HEALING

    -- TWW Alchemist-Only Healing Potions
    [212944]     = 3839450 + ALCHEMIST_VALUE_OFFSET, -- Fleeting Algari Healing Potion (Quality 3)
    [212943]     = 3681800 + ALCHEMIST_VALUE_OFFSET, -- Fleeting Algari Healing Potion (Quality 2)
    [212942]     = 3530600 + ALCHEMIST_VALUE_OFFSET, -- Fleeting Algari Healing Potion (Quality 1)
    [211880]     = 3839450, -- Algari Healing Potion (Quality 3)
    [211879]     = 3681800, -- Algari Healing Potion (Quality 2)
    [211878]     = 3530600, -- Algari Healing Potion (Quality 1)

    -- TWW Healing/Mana Potions
    [212950]     = 2799950 + ALCHEMIST_VALUE_OFFSET, -- Fleeting Cavedweller's Delight (Quality 3)
    [212949]     = 2685000 + ALCHEMIST_VALUE_OFFSET, -- Fleeting Cavedweller's Delight (Quality 2)
    [212948]     = 2574760 + ALCHEMIST_VALUE_OFFSET, -- Fleeting Cavedweller's Delight (Quality 1)
    [212244]     = 2799950, -- Cavedweller's Delight (Quality 3)
    [212243]     = 2685000, -- Cavedweller's Delight (Quality 2)
    [212242]     = 2574760, -- Cavedweller's Delight (Quality 1)
    
    
    -- Dragonflight Healing Potions:  https://www.wowhead.com/spells/professions/alchemy/name:Healing+Potion/live-only:on?filter=16;10;0
    [207023]     = 310592, -- Dreamwalker's Healing Potion (Quality 3)
    [207022]     = 266709, -- Dreamwalker's Healing Potion (Quality 2)
    [207021]     = 228992, -- Dreamwalker's Healing Potion (Quality 1)
    [191380]     = 160300, -- Refreshing Healing Potion (Quality 3)
    [191379]     = 137550, -- Refreshing Healing Potion (Quality 2)
    [191378]     = 118000, -- Refreshing Healing Potion (Quality 1)

    -- Classic Healing Potions:  https://www.wowhead.com/classic/spells/professions/alchemy/name:Healing+Potion/live-only:on?filter=16;10;0
    [13446]      = 1750,  -- Major Healing Potion
    [3928]       = 900,   -- Superior Healing Potion
    [1710]       = 585,   -- Greater Healing Potion
    [929]        = 360,   -- Healing Potion
    [858]        = 180,   -- Lesser Healing Potion
    [118]        = 90,    -- Minor Healing Potion
  },

  BEST_MANA_POTIONS = {
    BINDING_NAME = "SLACKHACKS_BEST_MANA_POTION",

    -- Mapping of:
    -- ITEM_ID = MAX_MANA_RESTORATION

    -- TWW Alchemist-Only Mana Potions
    [212947]     = 270000 + ALCHEMIST_VALUE_OFFSET, -- Fleeting Algari Mana Potion (Quality 3)
    [212946]     = 234783 + ALCHEMIST_VALUE_OFFSET, -- Fleeting Algari Mana Potion (Quality 2)
    [212945]     = 204159 + ALCHEMIST_VALUE_OFFSET, -- Fleeting Algari Mana Potion (Quality 1)
    [212241]     = 270000, -- Algari Mana Potion (Quality 3)
    [212240]     = 234783, -- Algari Mana Potion (Quality 2)
    [212239]     = 204159, -- Algari Mana Potion (Quality 1)

    -- TWW Mana/Healing Potions
    [212950]     = 202500 + ALCHEMIST_VALUE_OFFSET, -- Fleeting Cavedweller's Delight (Quality 3)
    [212949]     = 176087 + ALCHEMIST_VALUE_OFFSET, -- Fleeting Cavedweller's Delight (Quality 2)
    [212948]     = 153119 + ALCHEMIST_VALUE_OFFSET, -- Fleeting Cavedweller's Delight (Quality 1)
    [212244]     = 202500, -- Cavedweller's Delight (Quality 3)
    [212243]     = 176087, -- Cavedweller's Delight (Quality 2)
    [212242]     = 153119, -- Cavedweller's Delight (Quality 1)


    -- Dragonflight Mana Potions:  https://www.wowhead.com/spells/professions/alchemy/name:Mana+Potion/live-only:on?filter=16;10;0
    [191386]     = 27600, -- Aerated Mana Potion (Quality 3)
    [191385]     = 24000, -- Aerated Mana Potion (Quality 2)
    [191384]     = 20870, -- Aerated Mana Potion (Quality 1)

    -- Classic Mana Potions: https://www.wowhead.com/classic/spells/professions/alchemy/name:Mana+Potion#0-18+2
    [13444]      = 2250, -- Major Mana Potion
    [13443]      = 1500, -- Superior Mana Potion
    [6149]       = 900, -- Greater Mana Potion
    [3827]       = 585, -- Mana Potion
    [3385]       = 360, -- Lesser Mana Potion
    [2455]       = 180, -- Minor Mana Potion
  },

  BEST_BANDAGES = {
    BINDING_NAME = "SLACKHACKS_BEST_BANDAGE",

    -- Mapping of:
    -- ITEM_ID = MAX_HEALING

    -- TWW Bandages:
    [224442]     = 3339000, -- Weavercloth Bandage (Quality 3)
    [224441]     = 2504250, -- Weavercloth Bandage (Quality 2)
    [224440]     = 1669500, -- Weavercloth Bandage (Quality 1)


    -- Dragonflight Bandages:
    [194050]     = 50768, -- Wildercloth Bandage (Quality 3)
    [194049]     = 43560, -- Wildercloth Bandage (Quality 2)
    [194048]     = 37376, -- Wildercloth Bandage (Quality 1)

    -- Classic Bandages:
    [14530]      = 2000, -- Heavy Runecloth Bandage
    [14529]      = 1360, -- Runecloth Bandage
    [8545]       = 1104, -- Heavy Mageweave Bandage
    [8544]       = 800,  -- Mageweave Bandage
    [6451]       = 640,  -- Heavy Silk Bandage
    [6450]       = 400,  -- Silk Bandage
    [3531]       = 301,  -- Heavy Wool Bandage
    [3530]       = 161,  -- Wool Bandage
    [2581]       = 114,  -- Heavy Linen Bandage
    [1251]       = 66,   -- Linen Bandage
  },
}
