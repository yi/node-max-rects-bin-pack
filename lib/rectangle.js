// Generated by CoffeeScript 1.8.0
(function() {
  var Rectangle, exports;

  Rectangle = (function() {
    function Rectangle(left, top, width, height, id) {
      this.id = id;
      this.reset(left, top, width, height);
    }

    Rectangle.prototype.reset = function(left, top, width, height) {
      this.left = left;
      this.top = top;
      this.width = width;
      this.height = height;
      this.right = this.left + this.width;
      this.bottom = this.top + this.height;
      this.area = this.width * this.height;
    };

    Rectangle.prototype.contains = function(rect) {
      return rect.left >= this.left && rect.right <= this.right && rect.top >= this.top && rect.bottom <= this.bottom;
    };

    Rectangle.prototype.shrink = function(num) {
      this.left += num;
      this.top += num;
      this.right -= num;
      this.bottom -= num;
      num = num * 2;
      this.width -= num;
      this.height -= num;
      return this.area = this.width * this.height;
    };

    Rectangle.prototype.toString = function() {
      return "[Rect(id:" + this.id + ", left:" + this.left + ", top:" + this.top + ", w:" + this.width + ", h:" + this.height + ")]";
    };

    return Rectangle;

  })();

  exports = module.exports;

  exports.Rectangle = Rectangle;

}).call(this);
