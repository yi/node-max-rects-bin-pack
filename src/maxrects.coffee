##
# maxrects
# https://github.com/yi/node-maxrects
#
# Copyright (c) 2013 yi
# Licensed under the MIT license.
##

_ = require "underscore"
{Rectangle} = require "./rectangle"
debuglog = require("debug")("maxrects")
assert = require "assert"

CALCULATION_FAILED = "failed"


# -BSSF: Positions the Rectangle against the short side of a free Rectangle into which it fits the best.
HEURISTIC_BEST_SHORT_SIDE_FIT = "BSSF"

# -BLSF: Positions the Rectangle against the long side of a free Rectangle into which it fits the best.
HEURISTIC_BEST_LONG_SIDE_FIT = "BLSF"

# -BAF: Positions the Rectangle into the smallest free Rectangle into which it fits.
HEURISTIC_BEST_AREA_FIT = "BAF"

# -BL: Does the Tetris placement.
HEURISTIC_BOTTOM_LEFT_RULE = "BL"

# -CP: Choosest the placement where the Rectangle touches other Rectangles as much as possible.
HEURISTIC_CONTACT_POINT_RULE = "CP"

# 提供算法轮动
HEURISTIC_RING_SINGLE_BIN = {}
HEURISTIC_RING_SINGLE_BIN[HEURISTIC_BEST_SHORT_SIDE_FIT] = HEURISTIC_BEST_LONG_SIDE_FIT
HEURISTIC_RING_SINGLE_BIN[HEURISTIC_BEST_LONG_SIDE_FIT] = HEURISTIC_BEST_AREA_FIT
HEURISTIC_RING_SINGLE_BIN[HEURISTIC_BEST_AREA_FIT] = HEURISTIC_BOTTOM_LEFT_RULE
HEURISTIC_RING_SINGLE_BIN[HEURISTIC_BOTTOM_LEFT_RULE] = HEURISTIC_CONTACT_POINT_RULE

# 提供算法轮动
HEURISTIC_RING_MULTI_BIN = {}
HEURISTIC_RING_MULTI_BIN[HEURISTIC_BEST_SHORT_SIDE_FIT] = HEURISTIC_BEST_LONG_SIDE_FIT
HEURISTIC_RING_MULTI_BIN[HEURISTIC_BEST_LONG_SIDE_FIT] = HEURISTIC_BEST_AREA_FIT
HEURISTIC_RING_MULTI_BIN[HEURISTIC_BEST_AREA_FIT] = HEURISTIC_BOTTOM_LEFT_RULE

MAX_BIN_WIDTH = 2048
MAX_BIN_HEIGHT = 2048
MAX_PADDING = 64
MAX_MARGIN = 64

# 计算 rect 列表的面积和
# @param {Array, {id, width, height}[]} rects
calcSurfaceArea = (rects)->
  result = 0
  for rect in rects
    result += rect.width * rect.height
  return result

# 计算 rect 列表被排布之后，在画布上所在的非空余面积的大小
calcOcupiedArea = (rects, binWidth, binHeight)->
  left = binWidth
  right = 0
  top = binHeight
  bottom = 0
  debuglog "[calcOcupiedArea] left:#{left}, right:#{right}, top:#{top}, bottom:#{bottom}"

  # 算出所有 rects 排布后所占区域的上下左右
  for rect in rects
    #debuglog "[calcOcupiedArea] rect:#{rect}"
    left = rect.left if left > rect.left
    right = rect.right if right < rect.right
    top = rect.top if top > rect.top
    bottom = rect.bottom if bottom < rect.bottom

  width = Math.abs(right - left)
  height = Math.abs(bottom - top)
  debuglog "[calcOcupiedArea] width:#{width}i, height:#{height}, area:#{width * height}"
  return width * height



