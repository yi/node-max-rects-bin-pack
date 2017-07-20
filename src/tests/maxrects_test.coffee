require 'mocha'
should = require('chai').should()
mock_data = require "./mock_data"
{MaxRects} = require "../maxrects"
{Rectangle} = require "../rectangle"


r123 = new Rectangle 10, 10, 100, 100, "r123"
r1 = new Rectangle 20, 20, 10, 20, "r1"
r2 = new Rectangle 70, 13, 20, 70, "r2"
r3 = new Rectangle 70, 30, 10, 30, "r3"
r4 = new Rectangle 700, 300, 100, 300, "r4"
r5 = new Rectangle 1700, 3000, 780, 1340, "r5"
r6 = new Rectangle 750, 500, 10, 40, "r6"
r7 = new Rectangle 760, 500, 30, 40, "r7"
r8 = new Rectangle 2000, 3200, 80, 340, "r8"

describe "in Rectangle class", ->
  describe "Rectangle", ->

    it "should be inited correctly", ->
      x = 11
      y = 77
      w = 123
      h = 9
      r = new Rectangle x, y, w, h, "name"
      r.left.should.equal x
      r.top.should.equal y
      r.right.should.equal x + w
      r.bottom.should.equal y + h
      r.width.should.equal w
      r.height.should.equal h
      r.area.should.equal w * h
      r.id.should.equal "name"
      console.log "r:#{r}"

    it "should be shrinked correctly", ->
      x = 11
      y = 77
      w = 123
      h = 9
      p = 2
      r = new Rectangle x, y, w, h, "name"
      r.shrink p
      r.left.should.equal x + p
      r.top.should.equal y + p
      r.right.should.equal x + w - p
      r.bottom.should.equal y + h - p
      r.width.should.equal w - p * 2
      r.height.should.equal h - p * 2
      r.area.should.equal (w - p * 2) * (h - p * 2)
      console.log "r:#{r}"

describe "in MaxRects class", ->
  describe "MaxRects.pruneFreeList", ->
    it "should work correctly", ->
      r2.contains(r3).should.be.true
      r123.contains(r1).should.be.true
      r123.contains(r2).should.be.true
      r123.contains(r3).should.be.true
      r1.contains(r3).should.not.be.true
      console.log "r123:#{r123}\tr1:#{r1}\tr2:#{r2}\tr3:#{r3}"

      m = new MaxRects

      # test 1
      m.freeRectangles = [r1, r123, r2, r3]
      m.pruneFreeList()
      m.freeRectangles.should.include r123
      m.freeRectangles.should.not.include.members [r1, r2, r3]

      # test 2
      m.freeRectangles = [r1, r3]
      m.pruneFreeList()
      m.freeRectangles.should.include.members [r1, r3]
      m.freeRectangles.should.not.include.members [r123, r2]

      # test 3
      m.freeRectangles = [r1, r2, r3]
      m.pruneFreeList()
      m.freeRectangles.should.include.members [r1, r2]
      m.freeRectangles.should.not.include.members [r123, r3]

      # test 1
      m.freeRectangles = [r4, r5, r123, r6, r2, r3, r1, r7, r8]
      m.pruneFreeList()
      console.log "m.freeRectangles: #{m.freeRectangles}"

      m.freeRectangles.should.include.members [r4, r5, r123]
      m.freeRectangles.should.not.include.members [r1, r2, r3, r6, r7,r8]

  describe "MaxRects.calc", ->

    it "should work correctly with small sample", (done) ->
      m = new MaxRects
      m.calc [r4, r5, r123, r6, r2, r3, r1, r7, r8], (err, result)->
        console.log "[maxrects_test::small::callback from MaxRects.calc] err:#{err}, result:#{result}"
        #console.dir result
        should.not.exist err
        done()

    it "should fail on very large sample", (done) ->
      this.timeout(300000)
      m = new MaxRects
      m.calc mock_data, (err, result)->
        console.log "[maxrects_test::large::callback from MaxRects.calc] err:#{err}, result:#{result}"
        #console.dir result
        should.exist err
        done()

    it "should success on very large sample when enableMultiArrangment", (done) ->
      this.timeout(300000)
      m = new MaxRects
      m.enableMultiArrangment = true
      m.calc mock_data, (err, result)->
        console.log "[maxrects_test::large::callback from MaxRects.calc] err:#{err}, result:#{result}"
        #console.dir result
        should.not.exist err
        Array.isArray(result).should.be.true
        done()









