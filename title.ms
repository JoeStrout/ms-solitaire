clear
Sound.stopAll

bgm = file.loadSound("sounds/rivers-of-france-loop.ogg")
bgm.loop = true

if not globals.hasIndex("easyMode") then
	easyMode = true
end if
if not globals.hasIndex("musicOn") then
	musicOn = true
end if

if musicOn then bgm.play 0.75

title = file.loadImage("pics/Title.png")
gfx.drawImage title, 480 - title.width/2, 640 - title.height

loadSprite = function(x, y, imageName, imageName2)
	spr = new Sprite
	spr.image1 = file.loadImage("pics/" + imageName + ".png")
	if imageName2 != null then
		spr.image2 = file.loadImage("pics/" + imageName2 + ".png")
	else
		spr.image2 = null
	end if
	spr.image = spr.image1
	spr.x = x
	spr.y = y
	spr.localBounds = new Bounds
	spr.localBounds.width = spr.image.width
	spr.localBounds.height = spr.image.height
	display(4).sprites.push spr
	return spr
end function

Switch = {}

Switch.add = function(label, opt1, opt2, y, whichOn=0)
	sw = new Switch
	sw.y = y
	sw.label = loadSprite(342, y, label)
	sw.opt1 = loadSprite(534, y, opt1 + "-Off", opt1 + "-On")
	sw.slash = loadSprite(600, y, "Slash")
	sw.opt2 = loadSprite(678, y, opt2 + "-Off", opt2 + "-On")
	return sw
end function

Switch.selectLeft = function(leftOn)
	if leftOn then
		self.opt1.image = self.opt1.image2
		self.opt2.image = self.opt2.image1
	else
		self.opt1.image = self.opt1.image1
		self.opt2.image = self.opt2.image2
	end if
end function

difficultyY = 300
musicY = 248

diffSwitch = Switch.add("Difficulty", "Easy", "Hard", difficultyY, 0)
musicSwitch = Switch.add("Music", "Off", "On", musicY, 1)
playBtn = loadSprite(480, 128, "PlayButton-Up", "PlayButton-Down")

diffSwitch.selectLeft easyMode
musicSwitch.selectLeft not musicOn

while true
	yield
	if not mouse.button then continue
	if abs(mouse.y - diffSwitch.y) < 18 then
		easyMode = not easyMode
		diffSwitch.selectLeft easyMode
	else if abs(mouse.y - musicSwitch.y) < 18 then
		musicOn = not musicOn
		musicSwitch.selectLeft not musicOn
		if musicOn then bgm.play 0.75 else bgm.stop
	else if playBtn.contains(mouse) then
		while mouse.button
			yield
			if playBtn.contains(mouse) then
				playBtn.image = playBtn.image2
			else 
				playBtn.image = playBtn.image1
			end if
		end while
		if playBtn.image == playBtn.image2 then break
	end if
	while mouse.button; yield; end while
end while

run "solitaire"
