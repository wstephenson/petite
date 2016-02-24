Game loop (in progress)

Player object(persistent over state)
 Ship damage (in progress)
 Ship death
  Animation after death
 Ship fuel (in progress)
 Rank
 Score (done)
Fuel scooping (done)
 Rate dependent on velocity and distance to star (done)
Stellar heating (needs balance)
 Rate dependent on distance to star (done)
 Heat according to inverse square of distance to star (done)
UI for when docked (in progress)
 Switch pages
  XOR cursor (done)
 Trading
 Ship repair (in progress)
 Ship upgrade
Galaxy map
 Select next system to jump to (galaxy map) (done)
 Show econ type on map (done)
NPC AI
 Pirates that attack you
 Traders that just travel from entry point to station
Local scanner
Scoring (in progress)
 System score
 Kill score
 Scoop score
Player alignment (like score)
 (-1 to +1 scale based on actions)
 controls ability to dock at stations
Galaxy map
 Blank cells for unknown systems
Procedural system generation, not just random (in progress)
 Planet colour (done)
 Planet size (done)
 Vary palette according to system type (sort of done)
Hyperjump to a new system (nearly done)
 Limit jump range 
Planet/sun/station collisions
Weapon/health/shield/heat balancing
Real system scenarios 
 Cargo/ore scooping
Trading (in progrss)
Scoring (done)
 UI for showing score items (done)
 Array of score items that are assessed on state change (done)
 Feedback on trading profits (done)
Contraband cargo
Sort out system coordinate confusion (done)

Statistics screen on death
Start screen/attract mode (done)
SFX


Trading engine notes
====================
Trading carried out automatically on docking
Trade value depends on cargo type and station docked at
Cargo type depends on origin system
There is a table matching source and destination system
So we need to define system types
Agri/Tech/
SRC-----DEST----VALUE
HI	HI	$
"	LO	$$
"	C	$$$
LO	HI	$$
"	LO	$
"	C	$$$
CONTRA	HI	0
"	LO	0
"	C	0

Logic: Anarchy systems produce nothing so pay out high prices for imports.  However you collect no cargo on the outward leg. This is offset by the opposition you should face there, and the bounties to be earned.

# System characteristics and PG data footprint
* Star size 4 bits
* Star class (BH,PUR,RED,YEL,WHT,BL) = 6 = 4 bits needed
* Planet radius 4  - could take either of the x,y coords and split
* Planet colour(GRND,GRNL,BRN,GRYD,GRYL,RED,YEL,BLU,PNK,SKIN
*  or color1,color2 = 10 = 4 bits
* Economy 3 bits)

On docking in system: 
If cargo flag set
  Award cargo value\*ship size points 
  Unset cargo flag
Set cargo flag to current system type

