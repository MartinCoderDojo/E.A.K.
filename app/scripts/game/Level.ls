require! {
  'channels'
  'game/background'
  'game/dom/Mapper'
  'game/editor/Editor'
  'game/editor/EditorView'
  'game/event-loop'
  'game/hints/HintController'
  'game/physics'
  'game/Player'
  'game/Renderer'
  'game/Targets'
  'loader/ElementLoader'
  'loader/LoaderView'
  'logger'
}

{map, reduce} = _

module.exports = class Level extends Backbone.Model
  initialize: (level) ->
    @subs = []
    @level = level
    conf = @conf = {}

    # Set up the HTML/CSS for the level
    conf.html = level.find 'body' .html!
    conf.css = level.find 'style' |> map _, (-> $ it .text!) |> join '\n\n'

    # Should we display the top bar?
    editable-str = (level.find 'meta[name=editable]' .attr \value) or 'true'
    if editable-str.trim!.to-lower-case! is 'false'
      editable = false
    else editable = true
    @editable = editable

    offs = if editable then 50 else 0
    renderer = @renderer = new Renderer {
      html: conf.html
      css: conf.css
      root: $ \#levelcontainer
    }, offs

    # Find the background image
    bg = if level.find 'meta[name=background]' .attr \value then that else 'white'
    renderer.el.style.background = bg
    @conf.background = bg

    # Background overlay color:
    bg-overlay = if level.find 'meta[name=bg-overlay]' .attr \value then that else null

    # Set the level size
    if size = level.find 'meta[name=size]' .attr \value
      [w, h] = size / ' '
      w = parse-float w
      h = parse-float h
    else
      w = h = 100

    conf.width = w
    conf.height = h
    renderer.set-width w
    renderer.set-height h

    # Set player coordinates
    if player = level.find 'meta[name=player]' .attr \value
      [x, y] = player / ' '
      x = parse-float x
      y = parse-float y
    else
      x = y = 0

    # Set player colour
    colour = (level.find 'meta[name=player-color]' .attr \value) or 'black'

    conf.player = {x, y, colour}

    # Find borders
    if borders = level.find 'meta[name=borders]' .attr \value
      borders = borders / ' '
    else
      borders = <[ all ]>

    if borders.0 is 'all' then borders = <[ top bottom left right ]>
    if borders.0 is 'none' then borders = []

    conf.borders = borders

    # add-targets is a function that adds targets to Renderer.
    add-targets = Targets renderer

    if targets = level.find 'meta[name=targets]' .attr \value then add-targets targets

    'head hidden' |> level.find |> ( .children! ) |> ( .add-class 'entity' ) |> @renderer.append

    loader = new ElementLoader el: @renderer.$el
    loader-view = new LoaderView model: loader
    loader-view.hide-progress!
    loader-view.$el.append-to '#main > .app'

    loader-view.render!

    event-loop.pause!

    # Apply the blurred background image:
    <~ background.show bg, bg-overlay
    channels.game-commands.publish command: \loaded

    # Load sprite sheet animations:
    <~ renderer.setup-sprite-sheets

    do
      <~ loader.once 'done', _
      $.hide-dialogues!
      <~ set-timeout _, 600

      $ document.body .add-class \playing
      unless editable then $ document.body .add-class \hide-bar

      event-loop.resume!

      nodes = []
      @add-bodies-from-dom nodes
      @add-player nodes, conf.player
      @add-borders nodes, conf.borders

      state = @state = physics.prepare nodes

      @hint-controller = new HintController hints: (level.find 'head hints' .children!)

      if editable
        @subs[*] = channels.game-commands.filter ( .command is \edit ) .subscribe @start-editor
      @subs[*] = channels.game-commands.filter ( .command is \restart ) .subscribe @restart
      @subs[*] = channels.game-commands.filter ( .command is \stop ) .subscribe @complete
      @subs[*] = channels.frame.subscribe @frame

    loader.start!

  frame: (data) ~>
    # Run physics simulation / player input
    @state = physics.step @state, data.t

    # Emit events caused by the simulation
    physics.events @state, channels.contact

    @check-player-is-in-world!

  add-bodies-from-dom: (nodes) ~>
    @renderer.$el.find 'a[href]:not(.portal)' .attr 'data-id', 'HYPERLINK'
    @renderer.$el.find 'a[href].portal'
      ..attr 'data-id' 'PORTAL'
      ..attr 'data-sensor' 'data-sensor'

    # Build a map of some elements
    dom-map = @renderer.create-map!

    @dom-bodies = for shape in dom-map
      nodes[*] = shape
      shape.from-dom-map = true

  remove-DOM-bodies: ~>
    for node, i in @state.nodes when node.from-dom-map is true
      node.destroy!

  add-player: (nodes, player-conf) ~>
    if @player?
      nodes[*] = @player
      @player.prepared = false

    else
      player = new Player player-conf, @renderer.width, @renderer.height
      player.$el.append-to @renderer.$el
      player.id = "#{@renderer.el.id}-player"
      player.$el.attr id: player.id
      @player = player

      # Get starting positions
      @start-pos = player: player.el.get-bounding-client-rect!

      # Add player to physics
      nodes[*] = player

  restart: ~>
    logger.log 'restart', parent: @event-id
    @renderer.resize!
    @redraw-from @conf.html, @conf.css
    @player.reset!

  redraw-from: (html, css) ~>
    # Preserve entities
    entities = @renderer.$el.children \.entity .detach!

    @renderer.set-HTML-CSS html, css

    # Reset DOM bodies
    @remove-DOM-bodies!

    # Restore entities
    entities.append-to @renderer.$el

    nodes = []
    @add-bodies-from-dom nodes
    @add-player nodes, @conf.player
    @add-borders nodes, @conf.borders

    state = @state = physics.prepare nodes

  add-borders: (nodes, borders = []) ->
    if borders is \none then return
    if borders is \all then borders = top: true, right: true, left: true, bottom: true

    const t = 400px

    w = @w = @renderer.width
    h = @h = @renderer.height

    if 'top' in borders then nodes[*] = {
      type: 'rect'
      width: w * 2
      height: t
      x: 0
      y: -t / 2
      id: \BORDER_TOP
    }

    if 'bottom' in borders then nodes[*] = {
      type: 'rect'
      width: w * 2
      height: t
      x: 0
      y: h + t / 2
      id: \BORDER_BOTTOM
    }

    if 'right' in borders then nodes[*] = {
      type: 'rect'
      width: t
      height: h * 2
      x: w + t / 2
      y: 0
      id: \BORDER_RIGHT
    }

    if 'left' in borders then nodes[*] = {
      type: 'rect'
      width: t
      height: h * 2
      x: -t / 2
      y: 0
      id: \BORDER_LEFT
    }

  check-player-is-in-world: !~>
    pos = @player.p

    const xpad = 100, pad-top = 100, pad-bottom = 200

    unless (-xpad < pos.x < @w + xpad) and (-pad-top < pos.y < @h + pad-bottom)
      channels.death.publish cause: 'fall-out-of-world'

  complete: ({payload = {handled: false, callback: -> null}}) ~>
    # If a status object is passed, set 'handled' to true. This is so that if this was triggered
    # by an event, it can know whether or not to wait for callback. Kinda hacky.
    payload.handled = true
    callback = payload.callback or -> null

    if @stopped then return
    @stopped = true

    @trigger 'done'
    @hint-controller.destroy!

    $ document.body .remove-class 'playing hide-bar'
    @renderer.remove!

    delete @state
    @player.remove!
    channels.game-commands.publish command: \level-out
    for sub in @subs => sub.unsubscribe!
    @stop-listening!
    background.clear!
    callback!

  start-editor: ~>
    if $ document.body .has-class \editor then return

    edit-event = undefined
    logger.start 'edit', parent: @event-id, (event) -> edit-event := event

    # Put the play back where they started
    @player.reset!

    # Wait 2 frames so we can ensure that the player has reset before continuing
    <~ channels.frame.once
    <~ channels.frame.once

    event-loop.pause!

    @renderer.clear-transform!

    editor = new Editor {
      renderer: @renderer
      original-HTML: @conf.html
      original-CSS: @conf.css
    }

    editor-view = new EditorView model: editor, render-el: @renderer.$el, el: $ \#editor
    editor-view.render!
    editor-view.$el.append-to $ \#editor

    @renderer.editor = true
    @renderer.resize!

    @renderer.clear-transform!

    <~ editor.once \save _

    if edit-event then edit-event.stop!
    logger.log 'edit-finish', {
      html: editor.get \html
      css: editor.get \css
    }

    editor-view.restore-entities!
    editor-view.remove!
    @renderer.editor = false
    @renderer.resize!
    @redraw-from (editor.get \html), (editor.get \css)
    event-loop.resume!