# Returns 0 if the two intervals i1 and i2 are disjoint, or the length of their overlap otherwise.
commonIntervalLength = (i1start, i1end, i2start, i2end)->
  return 0 if i1end < i2start or i2end < i1start
  return Math.min(i1end, i2end) - Math.max(i1start, i2start)

# 算法类
class MaxRects

  # 构造函数
  # @param {uint} margin 排列矩形时，矩形和矩形之间的空白
  # @param {uint} padding 每个矩形的内部空白
  # @param {Boolean} enableMultiArrangment , when true 支持连续的 arrangment 计算
  # @param {Boolean} verbos
  constructor: (margin = 2, padding = 0, @enableMultiArrangment=false,  @verbos=false) ->
    debuglog "[constructor] @enableMultiArrangment:#{@enableMultiArrangment}"

    padding = parseInt(padding, 10) || 0
    @padding = if padding < 0 then 0 else if padding > MAX_PADDING then MAX_PADDING else padding

    margin = parseInt(margin, 10) || 0
    @margin = if margin < 0 then 0 else if margin > MAX_MARGIN then MAX_MARGIN else margin

    # 画布宽
    @binWidth = 2

    # 画布高
    @binHeight = 2
    @score1 = 0
    @score2 = 0

    # 有效区域的总面积
    @surfaceArea = 0

    # an array contains all positioned Rectangles
    # data type: Rectangle[]
    @usedRectangles = []

    # an array contains Rectangles present all avliable spaces
    # data type: Rectangle[]
    @freeRectangles = []

    # 数据源列表
    @sourceList = null

    # 数据源列表 的copy， 不可更改
    @_sourceList = null

    # 外部的结果回调
    @callback = null

    # 这是给 enableMultiArrangment 用的，用来保存每番计算尝试后的结果
    @currentArrangementByHeuristicKV = {}

    # 这是给 enableMultiArrangment 用的，用来保存已经挑选过的 arrangment
    @multiArrangments =[]

    # 当前的数据源所请求的最小的宽度和高度
    @minWidthRequest = 0
    @minHeightRequest = 0
    @minAreaRequest = 0

  # 主入口
  # @param {Array, {id, width, height}[]} rects
  # @param {Funcation} callback, signature: callback(err, data:Rectangle[])->
  calc : (rects, callback)->

    assert(_.isFunction(callback), "invalid callback")

    # validate input rects
    unless Array.isArray(rects) and rects.length > 0 and _.isFunction(callback)
      err = "bad argument, rects:#{rects}, callback:#{callback}"
      callback(err)
      return

    paddingBothSide = @padding * 2

    #@heuristicRing = if @enableMultiArrangment then HEURISTIC_RING_MULTI_BIN else HEURISTIC_RING_SINGLE_BIN
    @heuristicRing = HEURISTIC_RING_SINGLE_BIN

    # 对输入进行有效化处理
    for rect, i in rects
      rect.width = parseInt(rect.width, 10) || 0
      rect.height = parseInt(rect.height, 10) || 0
      rect.id = String(rect.id || i)
      unless rect.width > 0 and rect.height > 0 and rect.id?
        callback "bad Rectangle data: #{JSON.stringify(rect)}"
        return
        #throw new Error "bad Rectangle data: #{JSON.stringify(rect)}"

      rect.width += paddingBothSide if paddingBothSide > 0
      rect.height += paddingBothSide if paddingBothSide > 0
      rect.area = rect.width * rect.height

    # 将传入的矩形根据面积从小到大排序，从而 rect[0].area 就是当前的最小面积
    #rects.sort (a, b)-> a.area - b.area

    # 确保 rects 中不存在相同的 id
    rectIds = rects.map((el)-> return el.id)
    uniqueRectIds = _.uniq rectIds
    if rectIds.length isnt uniqueRectIds.length
      callback "duplicate id found in given rects: #{_.difference(rectIds, uniqueRectIds)}"
      return

    @_sourceList = rects
    @callback = callback
    @heuristic = null
    @startAt = Date.now()

    @heuristic = HEURISTIC_BEST_SHORT_SIDE_FIT
    @startCalculationFromMiniBinSize()
    return

  # 从当前幅面所允许的最小bin面积开始计算 arrangment
  startCalculationFromMiniBinSize : ->
    debuglog "[startCalculationFromMiniBinSize] @heuristic:#{@heuristic}"

    # calculate the minimum bin with and bin height
    @surfaceArea = calcSurfaceArea(@_sourceList)

    minSize = 2
    while minSize <= 512 and (minSize * minSize < @surfaceArea)
      minSize = minSize << 1

    debuglog "[calc] @surfaceArea:#{@surfaceArea}(#{Math.ceil(Math.sqrt(@surfaceArea))}), minSize:#{minSize}"

    @binWidth = minSize
    @binHeight = minSize
    @startCalculation()
    return

  # reset the bin size and start over calculation
  expendBinSize : () ->

    #w = @binWidth << 1
    #h = @binHeight  << 1

    w = @binWidth + 128
    h = @binHeight + 128

    debuglog "[expendBinSize] from #{@binWidth}x#{@binHeight} to #{w}x#{h}"

    if w <= MAX_BIN_WIDTH and h <= MAX_BIN_HEIGHT
      # 扩展后的容器大小在允许的范围内，因此重新开始计算
      @binWidth = w
      @binHeight = h
      #@heuristic = HEURISTIC_BEST_SHORT_SIDE_FIT
      @startCalculation()

    else
      @currentArrangementByHeuristicKV[@heuristic] = CALCULATION_FAILED
      @useNextHeuristic()

      # request size overflow
      #unless @enableMultiArrangment
      #return @callback "overall size of request texture is too large. max texture size allowed is #{MAX_BIN_WIDTH}x#{MAX_BIN_HEIGHT}, request size:#{w}x#{h}"

      #else
        #debuglog "[expendBinSize] carry on to new bin"

        ## 将当前最佳计算结果推入结果列表
        #bestArrangement = @pickArrangement()
        #@multiArrangments.push bestArrangement

        ## 将最佳结果中处理过的rect 从 _sourceList 中移除
        #processedRectIds = bestArrangement.arrangment.map((rect)-> rect.id)
        #debuglog "[expendBinSize] before @_sourceList.length:#{@_sourceList.length}"
        #@_sourceList = @_sourceList.filter((rect)-> return processedRectIds.indexOf(rect.id) is -1)
        #debuglog "[expendBinSize] after @_sourceList.length:#{@_sourceList.length}"

        #@startCalculationFromMiniBinSize()
      #return
    return

  # 在支持连续布局的情况下，从当前的布局中挑选出容积率最高的布局
  pickArrangement : ->
    #assert @enableMultiArrangment, "NOT enableMultiArrangment!"

    bestArrangement = null

    for heuristic of @heuristicRing
      arrangment = @currentArrangementByHeuristicKV[heuristic]
      continue unless arrangment?
      debuglog "[pickArrangement] heuristic:#{arrangment.heuristic}, occupiedArea:#{arrangment.occupiedArea}"
      unless bestArrangement
        bestArrangement = arrangment
        continue
      else
        if arrangment.occupiedArea < bestArrangement.occupiedArea
          bestArrangement = arrangment

    debuglog "[pickArrangement] BEST: heuristic:#{bestArrangement.heuristic}, occupiedArea:#{bestArrangement.occupiedArea}"
    return bestArrangement


  # 获取当前 arrangment 快照
  takeSnapshopt : ->
    surfaceArea = calcSurfaceArea(@usedRectangles)
    occupiedArea = calcOcupiedArea(@usedRectangles, @binWidth, @binHeight)
    result =
      surfaceArea : surfaceArea
      occupiedArea : occupiedArea
      binWidth : @binWidth
      binHeight : @binHeight
      arrangment: @usedRectangles
      heuristic : @heuristic
      freeRects : @freeRectangles
      plotRatio : surfaceArea / (@binWidth * @binHeight)  # 容积率
      timeSpent : Date.now() - @startAt

    @startAt = Date.now()
    return result

  # 当前的算法成功获得计算结果
  #currentHeuristicComplete : ->
    #debuglog "[currentHeuristicComplete] @heuristic:#{@heuristic}"

    #@currentArrangementByHeuristicKV[@heuristic] = @takeSnapshopt()

  #currentHeuristicFailed : ->
    #@currentArrangementByHeuristicKV[@heuristic] = "failed"
    #return

  useNextHeuristic : ->
    nextHeuristic = @heuristicRing[@heuristic]
    debuglog "[useNextHeuristic] nextHeuristic:#{nextHeuristic}"

    unless nextHeuristic?
      @complete()
      return

    # 还有可以尝试的算法，使用之，重新开始计算
    @heuristic = nextHeuristic
    @startCalculationFromMiniBinSize()
    return


  # 切换到下一个算法
  #switchNextHeuristic : ->
    #nextHeuristic = @heuristicRing[@heuristic]
    #debuglog "[switchNextHeuristic] nextHeuristic:#{nextHeuristic}"

    #if nextHeuristic
      ## 还有可以尝试的算法，使用之，重新开始计算

      ##if @enableMultiArrangment
      ## 在支持连续 arrangment 的情况下，记录当前算法的 arrangment
      #@currentArrangementByHeuristicKV[@heuristic] = @takeSnapshopt()

      #@heuristic = nextHeuristic
      #@startCalculation()
    #else
      ## 算法都用完了，扩展bin尺寸，然后重新开始
      #@expendBinSize()

    #return

  # 以当前选中的算法进行一次新的计算
  startCalculation : ->
    debuglog "[startCalculation] @heuristic:#{@heuristic} binSize:#{@binWidth}x#{@binHeight}"
    # reset
    @usedRectangles = []
    @freeRectangles = []
    @freeRectangles.push new Rectangle 0, 0, @binWidth, @binHeight, 'bin'
    @sourceList = @_sourceList.concat()

    @calcEachRect()
    return

  # go through the source list, and calculate each area data
  calcEachRect : ->
    @verbos && debuglog "[_calc] @heuristic:#{@heuristic}, progress: #{@usedRectangles.length}/#{@_sourceList.length}"

    if @sourceList.length <= 0
      # 所有的节点都计算完毕
      #@complete()
      #@currentHeuristicComplete()
      @currentArrangementByHeuristicKV[@heuristic] = @takeSnapshopt()
      @useNextHeuristic()
      return

    # process each rect
    bestScore1 = Number.MAX_VALUE
    bestScore2 = Number.MAX_VALUE
    bestRectIndex = -1
    bestNode = null

    @minWidthRequest = Number.MAX_VALUE
    @minHeightRequest = Number.MAX_VALUE
    @minAreaRequest = Number.MAX_VALUE

    for rect, i in @sourceList by 1

      # 刷新最小高度和宽度的要求
      @minWidthRequest = rect.width if rect.width < @minWidthRequest
      @minHeightRequest = rect.height if rect.height < @minHeightRequest
      @minAreaRequest = rect.area if rect.area < @minAreaRequest

      @score1 = 0
      @score2 = 0
      newNode = @scoreRect(rect)

      unless newNode?
        # 无法为当前的矩形找到适合放置的区域
        # @switchNextHeuristic()
        @expendBinSize()
        return
      else
        #@verbos && debuglog "[maxrects::_calc] i:#{i}, @score1:#{@score1}, bestScore1:#{bestScore1}, @score2:#{@score2}, bestScore2:#{bestScore2}"
        if (@score1 < bestScore1 or (@score1 is bestScore1 and @score2 < bestScore2))
          bestScore1 = @score1
          bestScore2 = @score2
          bestNode = newNode
          bestRectIndex = i

    # 将矩形放置如目标的空白区域，并且将放置后的空白区域切分出来
    @placeRect bestNode

    # 从待处理列表中移除已经处理完毕的矩形数据
    @sourceList.splice bestRectIndex, 1

    # 清理 freeRects 列表
    @pruneFreeList()

    # 跳出对战进行递归
    setImmediate => @calcEachRect()

    return

  # 计算完成了
  complete : ->

    bestArrangement = @pickArrangement()

    debuglog "[complete] bestArrangement:#{bestArrangement}, @enableMultiArrangment:#{@enableMultiArrangment}"

    if (not bestArrangement?) or (bestArrangement is CALCULATION_FAILED)
      err = "ERROR [maxrects::complete] overall size of request texture is too large. max texture size allowed is #{MAX_BIN_WIDTH}x#{MAX_BIN_HEIGHT}"
      debuglog "[complete] #{err}"
      @callback err
      return

    # de padding
    if @padding > 0 then bestArrangement.forEach (rect)=> rect.shrink(@padding)

    if @enableMultiArrangment
      @callback null, [bestArrangement]
    else
      @callback null, bestArrangement

    #unless @enableMultiArrangment
      ## 单个 bin 计算

      ## de padding
      #if @padding > 0 then @usedRectangles.forEach (rect)=> rect.shrink(@padding)

      #@callback null, @takeSnapshopt()

    #else
      ## 连续 bin 计算
      #@multiArrangments.push(@takeSnapshopt())

      ## de padding
      #if @padding > 0
        #for item in @multiArrangments
          #item.arrangment.forEach((rect)=> rect.shrink(@padding))

      #@callback null, @multiArrangments

    return

  # @param {Rectangle} node
  placeRect : (node) ->
    @verbos && debuglog "[maxrects::placeRect] node:#{node}"

    count = @freeRectangles.length
    @verbos && debuglog "[maxrects::placeRect] before split, free num:#{@freeRectangles.length} #############"
    i = 0
    numRectanglesToProcess = @freeRectangles.length
    while i < numRectanglesToProcess
      if @splitFreeNode(@freeRectangles[i], node)
        # 成功拆分了一个空闲区域
        @freeRectangles.splice i, 1
        --numRectanglesToProcess
        --i
      ++i

    @verbos && debuglog "[maxrects::placeRect] after split, free num:#{@freeRectangles.length}; i:#{i}, increase:#{@freeRectangles.length - count}"
    @usedRectangles.push node
    return

  # 根据被放置的矩形区域，拆分给定的空白区域
  # @param {Rectangle} freeNode 需要被拆分的空白区域
  # @param {Rectangle} usedNode 被放置的矩形区域
  splitFreeNode : (freeNode, usedNode)->
    #@verbos && debuglog "[maxrects::splitFreeNode] freeNode:#{freeNode}, usedNode:#{usedNode}, num free:#{@freeRectangles.length}, num used:#{@usedRectangles.length}/#{@_sourceList.length}"
    #@verbos && debuglog "[maxrects::splitFreeNode] @minWidthRequest:#{@minWidthRequest}, @minHeightRequest:#{@minHeightRequest}"

    debug_countBefore = @freeRectangles.length

    # Test with SAT if the rectangles even intersect.
    return false if usedNode.left >= freeNode.right or usedNode.right <= freeNode.left or
      usedNode.top >= freeNode.bottom  or usedNode.bottom <= freeNode.top

    if usedNode.left < freeNode.right and usedNode.right > freeNode.left

      # free node 的下半部被 usedNode 占用，把上半部提出来
      if usedNode.top > freeNode.top and usedNode.top < freeNode.bottom
        change = usedNode.top - freeNode.top - @margin
        if change >= @minHeightRequest and freeNode.width * change > @minAreaRequest # 忽略过小的区域
          @freeRectangles.push(new Rectangle(freeNode.left, freeNode.top, freeNode.width, change, 'f'))

      # free node 的上半部被 usedNode 占用，把下半部提出来
      if usedNode.bottom < freeNode.bottom
        change = freeNode.bottom - usedNode.bottom - @margin
        if change >= @minHeightRequest and freeNode.width * change > @minAreaRequest # 忽略过小的区域
          @freeRectangles.push(new Rectangle(freeNode.left, usedNode.bottom + @margin, freeNode.width, change, 'f'))

     if usedNode.top < freeNode.bottom and usedNode.bottom > freeNode.top

      # free node 的右半部被 usedNode 占用，把左半部提出来
       if usedNode.left > freeNode.left and usedNode.left < freeNode.right
         change = usedNode.left - freeNode.left - @margin
         if change >= @minWidthRequest and  change * freeNode.height > @minAreaRequest # 忽略过小的区域
           @freeRectangles.push(new Rectangle(freeNode.left, freeNode.top, change, freeNode.height, 'f'))

      # free node 的左半部被 usedNode 占用，把右半部提出来
       if usedNode.right < freeNode.right
         change = freeNode.right - usedNode.right - @margin
         if change >= @minWidthRequest and change * freeNode.height > @minAreaRequest # 忽略过小的区域
           @freeRectangles.push(new Rectangle(usedNode.right + @margin, freeNode.top, change, freeNode.height, 'f'))

    #if @freeRectangles.length > debug_countBefore
      #@verbos && debuglog "[maxrects::splitFreeNode] push node :#{@freeRectangles.length - debug_countBefore} !!!!!!!"
      #@verbos && debuglog "freeNode:#{freeNode}, usedNode:#{usedNode}, progress:#{@usedRectangles.length}/#{@_sourceList.length}"

    return true


  # score the given rect
  # @param {Object} rectangle data
  scoreRect : (rect) ->

    id = rect.id
    width = rect.width
    height = rect.height

    #@verbos && debuglog "[maxrects::scoreRect] id:#{id}, width:#{width}, height:#{height}"

    @score1 = Number.MAX_VALUE
    @score2 = Number.MAX_VALUE
    newNode = null

    switch @heuristic
      when HEURISTIC_BEST_SHORT_SIDE_FIT then newNode = @findPositionForBSSF(id, width, height)
      when HEURISTIC_BEST_LONG_SIDE_FIT then newNode = @findPositionForBLSF(id, width, height)
      when HEURISTIC_BEST_AREA_FIT then newNode = @findPositionForBAF(id, width, height)
      when HEURISTIC_BOTTOM_LEFT_RULE then newNode = @findPositionForBL(id, width, height)
      when HEURISTIC_CONTACT_POINT_RULE
        newNode = @findPositionForCP(id, width, height)
        @score1 = - @score1

    #@verbos && debuglog "[maxrects::scoreRect] newNode:#{newNode}"

    # Cannot fit the current rectangle.
    if not newNode? or newNode.height is 0
      @verbos && debuglog "[maxrects::scoreRect] fail to score node"
      @score1 = Number.MAX_VALUE
      @score2 = Number.MAX_VALUE


    return newNode

  # 给候选矩形打分算法：矩形的短边和空白区域越匹配越好
  # refer to https://github.com/juj/RectangleBinPack/blob/master/MaxRectsBinPack.cpp#L213
  # @param {Object} id
  # @param {int} width
  # @param {int} height
  findPositionForBSSF : (id, width, height)->
    # @score1: int & bestShortSideFit, @score2: int & bestLongSideFit
    # debuglog "[maxrects::findPositionForBSSF] id:#{id}, width:#{width}, height:#{height}"

    @score1 = Number.MAX_VALUE
    bestNode = new Rectangle 0, 0, 0, 0, id

    foundFitNode = false

    for rect in @freeRectangles

      leftoverHoriz = rect.width - width
      leftoverVert = rect.height - height

      continue if leftoverHoriz < 0 or leftoverVert < 0

      shortSideFit = Math.min leftoverHoriz, leftoverVert
      longSideFit = Math.max leftoverHoriz, leftoverVert

      if shortSideFit < @score1 or (shortSideFit is @score1 and longSideFit < @score2)
        foundFitNode = true
        #@verbos && debuglog "[maxrects::findPositionForBSSF] bestNode.reset(#{rect.left}, #{rect.top}, #{width}, #{height})"
        bestNode.reset(rect.left, rect.top, width, height)
        @score1 = shortSideFit
        @score2 = longSideFit

    return if foundFitNode then bestNode else null


  # 给候选矩形打分算法：矩形的长边和空白区域越匹配越好
  # refer to https://github.com/juj/RectangleBinPack/blob/master/MaxRectsBinPack.cpp#L263
  # @param {Object} id
  # @param {int} width
  # @param {int} height
  findPositionForBLSF : (id, width, height)->
    # @score1: int &bestShortSideFit, @score2: int &bestLongSideFit
    @verbos && debuglog "[maxrects::findPositionForBLSF] id:#{id}, width:#{width}, height:#{height}"

    @score2 = Number.MAX_VALUE
    bestNode = new Rectangle 0, 0, 0, 0, id
    foundFitNode = false

    for rect in @freeRectangles

      leftoverHoriz = rect.width - width
      leftoverVert = rect.height - height

      continue if leftoverHoriz < 0 or leftoverVert < 0

      shortSideFit = Math.min leftoverHoriz, leftoverVert
      longSideFit = Math.max leftoverHoriz, leftoverVert

      if longSideFit < @score2 or (longSideFit is @score2 and shortSideFit < @score1)
        foundFitNode = true
        @verbos && debuglog "[maxrects::findPositionForBLSF] bestNode.reset(#{rect.left}, #{rect.top}, #{width}, #{height})"
        bestNode.reset(rect.left, rect.top, width, height)
        @score1 = shortSideFit
        @score2 = longSideFit

    return if foundFitNode then bestNode else null

  # 给候选矩形打分算法：面积越匹配越好
  # refer to https://github.com/juj/RectangleBinPack/blob/master/MaxRectsBinPack.cpp#L313
  # @param {Object} id
  # @param {int} width
  # @param {int} height
  findPositionForBAF : (id, width, height)->
    # @score1: int &bestAreaFit, @score2: int &bestShortSideFit
    @score1 = Number.MAX_VALUE
    bestNode = new Rectangle 0, 0, 0, 0, id
    foundFitNode = false

    requestArea = width * height

    for rect in @freeRectangles

      leftoverHoriz = rect.width - width
      leftoverVert = rect.height - height

      continue if leftoverHoriz < 0 or leftoverVert < 0

      areaFit = rect.area - requestArea
      shortSideFit = Math.min leftoverHoriz, leftoverVert

      if areaFit < @score1 or (areaFit is @score1 and shortSideFit < @score2)
        foundFitNode = true
        @verbos && debuglog "[maxrects::findPositionForBAF] bestNode.reset(#{rect.left}, #{rect.top}, #{width}, #{height})"
        bestNode.reset(rect.left, rect.top, width, height)
        @score1 = areaFit
        @score2 = shortSideFit

    return if foundFitNode then bestNode else null

  # 给候选矩形打分算法：俄罗斯方块算法，左下角优先
  # refer to https://github.com/juj/RectangleBinPack/blob/master/MaxRectsBinPack.cpp#L173
  # @param {Object} id
  # @param {int} width
  # @param {int} height
  findPositionForBL : (id, width, height)->
    # @score1: int &bestY, @score2:int &bestX
    @score1 = Number.MAX_VALUE
    bestNode = new Rectangle 0, 0, 0, 0, id
    foundFitNode = false

    for rect in @freeRectangles
      # Try to place the rectangle in upright (non-flipped) orientation.
      continue if rect.width < width or rect.height < height

      topSideY = rect.top + height

      if topSideY < @score1 or (topSideY is @score1 and rect.left < @score2)
        foundFitNode = true
        @verbos && debuglog "[maxrects::findPositionForBL] bestNode.reset(#{rect.left}, #{rect.top}, #{width}, #{height})"
        bestNode.reset(rect.left, rect.top, width, height)
        @score1 = topSideY
        @score2 = rect.left

    return if foundFitNode then bestNode else null

  # 给候选矩形打分算法：区域尽可能接触 in this rule, the new rectangle is placed to a position where its edge touches the edges of previously placed rectangles as much as possible.
  # refer to https://github.com/juj/RectangleBinPack/blob/master/MaxRectsBinPack.cpp#L390
  # @param {Object} id
  # @param {int} width
  # @param {int} height
  findPositionForCP : (id, width, height)->
    # @score1: int &bestContactScore, @score2 not used
    @score1 = -1
    bestNode = new Rectangle 0, 0, 0, 0, id
    foundFitNode = false

    for rect in @freeRectangles by 1
      continue if rect.width < width or rect.height < height
      score = @contactPointScoreNode(rect.left, rect.top, width, height)
      if score > @score1
        foundFitNode = true
        @verbos && debuglog "[maxrects::findPositionForCP] bestNode.reset(#{rect.left}, #{rect.top}, #{width}, #{height})"
        bestNode.reset(rect.left, rect.top, width, height)
        @score1 = score

    return if foundFitNode then bestNode else null

  contactPointScoreNode : (left, top, width, height) ->
    score = 0

    right = left + width
    bottom = top + height

    score += height if left is 0 or right is @binWidth
    score += width if top is 0 or bottom is @binHeight

    for rect in @usedRectangles by 1
      if rect.left is right or rect.right is left
        score += commonIntervalLength(rect.top, rect.bottom, top, bottom)
      if rect.top is bottom or rect.bottom is top
        score += commonIntervalLength(rect.left, rect.right, left, right)

    return score

  # 整理当前的空闲区域列表，移除重叠的空白区域
  pruneFreeList : ->

    @verbos && debuglog "[maxrects::pruneFreeList] count before:#{@freeRectangles.length}, @minWidthRequest:#{@minWidthRequest}, @minHeightRequest:#{@minHeightRequest}, @minAreaRequest:#{@minAreaRequest}"
    @verbos && debuglog "[maxrects::pruneFreeList] @surfaceArea:#{@surfaceArea}(#{Math.ceil(Math.sqrt(@surfaceArea))}), @binWidth:#{@binWidth}, @binHeight:#{@binHeight}"

    i = 0
    `mainloop: //`
    while i < @freeRectangles.length
      rect = @freeRectangles[i]
      if rect.width < @minWidthRequest or rect.height < @minHeightRequest or rect.area < @minAreaRequest
        # 剔除超小区域, 这步很重要，可以大幅减少循环
        @verbos && debuglog "[maxrects::pruneFreeList] 剔除超小区域$$$$$$$$$$$$$$"
        @freeRectangles.splice i, 1
        `continue mainloop`

      # 剔除互相包含的区域
      j = i + 1
      `subloop: //`
      while j < @freeRectangles.length
        if @freeRectangles[j].contains @freeRectangles[i]
          # 后面的区域已经包含了当前区域, 剔除当前区域
          @freeRectangles.splice i, 1
          `continue mainloop`
        else if @freeRectangles[i].contains @freeRectangles[j]
          # 当前区域包含了后面的区域，剔除后面区域
          @freeRectangles.splice j, 1
          `continue subloop`
        else
          ++j
      ++i

    @verbos && debuglog "[maxrects::pruneFreeList] count after:#{@freeRectangles.length}"
    return


exports = module.exports
exports.MaxRects = MaxRects






