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

SELF_VENDOR_TRIGGER_EMOTES = {
  ABSENT = { slashCommands = "/absent", example = "You look at %s absently.", trigger = "you look at %s absently." },
  AGREE = { slashCommands = "/agree", example = "You agree with %s.", trigger = "you agree with %s." },
  AMAZE = { slashCommands = "/amaze", example = "You are amazed by %s!", trigger = "you are amazed by %s!" },
  ANGRY = { slashCommands = "/angry /mad", example = "You raise your fist in anger at %s.", trigger = "you raise your fist in anger at %s." },
  APOLOGIZE = { slashCommands = "/apologize /sorry", example = "You apologize to %s. Sorry!", trigger = "you apologize to %s. sorry!" },
  APPLAUD = { slashCommands = "/applaud /bravo /applause", example = "You applaud at %s. Bravo!", trigger = "you applaud at %s. bravo!" },
  ARM = { slashCommands = "/arm", example = "You put your arm around %s's shoulder.", trigger = "you put your arm around %s's shoulder." },
  ATTACKTARGET = { slashCommands = "/attacktarget", example = "You tell everyone to attack %s.", trigger = "you tell everyone to attack %s." },
  AWE = { slashCommands = "/awe", example = "You stare at %s in awe.", trigger = "you stare at %s in awe." },
  BADFEELING = { slashCommands = "/badfeeling /bad", example = "You have a bad feeling about %s.", trigger = "you have a bad feeling about %s." },
  BARK = { slashCommands = "/bark", example = "You bark at %s.", trigger = "you bark at %s." },
  BASHFUL = { slashCommands = "/bashful", example = "You are so bashful...too bashful to get %s's attention.", trigger = "you are so bashful...too bashful to get %s's attention." },
  BECKON = { slashCommands = "/beckon", example = "You beckon %s over.", trigger = "you beckon %s over." },
  BEG = { slashCommands = "/beg", example = "You beg %s. How pathetic!", trigger = "you beg %s. how pathetic!" },
  BITE = { slashCommands = "/bite", example = "You bite %s. Ouch!", trigger = "you bite %s. ouch!" },
  BLAME = { slashCommands = "/blame", example = "You blame %s for everything.", trigger = "you blame %s for everything." },
  BLANK = { slashCommands = "/blank", example = "You stare blankly at %s.", trigger = "you stare blankly at %s." },
  BLINK = { slashCommands = "/blink", example = "You blink at %s.", trigger = "you blink at %s." },
  BLUSH = { slashCommands = "/blush", example = "You blush at %s.", trigger = "you blush at %s." },
  BOGGLE = { slashCommands = "/boggle", example = "You boggle at %s.", trigger = "you boggle at %s." },
  BONK = { slashCommands = "/bonk /doh", example = "You bonk %s on the noggin. Doh!", trigger = "you bonk %s on the noggin. doh!" },
  BOOP = { slashCommands = "/boop", example = "You boop %s's nose.", trigger = "you boop %s's nose." },
  BOOT = { slashCommands = "/boot", example = "You kick at %s.", trigger = "you kick at %s." },
  BORED = { slashCommands = "/bored", example = "You are terribly bored with %s.", trigger = "you are terribly bored with %s." },
  BOUNCE = { slashCommands = "/bounce", example = "You bounce up and down in front of %s.", trigger = "you bounce up and down in front of %s." },
  BOW = { slashCommands = "/bow", example = "You bow before %s.", trigger = "you bow before %s." },
  BRANDISH = { slashCommands = "/brandish", example = "You brandish your weapon fiercely at %s.", trigger = "you brandish your weapon fiercely at %s." },
  BRB = { slashCommands = "/brb", example = "You let %s know you'll be right back.", trigger = "you let %s know you'll be right back." },
  BREATH = { slashCommands = "/breath", example = "You tell %s to take a deep breath.", trigger = "you tell %s to take a deep breath." },
  BURP = { slashCommands = "/burp /belch", example = "You burp rudely in %s's face.", trigger = "you burp rudely in %s's face." },
  BYE = { slashCommands = "/bye /goodbye /farewell", example = "You wave goodbye to %s. Farewell!", trigger = "you wave goodbye to %s. farewell!" },
  CACKLE = { slashCommands = "/cackle", example = "You cackle maniacally at %s.", trigger = "you cackle maniacally at %s." },
  CALM = { slashCommands = "/calm", example = "You try to calm %s down.", trigger = "you try to calm %s down." },
  CHALLENGE = { slashCommands = "/challenge", example = "You challenge %s to a duel.", trigger = "you challenge %s to a duel." },
  CHARM = { slashCommands = "/charm", example = "You think %s is charming.", trigger = "you think %s is charming." },
  CHEER = { slashCommands = "/cheer /woot", example = "You cheer at %s.", trigger = "you cheer at %s." },
  CHICKEN = { slashCommands = "/chicken /flap /strut", example = "With arms flapping, you strut around %s. Cluck, Cluck, Chicken!", trigger = "with arms flapping, you strut around %s. cluck, cluck, chicken!" },
  CHUCKLE = { slashCommands = "/chuckle", example = "You chuckle at %s.", trigger = "you chuckle at %s." },
  CHUG = { slashCommands = "/chug", example = "You encourage %s to chug. CHUG! CHUG! CHUG!", trigger = "you encourage %s to chug. chug! chug! chug!" },
  CLAP = { slashCommands = "/clap", example = "You clap excitedly for %s.", trigger = "you clap excitedly for %s." },
  COLD = { slashCommands = "/cold", example = "You let %s know that you are cold.", trigger = "you let %s know that you are cold." },
  COMFORT = { slashCommands = "/comfort", example = "You comfort %s.", trigger = "you comfort %s." },
  COMMEND = { slashCommands = "/commend", example = "You commend %s on a job well done.", trigger = "you commend %s on a job well done." },
  CONFUSED = { slashCommands = "/confused", example = "You look at %s with a confused look.", trigger = "you look at %s with a confused look." },
  CONGRATULATE = { slashCommands = "/congratulate /congrats /grats", example = "You congratulate %s.", trigger = "you congratulate %s." },
  COUGH = { slashCommands = "/cough", example = "You cough at %s.", trigger = "you cough at %s." },
  COVEREARS = { slashCommands = "/coverears", example = "You cover %s's ears.", trigger = "you cover %s's ears." },
  COWER = { slashCommands = "/cower /fear", example = "You cower in fear at the sight of %s.", trigger = "you cower in fear at the sight of %s." },
  CRACK = { slashCommands = "/crack /knuckles", example = "You crack your knuckles while staring at %s.", trigger = "you crack your knuckles while staring at %s." },
  CRINGE = { slashCommands = "/cringe", example = "You cringe away from %s.", trigger = "you cringe away from %s." },
  CROSSARMS = { slashCommands = "/crossarms", example = "You cross your arms at %s. Hmph!", trigger = "you cross your arms at %s. hmph!" },
  CRY = { slashCommands = "/cry /sob /weep", example = "You cry on %s's shoulder.", trigger = "you cry on %s's shoulder." },
  CUDDLE = { slashCommands = "/cuddle /spoon", example = "You cuddle up against %s.", trigger = "you cuddle up against %s." },
  CURIOUS = { slashCommands = "/curious", example = "You are curious what %s is up to.", trigger = "you are curious what %s is up to." },
  CURTSEY = { slashCommands = "/curtsey", example = "You curtsey before %s.", trigger = "you curtsey before %s." },
  DANCE = { slashCommands = "/dance", example = "You dance with %s.", trigger = "you dance with %s." },
  DING = { slashCommands = "/ding", example = "You congratulate %s on a new level. DING!", trigger = "you congratulate %s on a new level. ding!" },
  DISAGREE = { slashCommands = "/disagree", example = "You disagree with %s.", trigger = "you disagree with %s." },
  THREATEN = { slashCommands = "/threaten /doom /threat /wrath", example = "You threaten %s with the wrath of doom.", trigger = "you threaten %s with the wrath of doom." },
  DOUBT = { slashCommands = "/doubt", example = "You doubt %s.", trigger = "you doubt %s." },
  DRINK = { slashCommands = "/drink /shindig", example = "You raise a drink to %s. Cheers!", trigger = "you raise a drink to %s. cheers!" },
  DROOL = { slashCommands = "/drool", example = "You look at %s and begin to drool.", trigger = "you look at %s and begin to drool." },
  DUCK = { slashCommands = "/duck", example = "You duck behind %s.", trigger = "you duck behind %s." },
  EAT = { slashCommands = "/eat /chew /feast", example = "You begin to eat in front of %s.", trigger = "you begin to eat in front of %s." },
  EMBARRASS = { slashCommands = "/embarrass", example = "You are embarrassed by %s.", trigger = "you are embarrassed by %s." },
  ENCOURAGE = { slashCommands = "/encourage", example = "You encourage %s.", trigger = "you encourage %s." },
  ENEMY = { slashCommands = "/enemy", example = "You warn %s that an enemy is near.", trigger = "you warn %s that an enemy is near." },
  EYE = { slashCommands = "/eye", example = "You eye %s up and down.", trigger = "you eye %s up and down." },
  EYEBROW = { slashCommands = "/eyebrow /brow", example = "You raise your eyebrow inquisitively at %s.", trigger = "you raise your eyebrow inquisitively at %s." },
  FACEPALM = { slashCommands = "/facepalm /palm", example = "You look at %s and cover your face with your palm.", trigger = "you look at %s and cover your face with your palm." },
  FAINT = { slashCommands = "/faint", example = "You faint at the sight of %s.", trigger = "you faint at the sight of %s." },
  FART = { slashCommands = "/fart", example = "You brush up against %s and fart loudly.", trigger = "you brush up against %s and fart loudly." },
  FIDGET = { slashCommands = "/fidget /impatient", example = "You fidget impatiently while waiting for %s.", trigger = "you fidget impatiently while waiting for %s." },
  FLEE = { slashCommands = "/flee /retreat", example = "You yell for %s to flee!", trigger = "you yell for %s to flee!" },
  FLEX = { slashCommands = "/flex /strong", example = "You flex at %s. Oooooh so strong!", trigger = "flexes at you" },
  FLIRT = { slashCommands = "/flirt", example = "You flirt with %s.", trigger = "flirts with you" },
  FLOP = { slashCommands = "/flop", example = "You flop about helplessly around %s.", trigger = "you flop about helplessly around %s." },
  FOLLOWME = { slashCommands = "/followme", example = "You motion for %s to follow.", trigger = "you motion for %s to follow." },
  FROWN = { slashCommands = "/frown /disappointed", example = "You frown with disappointment at %s.", trigger = "you frown with disappointment at %s." },
  GASP = { slashCommands = "/gasp", example = "You gasp at %s.", trigger = "you gasp at %s." },
  GAZE = { slashCommands = "/gaze", example = "You gaze longingly at %s.", trigger = "gazes longingly at you" },
  GIGGLE = { slashCommands = "/giggle", example = "You giggle at %s.", trigger = "you giggle at %s." },
  GLARE = { slashCommands = "/glare", example = "You glare angrily at %s.", trigger = "glares angrily at you" },
  GLOAT = { slashCommands = "/gloat", example = "You gloat over %s's misfortune.", trigger = "you gloat over %s's misfortune." },
  GLOWER = { slashCommands = "/glower", example = "You glower at %s.", trigger = "you glower at %s." },
  GO = { slashCommands = "/go", example = "You tell %s to go.", trigger = "you tell %s to go." },
  GOING = { slashCommands = "/going", example = "You tell %s that you must be going.", trigger = "you tell %s that you must be going." },
  GOLFCLAP = { slashCommands = "/golfclap", example = "You clap for %s, clearly unimpressed.", trigger = "you clap for %s, clearly unimpressed." },
  GREET = { slashCommands = "/greet /greetings", example = "You greet %s warmly.", trigger = "you greet %s warmly." },
  GRIN = { slashCommands = "/grin /wicked /wickedly", example = "You grin wickedly at %s.", trigger = "you grin wickedly at %s." },
  GROAN = { slashCommands = "/groan", example = "You look at %s and groan.", trigger = "you look at %s and groan." },
  GROVEL = { slashCommands = "/grovel /peon", example = "You grovel before %s like a subservient peon.", trigger = "you grovel before %s like a subservient peon." },
  GROWL = { slashCommands = "/growl", example = "You growl menacingly at %s.", trigger = "you growl menacingly at %s." },
  GUFFAW = { slashCommands = "/guffaw", example = "You take one look at %s and let out a guffaw!", trigger = "you take one look at %s and let out a guffaw!" },
  HAIL = { slashCommands = "/hail", example = "You hail %s.", trigger = "you hail %s." },
  HAPPY = { slashCommands = "/happy /glad /yay", example = "You are very happy with %s!", trigger = "you are very happy with %s!" },
  HEADACHE = { slashCommands = "/headache", example = "You are getting a headache from %s's antics.", trigger = "you are getting a headache from %s's antics." },
  HELLO = { slashCommands = "/hello /hi", example = "You greet %s with a hearty hello!", trigger = "you greet %s with a hearty hello!" },
  HIGHFIVE = { slashCommands = "/highfive", example = "You give %s a high five!", trigger = "you give %s a high five!" },
  HISS = { slashCommands = "/hiss", example = "You hiss at %s.", trigger = "you hiss at %s." },
  HOLDHAND = { slashCommands = "/holdhand", example = "You hold %s's hand.", trigger = "you hold %s's hand." },
  HUG = { slashCommands = "/hug", example = "You hug %s.", trigger = "you hug %s." },
  HUNGRY = { slashCommands = "/hungry /food /pizza", example = "You are hungry. Maybe %s has some food...", trigger = "you are hungry. maybe %s has some food..." },
  HURRY = { slashCommands = "/hurry", example = "You tell %s to hurry up.", trigger = "you tell %s to hurry up." },
  HUZZAH = { slashCommands = "/huzzah", example = "You cheer boisterously for %s! Huzzah!", trigger = "you cheer boisterously for %s! huzzah!" },
  IMPRESSED = { slashCommands = "/impressed", example = "You clap vigorously for %s, clearly impressed.", trigger = "you clap vigorously for %s, clearly impressed." },
  INCOMING = { slashCommands = "/incoming", example = "You point out %s as an incoming enemy!", trigger = "you point out %s as an incoming enemy!" },
  INSULT = { slashCommands = "/insult", example = "You think %s is the son of a motherless ogre.", trigger = "you think %s is the son of a motherless ogre." },
  INTRODUCE = { slashCommands = "/introduce", example = "You introduce yourself to %s.", trigger = "you introduce yourself to %s." },
  JEALOUS = { slashCommands = "/jealous", example = "You are jealous of %s.", trigger = "you are jealous of %s." },
  JK = { slashCommands = "/jk", example = "You let %s know that you were just kidding!", trigger = "you let %s know that you were just kidding!" },
  KISS = { slashCommands = "/kiss /blow", example = "You blow a kiss to %s.", trigger = "you blow a kiss to %s." },
  KNEEL = { slashCommands = "/kneel", example = "You kneel before %s.", trigger = "you kneel before %s." },
  LAUGH = { slashCommands = "/laugh /lol", example = "You laugh at %s.", trigger = "you laugh at %s." },
  LAYDOWN = { slashCommands = "/laydown /liedown /lay /lie", example = "You lie down before %s.", trigger = "you lie down before %s." },
  LICK = { slashCommands = "/lick", example = "You lick %s.", trigger = "you lick %s." },
  LISTEN = { slashCommands = "/listen", example = "You listen intently to %s.", trigger = "you listen intently to %s." },
  LOOK = { slashCommands = "/look", example = "You look at %s.", trigger = "you look at %s." },
  LOST = { slashCommands = "/lost", example = "You want %s to know that you are hopelessly lost.", trigger = "you want %s to know that you are hopelessly lost." },
  LOVE = { slashCommands = "/love", example = "You love %s.", trigger = "you love %s." },
  LUCK = { slashCommands = "/luck", example = "You wish %s the best of luck.", trigger = "you wish %s the best of luck." },
  MAGNIFICENT = { slashCommands = "/magnificent", example = "You nod approvingly at %s. Magnificent job!", trigger = "you nod approvingly at %s. magnificent job!" },
  MASSAGE = { slashCommands = "/massage", example = "You massage %s's shoulders.", trigger = "you massage %s's shoulders." },
  MEOW = { slashCommands = "/meow", example = "You meow at %s.", trigger = "you meow at %s." },
  MERCY = { slashCommands = "/mercy", example = "You plead with %s for mercy.", trigger = "you plead with %s for mercy." },
  MOAN = { slashCommands = "/moan", example = "You moan suggestively at %s.", trigger = "you moan suggestively at %s." },
  MOCK = { slashCommands = "/mock", example = "You mock the foolishness of %s.", trigger = "you mock the foolishness of %s." },
  MOO = { slashCommands = "/moo", example = "You moo at %s. Mooooooooooo.", trigger = "you moo at %s. mooooooooooo." },
  MOON = { slashCommands = "/moon", example = "You drop your trousers and moon %s.", trigger = "you drop your trousers and moon %s." },
  MOURN = { slashCommands = "/mourn", example = "In quiet contemplation, you mourn the death of %s.", trigger = "in quiet contemplation, you mourn the death of %s." },
  MUTTER = { slashCommands = "/mutter", example = "You mutter angrily at %s. Hmmmph!", trigger = "you mutter angrily at %s. hmmmph!" },
  NERVOUS = { slashCommands = "/nervous", example = "You look at %s nervously.", trigger = "you look at %s nervously." },
  NO = { slashCommands = "/no", example = "You tell %s NO. Not going to happen.", trigger = "you tell %s no. not going to happen." },
  NOD = { slashCommands = "/nod /yes", example = "You nod at %s.", trigger = "you nod at %s." },
  NOSEPICK = { slashCommands = "/nosepick /pick", example = "You pick your nose and show it to %s.", trigger = "you pick your nose and show it to %s." },
  OBJECT = { slashCommands = "/object /objection /holdit", example = "You object to %s.", trigger = "you object to %s." },
  OFFER = { slashCommands = "/offer", example = "You attempt to make %s an offer they can't refuse.", trigger = "you attempt to make %s an offer they can't refuse." },
  PANIC = { slashCommands = "/panic", example = "You take one look at %s and panic.", trigger = "you take one look at %s and panic." },
  PAT = { slashCommands = "/pat", example = "You gently pat %s.", trigger = "you gently pat %s." },
  PEER = { slashCommands = "/peer", example = "You peer at %s searchingly.", trigger = "you peer at %s searchingly." },
  PET = { slashCommands = "/pet", example = "You pet %s.", trigger = "you pet %s." },
  PINCH = { slashCommands = "/pinch", example = "You pinch %s.", trigger = "you pinch %s." },
  PITY = { slashCommands = "/pity", example = "You look down upon %s with pity.", trigger = "you look down upon %s with pity." },
  PLEAD = { slashCommands = "/plead", example = "You plead with %s.", trigger = "you plead with %s." },
  POINT = { slashCommands = "/point", example = "You point at %s.", trigger = "you point at %s." },
  POKE = { slashCommands = "/poke", example = "You poke %s. Hey!", trigger = "you poke %s. hey!" },
  PONDER = { slashCommands = "/ponder", example = "You ponder %s's actions.", trigger = "you ponder %s's actions." },
  POUNCE = { slashCommands = "/pounce", example = "You pounce on top of %s.", trigger = "you pounce on top of %s." },
  POUT = { slashCommands = "/pout", example = "You pout at %s.", trigger = "you pout at %s." },
  PRAISE = { slashCommands = "/praise /lavish", example = "You lavish praise upon %s.", trigger = "you lavish praise upon %s." },
  PRAY = { slashCommands = "/pray", example = "You say a prayer for %s.", trigger = "you say a prayer for %s." },
  PROMISE = { slashCommands = "/promise", example = "You make %s a promise.", trigger = "you make %s a promise." },
  PROUD = { slashCommands = "/proud", example = "You are proud of %s.", trigger = "you are proud of %s." },
  PULSE = { slashCommands = "/pulse", example = "You check %s for a pulse. Oh no!", trigger = "you check %s for a pulse. oh no!" },
  PUNCH = { slashCommands = "/punch", example = "You punch %s's shoulder.", trigger = "you punch %s's shoulder." },
  PURR = { slashCommands = "/purr", example = "You purr at %s.", trigger = "you purr at %s." },
  PUZZLED = { slashCommands = "/puzzled", example = "You are puzzled by %s.", trigger = "you are puzzled by %s." },
  QUACK = { slashCommands = "/quack", example = "You quack at %s. Quack!", trigger = "you quack at %s. quack!" },
  RAISE = { slashCommands = "/raise /volunteer", example = "You look at %s and raise your hand.", trigger = "you look at %s and raise your hand." },
  RASP = { slashCommands = "/rasp", example = "You make a rude gesture at %s.", trigger = "you make a rude gesture at %s." },
  READY = { slashCommands = "/ready /rdy", example = "You let %s know that you are ready!", trigger = "you let %s know that you are ready!" },
  REGRET = { slashCommands = "/regret", example = "You think that %s will regret it.", trigger = "you think that %s will regret it." },
  REVENGE = { slashCommands = "/revenge", example = "You vow revenge on %s.", trigger = "you vow revenge on %s." },
  ROAR = { slashCommands = "/roar /rawr", example = "You roar with bestial vigor at %s. So fierce!", trigger = "you roar with bestial vigor at %s. so fierce!" },
  ROFL = { slashCommands = "/rofl", example = "You roll on the floor laughing at %s.", trigger = "you roll on the floor laughing at %s." },
  ROLLEYES = { slashCommands = "/rolleyes /eyeroll", example = "You roll your eyes at %s.", trigger = "you roll your eyes at %s." },
  RUDE = { slashCommands = "/rude", example = "You make a rude gesture at %s.", trigger = "you make a rude gesture at %s." },
  RUFFLE = { slashCommands = "/ruffle", example = "You ruffle %s's hair.", trigger = "you ruffle %s's hair." },
  SALUTE = { slashCommands = "/salute", example = "You salute %s with respect.", trigger = "salutes you with respect" },
  SCARED = { slashCommands = "/scared", example = "You are scared of %s.", trigger = "you are scared of %s." },
  SCOFF = { slashCommands = "/scoff", example = "You scoff at %s.", trigger = "you scoff at %s." },
  SCOLD = { slashCommands = "/scold", example = "You scold %s.", trigger = "you scold %s." },
  SCOWL = { slashCommands = "/scowl", example = "You scowl at %s.", trigger = "you scowl at %s." },
  SCRATCH = { slashCommands = "/scratch /cat /catty", example = "You scratch %s. How catty!", trigger = "you scratch %s. how catty!" },
  SEARCH = { slashCommands = "/search", example = "You search %s for something.", trigger = "you search %s for something." },
  SEXY = { slashCommands = "/sexy", example = "You think %s is a sexy devil.", trigger = "you think %s is a sexy devil." },
  SHAKE = { slashCommands = "/shake /rear", example = "You shake your rear at %s.", trigger = "you shake your rear at %s." },
  SHAKEFIST = { slashCommands = "/shakefist /fist", example = "You shake your fist at %s.", trigger = "you shake your fist at %s." },
  SHIFTY = { slashCommands = "/shifty", example = "You give %s a shifty look.", trigger = "you give %s a shifty look." },
  SHIMMY = { slashCommands = "/shimmy", example = "You shimmy before %s.", trigger = "you shimmy before %s." },
  SHIVER = { slashCommands = "/shiver", example = "You shiver beside %s. Chilling!", trigger = "you shiver beside %s. chilling!" },
  SHOO = { slashCommands = "/shoo /pest", example = "You shoo %s away. Be gone pest!", trigger = "you shoo %s away. be gone pest!" },
  HOLLER = { slashCommands = "/holler", example = "You shout at %s.", trigger = "you shout at %s." },
  SHRUG = { slashCommands = "/shrug", example = "You shrug at %s. Who knows?", trigger = "you shrug at %s. who knows?" },
  SHUDDER = { slashCommands = "/shudder", example = "You shudder at the sight of %s.", trigger = "you shudder at the sight of %s." },
  SHY = { slashCommands = "/shy", example = "You smile shyly at %s.", trigger = "you smile shyly at %s." },
  SIGH = { slashCommands = "/sigh", example = "You sigh at %s.", trigger = "you sigh at %s." },
  SIGNAL = { slashCommands = "/signal", example = "You give %s the signal.", trigger = "you give %s the signal." },
  SILENCE = { slashCommands = "/silence /shush", example = "You tell %s to be quiet. Shhh!", trigger = "you tell %s to be quiet. shhh!" },
  SILLY = { slashCommands = "/silly", example = "You tell %s a joke.", trigger = "you tell %s a joke." },
  SING = { slashCommands = "/sing", example = "You serenade %s with a song.", trigger = "you serenade %s with a song." },
  SLAP = { slashCommands = "/slap", example = "You slap %s across the face. Ouch!", trigger = "you slap %s across the face. ouch!" },
  SMACK = { slashCommands = "/smack", example = "You smack %s upside the head.", trigger = "you smack %s upside the head." },
  SMILE = { slashCommands = "/smile", example = "You smile at %s.", trigger = "you smile at %s." },
  SMIRK = { slashCommands = "/smirk", example = "You smirk slyly at %s.", trigger = "you smirk slyly at %s." },
  SNAP = { slashCommands = "/snap", example = "You snap your fingers at %s.", trigger = "you snap your fingers at %s." },
  SNARL = { slashCommands = "/snarl", example = "You bare your teeth and snarl at %s.", trigger = "you bare your teeth and snarl at %s." },
  SNEAK = { slashCommands = "/sneak", example = "You try to sneak away from %s.", trigger = "you try to sneak away from %s." },
  SNEEZE = { slashCommands = "/sneeze", example = "You sneeze on %s. Achoo!", trigger = "you sneeze on %s. achoo!" },
  SNICKER = { slashCommands = "/snicker", example = "You snicker at %s.", trigger = "you snicker at %s." },
  SNIFF = { slashCommands = "/sniff", example = "You sniff %s.", trigger = "you sniff %s." },
  SNORT = { slashCommands = "/snort", example = "You snort derisively at %s.", trigger = "you snort derisively at %s." },
  SNUB = { slashCommands = "/snub", example = "You snub %s.", trigger = "you snub %s." },
  SOOTHE = { slashCommands = "/soothe", example = "You soothe %s. There, there...things will be ok.", trigger = "you soothe %s. there, there...things will be ok." },
  SPIT = { slashCommands = "/spit", example = "You spit on %s.", trigger = "you spit on %s." },
  SQUEAL = { slashCommands = "/squeal", example = "You squeal at %s.", trigger = "you squeal at %s." },
  STARE = { slashCommands = "/stare", example = "You stare %s down.", trigger = "you stare %s down." },
  STINK = { slashCommands = "/stink /smell", example = "You smell %s. Wow, someone stinks!", trigger = "you smell %s. wow, someone stinks!" },
  SURPRISED = { slashCommands = "/surprised", example = "You are surprised by %s's actions.", trigger = "you are surprised by %s's actions." },
  SURRENDER = { slashCommands = "/surrender", example = "You surrender before %s. Such is the agony of defeat...", trigger = "you surrender before %s. such is the agony of defeat..." },
  SUSPICIOUS = { slashCommands = "/suspicious", example = "You are suspicious of %s.", trigger = "you are suspicious of %s." },
  SWEAT = { slashCommands = "/sweat", example = "You sweat at the sight of %s.", trigger = "you sweat at the sight of %s." },
  TALK = { slashCommands = "/talk", example = "You want to talk things over with %s.", trigger = "you want to talk things over with %s." },
  TALKEX = { slashCommands = "/talkex /excited", example = "You talk excitedly with %s.", trigger = "you talk excitedly with %s." },
  TALKQ = { slashCommands = "/talkq /question", example = "You question %s.", trigger = "you question %s." },
  TAP = { slashCommands = "/tap", example = "You tap your foot as you wait for %s.", trigger = "you tap your foot as you wait for %s." },
  TAUNT = { slashCommands = "/taunt", example = "You make a taunting gesture at %s. Bring it!", trigger = "you make a taunting gesture at %s. bring it!" },
  TEASE = { slashCommands = "/tease", example = "You tease %s.", trigger = "you tease %s." },
  THANK = { slashCommands = "/thank /thanks /ty", example = "You thank %s.", trigger = "you thank %s." },
  THINK = { slashCommands = "/think", example = "You think about %s.", trigger = "you think about %s." },
  THIRSTY = { slashCommands = "/thirsty", example = "You let %s know you are thirsty. Spare a drink?", trigger = "you let %s know you are thirsty. spare a drink?" },
  TICKLE = { slashCommands = "/tickle", example = "You tickle %s. Hee hee!", trigger = "you tickle %s. hee hee!" },
  TIRED = { slashCommands = "/tired", example = "You let %s know that you are tired.", trigger = "you let %s know that you are tired." },
  TRUCE = { slashCommands = "/truce", example = "You offer %s a truce.", trigger = "you offer %s a truce." },
  VETO = { slashCommands = "/veto", example = "You veto %s's motion.", trigger = "you veto %s's motion." },
  VICTORY = { slashCommands = "/victory", example = "You bask in the glory of victory with %s.", trigger = "basks in the glory of victory with you" },
  VIOLIN = { slashCommands = "/violin", example = "You play the world's smallest violin for %s.", trigger = "you play the world's smallest violin for %s." },
  WAIT = { slashCommands = "/wait", example = "You ask %s to wait.", trigger = "you ask %s to wait." },
  WARN = { slashCommands = "/warn", example = "You warn %s.", trigger = "you warn %s." },
  WAVE = { slashCommands = "/wave", example = "You wave at %s.", trigger = "you wave at %s." },
  WELCOME = { slashCommands = "/welcome", example = "You welcome %s.", trigger = "you welcome %s." },
  WHINE = { slashCommands = "/whine", example = "You whine pathetically at %s.", trigger = "you whine pathetically at %s." },
  WHISTLE = { slashCommands = "/whistle", example = "You whistle at %s.", trigger = "you whistle at %s." },
  WHOA = { slashCommands = "/whoa", example = "You are blown away by %s.", trigger = "you are blown away by %s." },
  WINCE = { slashCommands = "/wince", example = "You wince sympathetically at %s. That looked like it hurt!", trigger = "you wince sympathetically at %s. that looked like it hurt!" },
  WINK = { slashCommands = "/wink", example = "You wink slyly at %s.", trigger = "you wink slyly at %s." },
  WORK = { slashCommands = "/work", example = "You work with %s.", trigger = "you work with %s." },
  YAWN = { slashCommands = "/yawn", example = "You yawn sleepily at %s.", trigger = "you yawn sleepily at %s." },
  YW = { slashCommands = "/yw", example = "You were happy to help %s.", trigger = "you were happy to help %s." },
}

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
