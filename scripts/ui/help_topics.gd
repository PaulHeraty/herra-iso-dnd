class_name HelpTopics
extends RefCounted
## The help mode's texts (HelpBox shows them). Each topic: title + pages. A page:
##   t     the text
##   at    screen rect to frame (the rest of the screen dims), or a focus name HelpBox resolves:
##         "focus" = the rect / Control passed with HelpBox.tip()
##   open  "inventory" / "sheet" / "none": the tour opens (or closes) that screen for the page
##   h     a heading for the page (else the topic's title)
## Order of TOPICS = the order in the F1 help menu.

# --- screen areas (640x360 screen; the inventory and the sheet sit at (16, 6)) -------------------
const R_CARDS := Rect2(2, 301, 497, 58)
const R_BUTTONS := Rect2(498, 301, 141, 58)
const R_REST := Rect2(498, 301, 141, 16)
const R_MINIMAP := Rect2(2, 2, 136, 88)
const R_TOP_LEFT := Rect2(140, 2, 232, 52)
const R_LOG := Rect2(382, 2, 257, 106)
const R_TABS := Rect2(21, 25, 292, 24)
const R_INV_SLOTS := Rect2(20, 49, 292, 108)
const R_INV_STATS := Rect2(20, 156, 292, 120)
const R_INV_BAG := Rect2(318, 24, 302, 144)
const R_INV_INFO := Rect2(318, 165, 302, 113)
const R_SH_ID := Rect2(20, 46, 204, 84)
const R_SH_NUM := Rect2(20, 131, 204, 36)
const R_SH_ABIL := Rect2(20, 165, 204, 47)
const R_SH_SAVES := Rect2(20, 209, 204, 76)
const R_SH_SKILLS := Rect2(222, 48, 156, 242)
const R_SH_RIGHT := Rect2(372, 48, 250, 242)

## Hero card i in the party panel.
static func card_rect(i: int) -> Rect2:
	return Rect2(3 + i * 124, 302, 123, 56)


