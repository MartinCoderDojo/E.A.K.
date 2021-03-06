map = (fn, arr) --> _.map arr, fn

const available-kittens = 5

parse-targets = ->
  it / ',' |> map (
    -> it.trim! / ' ' |> map (
      -> it.trim! |> parse-float))
  |> map (-> x: it.0, y: it.1)

random-kitten = ->
  "url('/content/kittens/kitten-#{ (Math.random! * available-kittens |> Math.floor) + 1 }.gif')"

random-kitten-el = ->
  $ '<div></div>'
    ..css 'background-image', random-kitten!
    ..add-class 'kitten-anim'

box-burst-sprite = ->
  $ '<div></div>'
    ..attr {
      'data-sprite': '/content/sprites/kitten-box-burst.png'
      'data-sprite-start-frame': 0
      'data-sprite-frames': 14
      'data-sprite-loop': 1
      'data-sprite-state': 'paused'
      'data-sprite-size': '48x52'
      'data-sprite-speed': '0.025'
    }
    ..css 'display' 'none'
    ..add-class 'box-burst'

blink-sprite = ->
  $ '<div></div>'
    ..attr {
      'data-sprite': '/content/sprites/kitten-box-blink.png'
      'data-sprite-frames': 10
      'data-sprite-size': '48x52'
      'data-sprite-speed': '0.025'
      'data-sprite-delay': '0.1-6'
    }
    ..add-class 'box-blink'

module.exports = (container, targets) -->
  targets = parse-targets targets

  cx = container.width / 2
  cy = container.height / 2

  for target in targets

    el = $ '<div></div>'
      ..add-class 'entity entity-target'
      ..attr {
        'data-sensor': true
        'data-id': 'ENTITY_TARGET'
        'data-target': true

      }
      ..css do
        left: target.x + cx
        top: target.y + cy
      ..append random-kitten-el!
      ..append box-burst-sprite!
      ..append blink-sprite!
      ..append-to container.el
