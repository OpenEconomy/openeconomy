geo = new Geo()

class BubbleGraph
  constructor: (segmentData) ->
    @nodes = []
    width = 1200
    height = 800
    @force = d3.layout.force()
    @selectedYear = "2013-14"

    center = {x: width/2, y: height/2}
    @svg = d3.select(".viz").append("svg").attr(width: width).attr(height: height)

    tooltip = d3.select(".viz").append("div")
      .attr(class: "tooltip")
      .style(opacity: 0)

    quadrantData = [{x:0,y:0, fx:width/2, fy: height/2}, {x:width/2,y:0, fx: 0, fy: height/2}, {x:0,y:height/2, fx: width/2, fy: 0}, {x:width/2,y:height/2, fx: 0, fy: 0}]
    @quadrants = (new Quadrant(i, this, q.x, q.y, center.x, center.y, q.fx, q.fy, segmentData[i].colour, segmentData[i].name, tooltip) for q, i in quadrantData)
    segment.nodes = (new Node(node, @quadrants[q], segment.colour) for node in segment.data) for segment, q in segmentData

    years = (y.year for y in segmentData[0].data[0].years)
    years.sort((a,b) -> d3.descending(a,b))
    timeline = d3.select(".timeline")
    timelineScale = d3.scale.linear().domain([0, years.length]).range([0, width])
    timeline.selectAll("a")
      .data(years)
      .enter()
      .append("a")
      .text((d) -> d)
      .style(left: (d,i) -> "#{timelineScale i}px")
      .on(click: (d) => @updateYear(d))

    @updateNodes()
    @drawNodes()

    tick = (e) =>
      k = 0.1 * e.alpha
      (o.y += (o.quadrant.fy - o.y) * k; o.x += (o.quadrant.fx - o.x) * k) for o in quadrant.nodes for quadrant in @quadrants
      node = @svg.selectAll(".quadrant g.node")
      node.each(collide(e.alpha))
        .attr(transform: (d) -> "translate(#{d.x},#{d.y})")

    collide = (alpha) =>
      (d) =>
        quadtree = d3.geom.quadtree(@nodes)
        r = d.radius
        d.x = Math.max(d.radius, Math.min(width/2 - d.radius, d.x))
        d.y = Math.max(d.radius, Math.min(height/2 - d.radius, d.y))
        nx1 = d.x - r
        nx2 = d.x + r
        ny1 = d.y - r
        ny2 = d.y + r

        quadtree.visit((quad, x1, y1, x2, y2) ->
          if quad.point and !(quad.point is d)
            x = d.x - quad.point.x
            y = d.y - quad.point.y
            l = Math.sqrt(x * x + y * y)
            r = d.radius + quad.point.radius
            if (l < r)
              l = (l - r) / l * alpha
              d.x -= x *= l
              d.y -= y *= l
              quad.point.x += x
              quad.point.y += y
          x1 > nx2 || x2 < nx1 || y1 > ny2 || y2 < ny1
      )

    @force = @force.nodes(@nodes)
      .size([width, height])
      .gravity(0)
      .charge(5)
      .on("tick", tick)
    @force.start()

  drawNodes: () =>
    quadrant.drawNodes() for quadrant in @quadrants

  updateYear: (year) =>
    @selectedYear = year;
    quadrant.changeYear(year) for quadrant in @quadrants

  updateNodes: () =>
    nodes = []
    nodes.push quadrant.nodes... for quadrant in @quadrants
    @nodes = nodes

class Node
  constructor: (data, quadrant, colour) ->
    @quadrant = quadrant
    @data = data
    @map = d3.map(@data.years, (d) -> d.year)
    @colour = colour
    @children = data.children
    @x = quadrant.fx
    @y = quadrant.fy
    minR = 20
    maxR = 120
    @minA = geo.areaFromRadius(minR)
    @maxA = geo.areaFromRadius(maxR)
    @circleScale = d3.scale.linear().domain([1, 100000])
    @quadrant.addNode this
    @selectedYear = 0
    @radius = if data.years[@selectedYear].val <= 0 then 0 else @calculateRadius(@circleScale(data.years[@selectedYear].val), data.years[@selectedYear].val, @minA, @maxA)

  calculateRadius: (ratio, value, minArea, maxArea) =>
    area = ((maxArea - minArea) * ratio) + minArea
    geo.radiusFromArea(area)

  changeYear: (year) =>
    d = @map.get year
    @selectedYear = @map.keys().indexOf year
    @radius = if (d.val <= 0) then 0 else @calculateRadius(@circleScale(d.val), d.val, @minA, @maxA)

