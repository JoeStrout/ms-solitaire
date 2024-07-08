// Klondike Solitaire

import "listUtil"
import "mathUtil"

//----------------------------------------------------------------------
// Constants
//----------------------------------------------------------------------
STOCKPOS = {"x":80, "y":520}
WASTEPOS = {"x":220, "y":STOCKPOS.y}
WASTEOFFSET = 30	// how much the cards sperad out from WASTEPOS
FOUNDATIONPOS = {"x": 430, "y":STOCKPOS.y}
FOUNDATIONOFFSET = 150
TABLEAUPOS = {"x":70, "y":320}
TABLEAUOFFSET = 137
// Sadly, the built-in cards are just a little too big for Klondike
// on the Mini Micro screen.  So we'll use these slighly smaller ones:
CARDPICS = "pics/cards-120/"

//----------------------------------------------------------------------
// Globals
//----------------------------------------------------------------------
stock = []  // stock pile (from which cards are drawn)
waste = []	// waste pile (drawn cards; top one is playable)
foundations = [[], [], [], []] // pile of cards on each of 4 foundations
tabs = [[], [], [], [], [], [], []] // tableau piles
quitting = false	// set to true to quit the game
lifted = []
sourcePile = null
if not globals.hasIndex("easyMode") then easyMode = true


//----------------------------------------------------------------------
// Import and extend the CardSprite class from /sys/demo/cardFlip.
//----------------------------------------------------------------------
if not env.importPaths.contains("/sys/demo") then
	env.importPaths.push "/sys/demo"
end if
import "cardFlip"
Card = new cardFlip.CardSprite
Card.image = file.loadImage(CARDPICS + "cardClubsA.png")
Card.localBounds.width = Card.image.width
Card.localBounds.height = Card.image.height
Card.curSound = null

Card.flipSounds = []
Card.arriveSounds = []
for i in range(1,3)
	Card.flipSounds.push file.loadSound("sounds/cardPlace" + i + ".ogg")
	Card.arriveSounds.push file.loadSound("sounds/cardSlide" + i + ".ogg")
end for

Card.playSound = function(sound)
	self.curSound = sound
	sound.play 1, (self.x - 480) / 400, 0.9 + rnd*0.2
end function

Card.update = function(dt=0.016)
	d = self.distToTarget
	if d > 0 and d < self.speed.xy * dt and self.curSound == null then
		self.playSound self.arriveSounds.any
	end if
	prevFaceUp = self.faceUp
	
	super.update dt

	if self.faceUp != prevFaceUp then
		if (self.faceUp < 0.5) != (prevFaceUp < 0.5) and self.curSound == null then
			self.playSound self.flipSounds.any
		end if
	end if
	if self.curSound != null and not self.curSound.isPlaying then
		self.curSound = null
	end if
end function

Card.distToTarget = function
	if not self.target.hasIndex("x") then return 0
	return mathUtil.distance(self, self.target)
end function

Card.goToInSecs = function(x, y, seconds)
	if seconds <= 0 then
		self.x = x
		self.y = y
		return
	end if
	self.target = {"x":x, "y":y}
	self.speed.xy = self.distToTarget / seconds
end function

Card.goToAtSpeed = function(x, y, speed=1000)
	self.target = {"x":x, "y":y}
	self.speed.xy = speed
end function

Card.goTo = function(x, y)
	self.goToAtSpeed x, y, 1000
end function

Card.jumpTo = function(x, y)
	self.goToInSecs x, y, 0
end function

Card.moveToFront = function
	cards.removeVal self
	cards.push self
end function

Card.canGoOnFoundation = function(index)
	topCard = null
	if foundations[index] then
		// can add to foundation if it matches in suit, and one greater in rank
		topCard = foundations[index][-1]
		return self.suit == topCard.suit and self.rankVal == topCard.rankVal + 1
	else
		// only Ace can go on empty foundation
		return self.rank == "A"
	end if
end function

Card.canGoOnTab = function(index)
	topCard = null
	if tabs[index] then
		// add to tab if opposite color, and one less in rank
		topCard = tabs[index][-1]
		return self.red != topCard.red and self.rankVal == topCard.rankVal - 1
	else
		// only King can go on an empty tab
		return self.rank == "K"
	end if
end function

Card.name = function
	return self.rank + " of " + self.suit
end function

updateCards = function
	for sp in cardDisp.sprites
		sp.update
	end for
end function

waitButUpdate = function(delay = 1)
	t1 = time + delay
	while time < t1
		updateCards
		yield
	end while
end function

