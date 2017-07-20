# maxrects

A Node.JS implementation of MaxRects algorithms, useful for rectangle bin packing and creating texture atlases

MaxRects 算法的 Node.JS 实现。设计逻辑如下：
 * 实现 MaxRects 的 5 种算法： BEST_SHORT_SIDE_FIT("BSSF"), LONG_SIDE_FIT("BLSF"), BEST_AREA_FIT("BAF"), BOTTOM_LEFT_RULE("BL"), CONTACT_POINT_RULE("CP")
 * 执行逻辑为画布最小 > 速度最快 > 容积率最高。从而保证在最快时间内，找到最小的画布来放置所有请求的矩形。
 * 执行是尝试的算法依次为： BSSF > BLSF > BAF > BL > CP 因为实测下来，BSSF的平均容积率最高（除了超长，超宽情况），CP的计算开销最大
 * 可在客户端执行，也可以在服务器执行。因此采用 Node.JS 的异步实现(process.nextTick) 以避免计算资源锁死
 * 因此可以实现大量并发计算，在i3 cpu 的测试主机上，10个客户端并发，平均每次请求的矩形数为100，得到的计算平局效率 20ms
 * 提供画布的 [padding 和 margin 设定](http://www.codeandweb.com/texturepacker/documentation#layout)，以在 alpha-bleeding 时得到更好的边缘修正效果。
 * 提供一个简单的 web 界面的人工调试服务


![Screenshot](//github.com/yi/node-max-rects-bin-pack/raw/master/public/screenshot01.jpg)


## Install

`npm install max-rects-bin-pack`

## Usage

###

```javascript

var margin = 1;    // 边距
var padding = 1;   // 内距
var isMulti = ture;  // arrangment could support multiple canvas
var rects = [ { id: '10682046', width: '232', height: '44' },
    { id: '13882862', width: '72', height: '36' },
    { id: '14922707', width: '75', height: '168' },
    { id: '12124153', width: '105', height: '128' },
    { id: '13484486', width: '162', height: '188' },
    { id: '13541554', width: '207', height: '207' },
    { id: '16036037', width: '12', height: '202' },
    { id: '13482376', width: '123', height: '90' } ]


var MaxRects = require("max-rects-bin-pack").MaxRects;

var mr = new MaxRects(margin, padding, isMulti)

mr.calc(rects, function(err, results) {
  console.dir(results);
});

```

### 启动 web 服务 / Start service
```bash
npm start
```

### 执行单元测试 / Unit Test
```bash
npm test
```

### 执行人工测试 / UI Testing
```bash
npm start
```
然后在支持 SVG 的浏览器(Chrome浏览器)中访问 http://localhost:3677

## Web 服务接口 / Server-side API

### 计算maxrect 布局

path: "/calc"

method: "POST"

输入格式 / Input:
```javascript
req.body={
  margin : 1,    // 边距
  padding : 1,   // 内距
  rects : [ { id: '10682046', width: '232', height: '44' },
    { id: '13882862', width: '72', height: '36' },
    { id: '14922707', width: '75', height: '168' },
    { id: '12124153', width: '105', height: '128' },
    { id: '13484486', width: '162', height: '188' },
    { id: '13541554', width: '207', height: '207' },
    { id: '16036037', width: '12', height: '202' },
    { id: '13482376', width: '123', height: '90' } ]
 }
 ```

成功时输出格式 / Output：
```javascript
{
  "success": true,
  "results": {
    "surfaceArea": 727538,
    "binWidth": 1024,
    "binHeight": 1024,
    "arrangment": [
      {
        "id": "14910417",
        "left": 0,
        "top": 0,
        "width": 256,
        "height": 217,
        "right": 256,
        "bottom": 217,
        "area": 55552
      },
      {
        "id": "12037547",
        "left": 258,
        "top": 0,
        "width": 247,
        "height": 120,
        "right": 505,
        "bottom": 120,
        "area": 29640
      },
      {
        "id": "15380618",
        "left": 0,
        "top": 280,
        "width": 210,
        "height": 10,
        "right": 210,
        "bottom": 290,
        "area": 2100
      },
      {
        "id": "10221726",
        "left": 799,
        "top": 177,
        "width": 100,
        "height": 28,
        "right": 899,
        "bottom": 205,
        "area": 2800
      }
    ],
    "timeSpent": 8,
    "heuristic": "BSSF",
    "freeRects": [
      {
        "id": "f",
        "left": 638,
        "top": 677,
        "width": 386,
        "height": 242,
        "right": 1024,
        "bottom": 919,
        "area": 93412
      },
      {
        "id": "f",
        "left": 799,
        "top": 207,
        "width": 142,
        "height": 817,
        "right": 941,
        "bottom": 1024,
        "area": 116014
      }
    ]
  }
}
```

失败时输出格式：
```javascript
{
  "success": false,
  "msg" : "error information"
}
```


## References

 * CPP Implementation: https://github.com/juj/RectangleBinPack/
 * Paper: [A Thousand Ways to Pack the Bin - A Practical Approach to Two-Dimensional Rectangle Bin Packing.](http://clb.demon.fi/files/RectangleBinPack.pdf)
 * Blog: [Rectangle Bin Packing](http://clb.demon.fi/projects/rectangle-bin-packing)
 * Blog: [More Rectangle Bin Packing](http://clb.demon.fi/projects/more-rectangle-bin-packing)
 * Blog: [Even More Rectangle Bin Packing](http://clb.demon.fi/projects/even-more-rectangle-bin-packing)
 * Blog: [MaxRects ActionScript3 implementation](http://www.duzengqiang.com/blog/post/971.html)
 * QA: [HTML5 Canvas to PNG](http://stackoverflow.com/questions/12796513/html5-canvas-to-png-file)

## License
Copyright (c) 2013 yi
Licensed under the MIT license.