const TOPICS := {
	"welcome": {title = "WELCOME TO HERRA D&D", calm = true, pages = [
		{t = "Help mode is on: whenever something new happens, a box like this explains it.\n\nSpace / Enter = next page, Esc or the x (top right) = close. 'Help off' stops these boxes for good; F1 brings help back any time and lists every topic.", open = "none"},
		{h = "MOVING", t = "Click the ground to walk: the leader goes there and the others follow. Click doors, chests, levers and people to use them; the line at the top says what a click will do.\n\nCamera: WASD / arrows or middle-drag to pan, wheel to zoom, Space recentres, Q / E turn the view."},
		{h = "THE PARTY", at = R_CARDS, t = "Your four heroes. Each card shows the level, HP (number + red bar), spell slots (blue pips: blue = ready, dark = spent) and a purple XP line towards the next level.\n\nSmall icons on a card are conditions: hover one to see what it does. Click a card to find the hero; right-click it for the character sheet."},
		{h = "EXPLORING", at = R_BUTTONS, t = "While exploring: Short / Long rest, Search (F) for hidden traps and secret doors, the Bag (I), the Quest log (J) and the character Sheet (C). The party's gold is shown here too.\n\nIn a fight these buttons turn into the combat actions."},
		{h = "THE MAP", at = R_MINIMAP, t = "The minimap follows the party (- / + or the wheel to zoom); click it, or press M, for the full map.\n\nYou only see what your heroes can see: black = not explored yet, dimmed = explored but out of sight (monsters there are hidden)."},
		{h = "THE INVENTORY (I)", open = "inventory", at = R_TABS, t = "This is the inventory: the party shares one bag, and each hero wears their own gear.\n\nThese tabs pick whose gear is shown (clicking a party card does too). Drag an item onto a tab to give it to that hero."},
		{h = "EQUIPMENT", open = "inventory", at = R_INV_SLOTS, t = "The hero's slots: main hand, off hand (a shield), ranged weapon, armour, two rings and two worn items (cloaks, amulets, gauntlets...).\n\nClick a slot to take the item off (back into the bag), or drag it."},
		{h = "WHAT THE GEAR GIVES", open = "inventory", at = R_INV_STATS, t = "Armour Class, attacks and saving throws with this gear on. It changes as soon as you equip something."},
		{h = "THE PARTY BAG", open = "inventory", at = R_INV_BAG, t = "Everything the party carries. Click an item to put it on the hero shown, or drag it onto a slot or a hero tab.\n\nClick a potion to drink it (exploring only). Sort tidies the bag. In a fight the bag is read-only: use the Item action instead."},
		{h = "HOVER FOR INFO", open = "inventory", at = R_INV_INFO, t = "Hover over any item or slot and this box tells you what it is, and what equipping it would change (green = better, red = worse). Orange warns that the hero isn't trained to use it.\n\nMagic items have blue names and a glimmer on their icon."},
		{h = "THE CHARACTER SHEET (C)", open = "sheet", at = R_SH_ID, t = "Each hero's sheet. Here: class, level and XP (the bar fills towards the next level), HP and hit dice. Hit dice are spent on a short rest to heal.\n\nHover over almost anything on this sheet for an explanation."},
		{h = "THE KEY NUMBERS", open = "sheet", at = R_SH_NUM, t = "AC (Armour Class): an attack must roll this or more to hit the hero.\nINIT: added to the initiative roll that decides who acts first in a fight.\nSPEED: how far the hero moves in a turn.\nPROF: the proficiency bonus, added to everything the hero is trained in."},
		{h = "ABILITIES", open = "sheet", at = R_SH_ABIL, t = "The six abilities: Strength, Dexterity, Constitution, Intelligence, Wisdom, Charisma. The small number is the score, the big one its modifier: (score - 10) / 2, rounded down.\n\nThe modifier is what gets added to rolls: STR to melee hits, DEX to AC and bows, CON to HP..."},
		{h = "SAVING THROWS", open = "sheet", at = R_SH_SAVES, t = "A saving throw resists something bad: a fireball (DEX), poison (CON), a spell on the mind (WIS). Roll a d20 + this bonus; reach the DC to resist (often half damage).\n\nA green dot = trained: the proficiency bonus is added. Below: the armour and weapons the hero is trained with."},
		{h = "SKILLS", open = "sheet", at = R_SH_SKILLS, t = "A skill check is a d20 + the skill's bonus against a difficulty (DC). Green dot = trained (+ proficiency), gold = expertise (double).\n\nPassive Perception (10 + Perception) is how heroes notice hidden traps and doors without trying. Hover a skill to see where the game uses it."},
		{h = "ATTACKS, SPELLS, FEATURES", open = "sheet", at = R_SH_RIGHT, t = "Attacks: bonus to hit and damage. Spellcasters: the spell save DC (what monsters roll against), the spell attack bonus and spell slots per level.\n\nThen the spells and abilities (cost or uses on the right) and class features. Hover any line for the full description."},
		{h = "THAT'S IT", open = "none", t = "Keys worth knowing: I bag, C sheet, J quest log + journal, M map, F search, Esc closes a screen, or with none open brings up the menu (save, load, settings, quit). F5 quick save, F6 save slots, F9 load. F2 changes how dice rolls are shown, F11 fullscreen.\n\nGood luck. Help will pop up again when something new happens."},
	]},
	"combat": {title = "COMBAT!", pages = [
		{h = "INITIATIVE", at = R_LOG, t = "A monster has spotted the party, so the game switches to turns. Everyone rolled initiative: a d20 + their initiative bonus (mostly DEX). Highest goes first.\n\nThe rolls are in the log here. Each round everyone takes one turn, in that order."},
		{h = "WHOSE TURN", at = R_TOP_LEFT, t = "The banner shows whose turn it is, the line below says what you can do or what a click will do, and 'Next' lists the turns coming up.\n\nThe active hero stands on a pulsing yellow square, and their card is framed in yellow."},
		{h = "MOVING", t = "On a hero's turn, the blue squares show how far they can move (most heroes: 30 ft = 6 squares; diagonals count as one). Click a blue square to walk.\n\nYou can move part of the way, act, then move the rest. Nobody can walk through anyone else."},
		{h = "ACTIONS", at = R_BUTTONS, t = "Each turn a hero has one action, and some powers are a bonus action on top.\nAttack: click an enemy (the line at the top shows the chance to hit).\nSpell / Ability: the hero's spells and class powers.\nItem: drink a potion or read a scroll.\nWait (Enter): end the turn."},
		{h = "HITTING", t = "An attack rolls a d20 + the attack bonus. Reach the target's AC and it hits, then the damage dice are rolled.\n\nA natural 20 is a critical hit (double the damage dice); a natural 1 always misses. Advantage = roll two d20s and keep the higher (e.g. the target is prone); disadvantage = keep the lower."},
		{h = "WINNING", t = "Monsters show an HP bar. When they're all down, the party wins and shares the XP.\n\nIn a fight you can still open doors (free, once a turn), look at the sheet (C), the bag (I) and the map (M), but not open chests or rest."},
	]},
	"hero_down": {title = "A HERO IS DOWN!", pages = [
		{at = "focus", t = "At 0 HP a hero falls unconscious and is dying. On each of their turns they make a death saving throw: a d20, 10 or more is a success, less is a failure.\n\nA natural 1 counts as two failures; a natural 20 brings them back up with 1 HP."},
		{h = "STABLE OR DEAD", at = "focus", t = "3 successes: the hero is stable (still unconscious, but no longer dying). 3 failures: the hero dies.\n\nGetting hit while down counts as a failure. The pips on the card keep count: green = successes, red = failures."},
		{h = "GET THEM UP", at = "focus", t = "Any healing brings a downed hero back, however little. The Cleric's Cure Wounds (touch) or Healing Word (at range, a bonus action), or a potion: choose Item, then click the hero lying next to you.\n\nIf the fight is won, downed heroes come to with 1 HP."},
	]},
	"knocked_out": {title = "KNOCKED OUT", calm = true, pages = [
		{t = "Outside a fight, traps and hazards can't kill: a hero who drops to 0 HP is knocked out and comes to with 1 HP a moment later.\n\nHeal up before the next fight: a short rest spends hit dice, a long rest brings everything back."},
	]},
	"hero_died": {title = "A HERO HAS DIED", pages = [
		{at = "focus", t = "Three failed death saves (or one huge blow) and a hero is dead. The dead stay dead: no healing or rest brings them back.\n\nIf you'd rather not go on without them, load a save (F9). After a party wipe, R restarts the map as you arrived."},
	]},
	"conditions": {title = "CONDITIONS", pages = [
		{at = "focus", t = "Conditions show as small icons on a hero's card: hover an icon to see what it does and how long it lasts.\n\nProne: attacks have disadvantage; standing up costs half the movement.\nRestrained (webs): can't move; use 'Break free' in the Ability menu.\nFrightened: attacks have disadvantage.\nParalyzed: can't act; saves at the end of each turn."},
	]},
	"concentration": {title = "CONCENTRATION", pages = [
		{at = "focus", t = "Some spells (Bless, Hold Person...) last while the caster concentrates, shown by an icon on their card. Only one at a time: a new one ends the old.\n\nWhen the caster takes damage they roll a CON save (DC 10, or half the damage if that's more). Fail, and the spell ends."},
	]},
	"reaction": {title = "REACTIONS", pages = [
		{t = "A reaction is something a hero can do outside their own turn, once per round: the Mage's Shield, the Rogue's Uncanny Dodge.\n\nThe game asks when one would change what happens. Y = yes, N = no."},
	]},
	"spells": {title = "SPELLS & ABILITIES", pages = [
		{t = "Hover a spell or ability for what it does. Spells of 1st level and up spend a spell slot (the blue pips on the card); cantrips are free. Slots come back on a long rest.\n\nAfter picking one: orange shows the targets or the area. Click to aim, + / - picks a higher slot (a stronger spell), right-click cancels."},
	]},
	"after_combat": {title = "VICTORY!", calm = true, pages = [
		{at = R_REST, t = "The XP is shared between the heroes still alive; with enough of it they gain a level. Heroes who were down come to with 1 HP.\n\nHurt? A short rest lets each hero spend hit dice to heal (and some powers come back). A long rest brings back all HP, spell slots and powers. Nobody can rest with enemies nearby."},
	]},
	"level_up": {title = "LEVEL UP!", calm = true, pages = [
		{at = "focus", t = "Each level brings more HP and often new spells, more spell slots or new class features, as listed here.\n\nOpen the character sheet (C) to see them, and hover over anything there for the details."},
	]},
	"chest": {title = "TREASURE", calm = true, pages = [
		{at = "focus", t = "Whatever is in a chest goes straight into the party bag, gold too.\n\nOpen the Bag (I) to put new gear on. Hover over any item there to see what it does and what equipping it would change. Magic items have blue names."},
	]},
	"locked": {title = "LOCKED", calm = true, pages = [
		{t = "The Rogue tries to pick a lock with thieves' tools (a d20 + DEX + proficiency against the lock's DC). Without a Rogue, the strongest hero tries to force it (Athletics, a little harder).\n\nFailed? Click it again to retry. Some locks only open with their key; keys go in the bag and work by themselves."},
	]},
	"trap_spotted": {title = "A TRAP!", calm = true, pages = [
		{t = "Heroes notice hidden traps with their passive Perception (10 + Perception) when they come close. A known trap is marked in red and the party walks around it.\n\nClick it to try to disarm it: the Rogue uses thieves' tools, the others their DEX. Fail by 5 or more and it goes off. Disarming gives XP."},
		{h = "SEARCHING", at = R_BUTTONS, t = "Search (F or the Search button): everyone looks around and the best Perception or Investigation roll is checked against hidden traps and secret doors within 5 squares.\n\nIt costs nothing, so search wherever something feels wrong."},
	]},
	"trap_sprung": {title = "IT'S A TRAP!", calm = true, pages = [
		{t = "Nobody spotted that one. Some traps attack (a roll against the hero's AC); others call for a saving throw (a d20 + an ability, often DEX, against the trap's DC: success = half damage or none).\n\nOutside a fight a trap can't kill. Search (F) where traps seem likely."},
	]},
	"secret_door": {title = "A SECRET DOOR", calm = true, pages = [
		{t = "It looked like plain wall until a hero noticed it (passive Perception, or a Search). Click the glinting seam to open it.\n\nSome hidden doors only open by a lever or a puzzle. Hidden places hold optional treasure."},
	]},
	"puzzle": {title = "A PUZZLE", calm = true, pages = [
		{t = "Levers, pressure plates, braziers and stone blocks are parts of puzzles. Click a lever to pull it, a brazier to light or douse it, a block to push it away from the hero.\n\nThe clues are in the room descriptions and inscriptions (the log keeps them). Puzzles guard optional treasure, never the way on, and solving one gives XP."},
	]},
	"riddle": {title = "A RIDDLE", pages = [
		{t = "Pick an answer by clicking it or pressing its number (1-4). A wrong answer has a price, but you can try again. Esc walks away."},
	]},
	"lore": {title = "THE JOURNAL", calm = true, pages = [
		{t = "Books, tablets and notes the party reads are kept in the journal: open the quest log (J) and its Journal page to read them again."},
	]},
	"ambush": {title = "AMBUSH!", pages = [
		{t = "Monsters were lying in wait. Sometimes a gate slams down behind the party: it rises again once they're all dead."},
	]},
	"talk": {title = "TALKING", pages = [
		{t = "Click a choice, or press its number (1-4). Space finishes the line at once; Esc says goodbye."},
	]},
	"shop": {title = "TRADING", pages = [
		{t = "Click an item in the trader's wares or in your bag, then Buy or Sell (or double-click it). You buy at the full price and sell at half.\n\nKeys and quest items can't be sold."},
	]},
	"quest": {title = "QUESTS", calm = true, pages = [
		{t = "The quest log (J or the Quest button) lists what is done and what comes next, for the main quest and any side quests. Its Journal page keeps what the party has read."},
	]},
	"rune": {title = "THE RUNE OF RETURN", calm = true, pages = [
		{t = "Click the Rune in the Bag (I) while exploring: a portal opens next to the party and leads to the trader. The portal there brings you back to the same spot, then closes.\n\nIt never runs out, but only one portal can be open at a time."},
	]},
	"stairs": {title = "A NEW PLACE", calm = true, pages = [
		{t = "Stairs and openings lead to other maps (click them; not in a fight). HP, spell slots and the bag go with the party, and every place remembers what was opened, found and killed.\n\nA good moment to save: F5 quick save, F6 save slots."},
	]},
	"class_fighter": {title = "THE FIGHTER", pages = [
		{at = "focus", t = "The front line: heavy armour, the most HP, and a good weapon. Stand between the monsters and the Mage.\n\nSecond Wind (a bonus action) heals the Fighter; Shove knocks a foe prone or pushes it away. More attacks and tricks come with levels."},
	]},
	"class_rogue": {title = "THE ROGUE", pages = [
		{at = "focus", t = "Sneak Attack: once a turn, extra damage when the Rogue has advantage, or when an ally stands next to the target. Hide gives advantage on the next attack.\n\nThe Rogue also picks locks and disarms traps."},
	]},
	"class_cleric": {title = "THE CLERIC", pages = [
		{at = "focus", t = "The healer. Cure Wounds (touch) and Healing Word (at range, a bonus action) heal and get downed heroes back up. Bless helps the party hit and save; Sacred Flame is a free radiant attack.\n\nKeep a spell slot or two for healing."},
	]},
	"class_mage": {title = "THE MAGE", pages = [
		{at = "focus", t = "Powerful but fragile: keep the Mage behind the others. Fire Bolt is free (a cantrip), Magic Missile never misses, and Shield (a reaction) can turn a hit into a miss.\n\nBigger spells come with levels: Fireball at level 5."},
	]},
}
