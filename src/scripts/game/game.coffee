Level = require "game/level"

mediator = require "game/mediator"

module.exports = class Game extends Backbone.Model
  initialize: (load) ->
    if load then @load() else @save()

    @on "change", @save

    @$levelTitle = $ ".levelname"
    @$levelNo = @$levelTitle.find "span"
    @$levelName = @$levelTitle.find "h4"

    @startLevel @get "level"

  defaults:
    level: 0

  startLevel: (n) =>
    console.log n
    if mediator.LevelStore[n] is undefined
      console.log "Cannot find level #{n}", mediator.LevelStore
      mediator.trigger "alert", "That's it! I haven't coded any more levels yet."
      return false

    level = mediator.LevelStore[n]
    @$levelNo.text n+1

    if level.config is undefined or level.config.name is undefined
      @$levelName.text ""
    else
      @$levelName.text level.config.name

    @$levelTitle.makeOnlyShownDialogue()

    setTimeout =>
      @$levelTitle.hideDialogue()
      level = new Level level
      mediator.once "levelout", =>
        console.log "levelout"
        l = (@get "level") + 1
        @set "level", l
        @startLevel l
    , 1300

  save: =>
    console.log "Saving to local storage"
    attrs = _.clone @attributes
    localStorage.setItem Game::savefile, JSON.stringify attrs

  load: =>
    attrs = JSON.parse localStorage.getItem Game::savefile
    @set attrs

  savefile: "web-platform-savegame"
