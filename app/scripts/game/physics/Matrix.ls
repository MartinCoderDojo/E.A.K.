require! 'game/physics/Vector'

# Basic 2D-matrix class.
# Matrices are in the form:
# ⎡a b⎤
# ⎣c d⎦
module.exports = class Matrix
  (a, b, c, d) ->
    @ <<< {a, b, c, d}
    @from = new Vector a, c
    @to = new Vector b, d

  invert: ~>
    x = 1 / @determinant!
    new Matrix x * @d, -x * @b, -x * @c, x * @a

  determinant: ~> @a * @d - @b * @c

  # Transform a vector by this matrix:
  # ⎡a b⎤⎡x⎤ = ⎡x·a + y·b⎤
  # ⎣c d⎦⎣y⎦   ⎣x·c + y·d⎦
  transform: ({x, y}) ~> new Vector x * @a + y * @b, x * @c + y * @d
