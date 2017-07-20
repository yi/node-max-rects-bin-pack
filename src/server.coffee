
debuglog = require("debug")("server")
express = require 'express'
path = require "path"
{MaxRects} = require "./maxrects"

PORT = 3677

app = express()

#app.use(express.basicAuth("dev", "pass"))

# config
app.set('view options', { doctype: 'html' })
app.set('views', __dirname + '/views')
app.set('title', 'MaxRects')

# middleware
app.use(express.favicon())
app.use(app.router)
app.use(express.static(path.join(__dirname, "../public")))

app.use(express.bodyParser())

app.get '/', (req, res) ->
  res.redirect "/index.html"
  return


app.post '/calc', express.bodyParser(), (req, res) ->

  console.log "[index::on /calc] ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
  rects = req.body.rects
  #console.log "[index::on /calc] rects: $j", rects

  unless Array.isArray(rects) and rects.length > 0
    return res.json
      success : false
      msg : 'missing rects'

  try
    isMulti = false
    if req.body.is_multi is true or req.body.is_multi is "true"
      isMulti = true

    debuglog "[server] Boolean(req.body.is_multi):#{Boolean(req.body.is_multi)}, req.body.is_multi:#{req.body.is_multi}, isMulti:#{isMulti}"
    (new MaxRects(req.body.margin, req.body.padding, isMulti)).calc rects, (err, results)->
      #console.log "[index::on /calc::complete] err:#{err}, results:"
      #console.dir results

      if err?
        return res.json
          success : false
          msg : err.toString()
      else
        return res.json
          success : true
          results : results
  catch err
    return res.json
      success : false
      msg : err.toString()

  return

app.listen(PORT)
console.log "maxrects service start at port:#{PORT}"