createDeck = function
	Card.backImage = file.loadImage(CARDPICS + "cardBack_blue4.png")
	outer.cards = cardDisp.sprites
	// create the cards
	ranks = ["A"] + range(2,10) + ["J", "Q", "K"]
	for suit in "Clubs Diamonds Hearts Spades".split
		for rank in ranks
			card = new Card
			card.speed = Card.speed + {}
			card.frontImage = file.loadImage(CARDPICS + "card" + suit + rank + ".png")
			card.rank = rank
			card.rankVal = 1 + ranks.indexOf(rank)
			card.suit = suit
			card.red = (suit == "Diamonds" or suit == "Hearts")
			card.black = not card.red
			cards.push card
		end for
	end for

	// shuffle 'em, and start them all in the stock pile, face down
	cards.shuffle
	outer.stock = cards[:]
	for card in cards
		card.jumpTo STOCKPOS.x, STOCKPOS.y
		card.faceUp = false
	end for
end function

Well = new Sprite
Well.tint = "#FFFFFF44"
Well.update = function(dt); end function
Well.image = file.loadImage("pics/emptyWell.png")
Well.localBounds = new Bounds
Well.localBounds.width = Well.image.width
Well.localBounds.height = Well.image.height

createWells = function
	globals.stockWell = new Well
	stockWell.image = file.loadImage("pics/redoWell.png")
	stockWell.x = STOCKPOS.x
	stockWell.y = STOCKPOS.y
	wellDisp.sprites.push stockWell
	globals.foundationWells = []
	cardWellPic = file.loadImage("pics/cardWell.png")
	for i in range(0,3)
		well = new Well
		well.image = cardWellPic
		well.x = FOUNDATIONPOS.x + FOUNDATIONOFFSET * i
		well.y = FOUNDATIONPOS.y 
		foundationWells.push well
		wellDisp.sprites.push well
	end for
	globals.tableauWells = []
	for i in range(0,7)
		well = new Well
		well.x = TABLEAUPOS.x + TABLEAUOFFSET * i
		well.y = TABLEAUPOS.y
		tableauWells.push well
		wellDisp.sprites.push well		
	end for
end function

dealTableau = function
	for t in range(0, 6)
		tabs[t] = []
		for i in range(0, t)
			card = stock.pop
			card.goToAtSpeed TABLEAUPOS.x + TABLEAUOFFSET * t,
			  TABLEAUPOS.y - 15 * i, 1000
			card.target.faceUp = (i == t)
			card.moveToFront
			tabs[t].push card
		end for
	end for
end function

draw = function(numToDraw = 3)
	for i in range(1, numToDraw)
		if not stock then return	// out of cards!
		card = stock.pop
		if not waste then
			x = WASTEPOS.x
		else if waste.len < 3 then
			x = waste[-1].target.x + WASTEOFFSET
		else
			// (shove existing waste cards over, exposing only the top 3)
			for w in waste; w.target.x = WASTEPOS.x; end for
			waste[-1].target.x += WASTEOFFSET
			x = waste[-1].target.x + WASTEOFFSET
		end if
		waste.push card
		card.goToInSecs x, WASTEPOS.y, 0.5
		card.target.faceUp = true
		card.moveToFront
		waitButUpdate 0.25
	end for
end function

restock = function
	for card in waste
		card.goToInSecs WASTEPOS.x, WASTEPOS.y, 0.25
	end for
	waitButUpdate 0.2
	while waste
		card = waste.pop
		card.goToInSecs STOCKPOS.x, STOCKPOS.y, 0.5
		card.target.faceUp = false
		card.moveToFront
		stock.push card
	end while
end function

processKey = function(k)
	if k == char(13) or k == char(10) or k == char(3) then // enter/return
		if stock then
			draw
		else
			restock
		end if
	end if
	if k == char(27) then globals.quitting = true
end function

revealNextOfSourcePile = function
	for tab in tabs
		if refEquals(tab, sourcePile) and tab then
			waitButUpdate 0.2
			tab[-1].target.faceUp = true
		end if
	end for
end function

placeOnFoundation = function(which)
	fw = foundationWells[which]
	card = lifted[0]
	card.goToAtSpeed fw.x, fw.y, 3000
	card.moveToFront
	foundations[which].push card
	revealNextOfSourcePile
	if checkForWin then
		showWin
		run "title"
	end if
end function

placeOnTableau = function(which)
	x  = tableauWells[which].x; y = tableauWells[which].y
	if tabs[which] then y = tabs[which][-1].y - 24
	for c in lifted
		c.goToAtSpeed x, y, 3000
		c.moveToFront
		tabs[which].push c
		y -= 20
	end for
	revealNextOfSourcePile
end function

