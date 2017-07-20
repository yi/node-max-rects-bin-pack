
class Render

  constructor: (elId, pack)->

    if $("#isDrawRender").is(":checked")
      paper = Raphael elId, pack.binWidth, pack.binHeight

      paper.rect(0, 0, pack.binWidth, pack.binHeight).attr "fill", "#000"

      for rect in pack.arrangment
        paper.rect(rect.left, rect.top, rect.width, rect.height).attr "fill", "#" + parseInt(rect.id, 10).toString(16)

      for rect in pack.freeRects
        paper.rect(rect.left, rect.top, rect.width, rect.height).attr "stroke", "#00ff00"

    $("#details").append """
    <pre>
          矩形数量:#{pack.arrangment.length};
          辅助区数量: #{pack.freeRects.length};
          算法：#{pack.heuristic};
          耗时：#{pack.timeSpent}ms;
          画布大小：#{pack.binWidth} x #{pack.binHeight};
          容积率: #{pack.plotRatio}
          占地面积: #{pack.occupiedArea}
    </pre>
      """

# Creates canvas 320 × 200 at 10, 50
above128 = -> 128 + 128 * Math.random() >>> 0

# @param {Array, {id, width, height}[]} rects
calcSurfaceArea = (rects)->
  result = 0
  for rect in rects
    result += rect.width * rect.height
  return result

generateRects = ->
  rects = []

  base = if $("#isMulti").is(":checked") then 1000 * Math.random() >>> 0 else 20
  n = base + Math.random() * 120 >>> 0

  for i in [0...n]
    rects.push
      id: (above128() << 16) + i * 4
      width: 1 + 256 * Math.random() >>> 0
      height: 1 + 256 * Math.random() >>> 0

  return rects

generate = ->

  jobId = Date.now()
  rects = generateRects()
  totalArea = calcSurfaceArea(rects)

  $("#input").text "输入: 矩形数量:" + rects.length

  #console.log "@" + jobId + " send following rects to calc"
  #console.dir rects

  $.ajax
    type: "POST"
    url: "/calc"
    data:
      rects: rects
      margin: $("#margin:checked").val()
      padding: $("#padding:checked").val()
      is_multi: $("#isMulti").is(":checked")

    success: (results) ->
      console.log "@" + jobId + " receive server result:"
      #console.dir results

      return $("#output").text "输出：遇到问题:calculation failed. reason:" + results.msg unless results.success is true
      return $("#output").text "输出：遇到问题:calculation failed. empty results" unless results.results?

      results = results.results

      results = [results] unless Array.isArray(results)

      #$("#details").append "<hr>"
      $("#details").empty()
      $("#canvases").empty()

      totalTs = 0
      for pack , i in results
        id = "node#{i}"
        $("#canvases").append("<div id='#{id}'></div>")
        new Render(id, pack)
        totalTs += pack.timeSpent

      $("#output").text "输出：bin 数量：#{results.length}, 总耗时：#{totalTs}ms"

      setTimeout generate, 1000  if $("#isContinue").is(":checked") #start over after 3 sec
      return

    dataType: "json"

  return

$(document).ready ->
  $("#btnGenerate").click generate




