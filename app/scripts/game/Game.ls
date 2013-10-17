require! {
  'game/Level'
  'game/Bar'
  'game/Background'
  'game/mediator'
}

module.exports = class Game extends Backbone.Model
  initialize: (load) ->
    if load then @load! else @save!

    @on \change @save

    background = new Background!

    @$level-title = $ \.levelname
    @$level-no = @$level-title.find \span
    @$level-name = @$level-title.find \h4

    bar-view = new Bar el: $ \#bar

  defaults: level: '/levels/index.html'

  start-level: (l) ~>
    level-source <~ $.get l, _
    parsed = Slowparse.HTML document, level-source, [TreeInspectors.forbidJS]

    if parsed.error isnt null
      mediator.trigger 'alert', 'There are errors in that level!'
      console.log parsed
      return

    $level = $ parsed.document.children.0

    console.log ($level.find 'title' .text!)
    @$level-name.text ($level.find 'title' .text! or '')

    <~ $.hide-dialogues

    new Level $level

    mediator.once \levelout, ~>
      l = (@get \level) + 1
      @set \level, l
      @start-level l

  save: ~> @attributes |> _.clone |> JSON.stringify |> local-storage.set-item Game::savefile, _

  load: ~> Game::savefile |> local-storage.get-item |> JSON.parse |> @set

  savefile: \kittenquest-savegame
