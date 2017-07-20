
# 数据模型类: 矩形
class Rectangle
  constructor: (left, top, width, height, @id) ->
    @reset left, top, width, height

  reset  : (@left, @top, @width, @height) ->
    @right = @left + @width
    @bottom = @top + @height
    @area = @width * @height
    return

  # returns true if rectangle a is contained in rectangle b.
  contains : (rect)->
    return rect.left >= @left and rect.right <= @right and rect.top >= @top and rect.bottom <= @bottom

  shrink : (num) ->
    @left += num
    @top += num
    @right -= num
    @bottom -= num
    num = num * 2
    @width -= num
    @height -= num
    @area = @width * @height


  toString : -> "[Rect(id:#{@id}, left:#{@left}, top:#{@top}, w:#{@width}, h:#{@height})]"

exports = module.exports
exports.Rectangle = Rectangle