class Quadrant
  constructor: (index, graph, x, y, width, height, fx, fy, colour, name, tooltip) ->
    @index = index
    @nodes = []
    @graph = graph
    @container = graph.svg
    @x = x
    @y = y
    @fx = fx
    @fy = fy
    @width = width
    @height = height
    @colour = colour
    @name = name
    @tooltip = tooltip
    @total = 0

    @element = @container.append("g")
      .attr(class: "quadrant")
      .attr(transform: "translate(#{x},#{y})")

    @element.append("rect")
      .attr(width: width)
      .attr(height: height)
      .attr(fill: @colour)
      .attr("fill-opacity": 0.2)

    @element.append("text")
      .text(name)
      .attr(class: "title")
      .attr(x: if @fx is 600 then 10 else 580)
      .attr("text-anchor": if @fx is 600 then "start" else "end")
      .attr(y: 30)
      .attr(fill: @colour)

    @element.append("text")
      .attr(class: "total")
      .attr(x: if @fx is 600 then 10 else 580)
      .attr("text-anchor": if @fx is 600 then "start" else "end")
      .attr(y: 60)
      .attr(fill: @colour)

  addNode: (node) =>
    @nodes.push node

  removeNode: (nodeData) =>
    @nodes.splice(i, 1) for i, node of @nodes when node.data is nodeData

  changeYear: (year) =>
    node.changeYear(year) for node in @nodes
    node = @element.selectAll("g.node")
    node.select("circle")
      .transition()
      .duration(1000)
      .attr(r: (d) -> d.radius)
      .each("end", () => @graph.force.start())

    node.select("text")
      .text((d) -> d.data.item.substring(0, d.radius / 3))
    @updateTotal()

  updateTotal: =>
    @total = d3.sum(@nodes, (d) => +d.data.years[d.selectedYear].val)
    @element.select('.total')
      .text("#{d3.format(",") @total} Million")

  drawNodes: () =>
    @updateTotal()
    node = @element.selectAll("g.node").data(@nodes)

    node.exit().remove()

    nodeEnter = node.enter()
      .append("g")
      .attr(class: "node")
      .attr(transform: (d) -> "translate(#{d.quadrant.fx},#{d.quadrant.fy})")

    nodeEnter.append("text")
      .attr("dy", ".3em")
      .style("text-anchor", "middle")
      .text((d) -> d.data.item.substring(0, d.radius / 3))
      .attr(fill: (d) -> d3.rgb(d.colour).darker(2))
      .style("font-size": "12px")

    nodeEnter.append("circle")
      .attr(r: (d) -> d.radius)
      .attr(fill: (d) -> d.colour)
      .attr(stroke: (d) -> d.colour)
      .attr("stroke-width": (d) -> if d.data.children then 4 else 1)
      .attr("stroke-opacity": 0.4)
      .attr("fill-opacity": 0.6)
      .on("mouseover", (d) ->
        d3.select(this)
          .transition()
          .attr("fill-opacity": 0.8)

        if d.data.children
          d3.select(this).transition().attr("stroke-opacity", 0.8)

        d.quadrant.tooltip
          .html("
            <strong>#{d.data.item}</strong>
            #{d3.format("$,") d.data.years[d.selectedYear].val}M AUD
          ")
          .style(left: "#{d.x + d.quadrant.x}px")
          .style(top: "#{d.y + d.quadrant.y}px")
          .transition()
          .style(opacity: 1)
      )
      .on("mouseout", (d) ->
        d3.select(this)
          .transition()
          .attr("fill-opacity": 0.6)
          .attr("stroke-opacity", 0.4)

        d.quadrant.tooltip.transition().style(opacity: 0)
      )

    nodeEnter.filter((d) -> d.data.children)
      .select("circle")
      .on("click", (d) =>
        if d.children
          d._children = d.children
          d.children = null
          new Node(node, d.quadrant, d.colour) for node in d._children
        else
          d.children = d._children
          d._children = null
          @removeNode node for node in d.children
        @graph.updateNodes()
        @drawNodes()
      )

    @graph.force.nodes(@graph.nodes).start()

graph = (e, assetsData, expensesData, liabilitiesData, revenueData) ->
  segmentData = [
      {name: "liabilities", colour: "#c54927", data: getEntity liabilitiesData}
      {name: "expenses", colour: "#911048", data: getEntity expensesData}
      {name: "assets", colour: "#2789ab", data: getEntity assetsData}
      {name: "revenue", colour: "#27a776", data: getEntity revenueData}
    ]
  graph = new BubbleGraph(segmentData)

getEntity = (data) ->
  dataMap = data.reduce((map, node) ->
    entity = {years: [], item: node["Item"], parent: node.parent}
    keys = d3.keys node
    years = keys.filter((d) -> !(d is "parent" or d is "Item" or d is "undefined"))
    entity.years.push {year: year, val: node[year]} for year in years
    map[node["Item"]] = entity
    map
  , {})
  treeData = []
  generateTree d, dataMap,treeData for d in d3.map(dataMap).values()
  treeData

generateTree = (node, dataMap, treeData) ->
  parent = dataMap[node.parent]
  if parent
    children = (parent.children || (parent.children = []))
    children.push(node)
  else
    treeData.push node

queue()
  .defer(d3.csv, 'data/WA4/assets.csv')
  .defer(d3.csv, 'data/WA4/expenses.csv')
  .defer(d3.csv, 'data/WA4/liabilities.csv')
  .defer(d3.csv, 'data/WA4/revenue.csv')
  .await(graph)