autoplaceCard = function(card)
	// Try the foundations (if we have a single card)
	if lifted.len < 2 then
		for i in foundations.indexes
			if card.canGoOnFoundation(i) then
				placeOnFoundation i
				return
			end if		
		end for
	end if
	// Try the tabs -- and move all lifted cards
	for i in tabs.indexes
		if refEquals(tabs[i], sourcePile) then continue
		if card.canGoOnTab(i) then
			placeOnTableau i
			return
		end if
	end for
	// Can't do either of the above?  Put them back where they came from.
	putDownCards
end function

pickUpCards = function(card)
	while lifted
		waitButUpdate 0.1
	end while
	
	// Pick up the given card, and any cards on top of it in the tableau.
	// Store these in global `lifted`, and source pile as `sourcePile`.
	if waste and waste[-1] == card then
		// Just lifting one card, from the waste.
		globals.lifted = [card]
		globals.sourcePile = waste
		waste.pop
		return
	end if
	for tab in tabs
		idx = tab.indexOf(card)
		if idx == null then continue
		globals.lifted = tab[idx:]
		globals.sourcePile = tab
		while tab.len > idx; tab.pop; end while		
	end for
	for card in lifted
		card.y += 10
		card.moveToFront
	end for
end function

moveCards = function(dx, dy)
	for card in lifted
		card.x += dx
		card.y += dy
	end for
end function

putDownCards = function
	// Just put the cards back down where they came from
	for card in lifted
		card.y -= 10
		card.speed.xy = 4000  // (fly back quickly)
		sourcePile.push card
	end for
	globals.lifted = []
end function

dropCardsOnNewStack = function
	// If we have just a single card, consider the foundation piles
	card = lifted[0]
	if lifted.len == 1 and card.y > FOUNDATIONPOS.y - 100 then
		which = round((card.x - FOUNDATIONPOS.x) / FOUNDATIONOFFSET)
		if 0 <= which < foundationWells.len and card.canGoOnFoundation(which) then
			placeOnFoundation which
			return		
		end if
	end if
	
	// Otherwise, consider each of the tableau piles.
	which = round((card.x - TABLEAUPOS.x) / TABLEAUOFFSET)
	if 0 <= which < tabs.len and card.canGoOnTab(which) then
		placeOnTableau which
		return	
	end if
	
	// Failed the above?  Just put back down where they came from.
	putDownCards
end function

checkForWin = function
	for f in foundations
		if not f or f[-1].rank != "K" then return false
	end for
	return true
end function

waitForMouseUp = function
	while mouse.button; yield; end while
end function

clickDragCard = function(card)
	if stock.contains(card) then
		waitForMouseUp
		draw 1 + 2 * (not easyMode)
		return
	end if
	if not card.faceUp then return
	for f in foundations; if f.contains(card) then return waitForMouseUp; end for
	
	timeDown = time
	pickUpCards card

	oldMousePos = {"x":mouse.x, "y":mouse.y}	
	while mouse.button
		yield
		moveCards mouse.x - oldMousePos.x, mouse.y - oldMousePos.y
		oldMousePos = {"x":mouse.x, "y":mouse.y}	
	end while

	timeUp = time
	if card.distToTarget > 20 then
		dropCardsOnNewStack
	else if timeUp - timeDown < 0.5 then
		autoplaceCard card
	else
		putDownCards
	end if
	globals.lifted = []
end function

processMouse = function
	if not mouse.button then return
	for i in range(cards.len-1, 0, -1)
		card = cards[i]
		globals.cardHit = card
		if card.contains(mouse) then
			clickDragCard card
			return
		end if
	end for
	if not stock and stockWell.contains(mouse) then
		while mouse.button; yield; end while
		restock
	end if
end function

processInput = function
	if key.available then processKey key.get
	if mouse.button then processMouse	
end function

showWin = function
	file.loadSound("/sys/sounds/fanfare.wav").play
	waitButUpdate 0.5
	spr = new Sprite
	spr.update = function(dt); end function
	spr.image = file.loadImage("pics/YouWin.png")
	spr.x = 480; spr.y = 400
	spr.scale = 0.1
	cardDisp.sprites.push spr
	while spr.scale < 1.2
		spr.scale *= 1.08
		waitButUpdate 0.01
	end while
	while spr.scale > 1
		spr.scale *= 0.92
		waitButUpdate 0.01
	end while
	spr.scale = 1
	waitButUpdate 0.5
	text.row = 0; text.column = 25
	text.color = "#88FF88"
	print "Click to continue.", ""
	while not mouse.button; waitButUpdate 0.01; end while
	waitForMouseUp
end function

setup = function
	clear
	globals.cardDisp = display(4)
	cardDisp.clear
	display(5).mode = displayMode.sprite
	globals.wellDisp = display(5)
	wellDisp.clear
	display(7).color = color.green
	createWells
	createDeck
	dealTableau
end function

main = function
	while not quitting
		yield
		updateCards
		processInput
	end while
end function

setup
main
run "title"
