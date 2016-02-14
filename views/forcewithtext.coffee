Array.prototype.removeMatching = (matches) ->
  # Move backwards through array to avoid shifting indexes on deletion and skipping items
  for i in [@length-1..0]
    if matches @[i]
      @splice(i, 1)

geo = new Geo()

class BubbleGraph
  constructor: (segmentData) ->
    @nodes = []
    @links = []
    @width = 1200
    @height = 600
    @force = d3.layout.force()
    console.log segmentData
    @years = (y.year for y in segmentData[0].data[0].years)
    @selectedYear = "2013-14"
    @yearIndex = @years.length - 1
    @data = segmentData
    center = {x: @width/2, y: @height/2}
    that = this

    @svg = d3.select(".viz")
      .append("svg")
      .attr(width: "100%")
      .attr(height: "100%")
      .attr(viewBox: "0 0 #{@width} #{@height}")
      .attr(preserveAspectRatio: "xMidYMid")

    tooltip = d3.select(".viz").append("div")
      .attr(class: "tooltip")
      .style(opacity: 0)

    quadrantData = [{x:0,y:0, fx:@width/2, fy: @height/2}, {x:@width/2,y:0, fx: 0, fy: @height/2}, {x:0,y:@height/2, fx: @width/2, fy: 0}, {x:@width/2,y:@height/2, fx: 0, fy: 0}]
    @quadrants = (new Quadrant(i, this, q.x, q.y, center.x, center.y, q.fx, q.fy, segmentData[i].colour, segmentData[i].name, tooltip) for q, i in quadrantData)
    nodes = (@quadrants[q].addNode(new Node(node, @quadrants[q], segment.colour)) for node in segment.data) for segment, q in segmentData

    @years.sort((a,b) -> d3.ascending(a,b))
    timeline = d3.select(".timeline")
    timelineScale = d3.scale.linear().domain([0, @years.length]).range([10, 90])
    timeline.selectAll("a")
      .data(@years)
      .enter()
      .append("a")
      .text((d) -> d)
      # .style(left: (d,i) -> "#{timelineScale i}%")
      .classed(selected: (d) => d is @selectedYear)
      .on(click: (d) ->
        timeline.selectAll('a').classed(selected: false)
        d3.select(this).classed(selected: true)
        that.updateYear(d)
      )

    @drawNodes()

    tick = (e) =>
      k = 0.1 * e.alpha
      (o.y += (o.quadrant.fy - o.y) * k; o.x += (o.quadrant.fx - o.x) * k) for o in @nodes when not o.parent
      node = @svg.selectAll(".quadrant g.node")
      node.each(collide(e.alpha))
        .attr(transform: (d) -> "translate(#{d.x},#{d.y})")

      link = @svg.selectAll(".quadrant .link")

      link.attr("x1", (d)-> d.source.x)
        .attr("y1", (d)-> d.source.y)
        .attr("x2", (d)-> d.target.x)
        .attr("y2", (d)-> d.target.y)

    collide = (alpha) =>
      (d) =>
        quadtree = d3.geom.quadtree(@nodes)
        r = d.radius * 1.2
        d.x = Math.max(d.radius, Math.min(@width/2 - d.radius, d.x))
        d.y = Math.max(d.radius, Math.min(@height/2 - d.radius, d.y))
        nx1 = d.x - r
        nx2 = d.x + r
        ny1 = d.y - r
        ny2 = d.y + r

        quadtree.visit((quad, x1, y1, x2, y2) ->
          if quad.point and !(quad.point is d)
            x = d.x - quad.point.x
            y = d.y - quad.point.y
            l = Math.sqrt(x * x + y * y)
            r2 = r + quad.point.radius
            if (l < r2)
              l = (l - r2) / l * alpha
              d.x -= x *= l
              d.y -= y *= l
              quad.point.x += x
              quad.point.y += y
          x1 > nx2 || x2 < nx1 || y1 > ny2 || y2 < ny1
      )

    @force = @force.nodes(@nodes)
      .links(@links)
      .size([@width, @height])
      .gravity(0)
      .charge(0.5)
      .linkDistance(10)
      .linkStrength(0.5)
      .on("tick", tick)
    @force.start()

  drawNodes: () =>
    quadrant.drawNodes() for quadrant in @quadrants

  updateYear: (year) =>
    @selectedYear = year
    @yearIndex = @years.indexOf year
    quadrant.changeYear(year) for quadrant in @quadrants

class Node
  constructor: (data, quadrant, colour, opacity, fx, fy) ->
    @quadrant = quadrant
    @graph = quadrant.graph
    @data = data
    @colour = colour
    @children = data.children
    @opacity = opacity || 1
    @x = fx || quadrant.fx
    @y = fy || quadrant.fy
    minR = 20
    maxR = 100
    @minA = geo.areaFromRadius(minR)
    @maxA = geo.areaFromRadius(maxR)
    @circleScale = d3.scale.linear().domain([1, 100000])
    @radius = if data.years[@graph.yearIndex].val <= 0 then 0 else @calculateRadius(@circleScale(data.years[@graph.yearIndex].val), data.years[@graph.yearIndex].val, @minA, @maxA)

  calculateRadius: (ratio, value, minArea, maxArea) =>
    area = ((maxArea - minArea) * ratio) + minArea
    geo.radiusFromArea(area)

  changeYear: (year) =>
    d = @data.years[@graph.yearIndex]
    @radius = if (d.val <= 0) then 0 else @calculateRadius(@circleScale(d.val), d.val, @minA, @maxA)

  showText: =>
    clickText = if @_children
     "<em>Click to collapse</em> "
    else if @children
      "<em>Click to expand</em> "
    else
      ""

    "
    #{clickText}
    <strong>#{@data.name}</strong>
    #{d3.format("$,") @data.years[@graph.yearIndex].val}M AUD
    "

class Quadrant
  constructor: (index, graph, x, y, width, height, fx, fy, colour, name, tooltip) ->
    @index = index
    @nodes = []
    @links = []
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
    that = this
    textPos = if @fx is 600 then 10 else 580
    graphPos = if @fx is 600 then 10 else 420

    @element = @container.append("g")
      .attr(class: "quadrant")
      .attr(transform: "translate(#{x},#{y})")

    @dataBox = new DataBox(@, graph.years, graphPos, 80)

    @element.on("mouseover", () => @dataBox.show())
      .on("mouseout", () => @dataBox.hide())

    @element.append("rect")
      .attr(width: width)
      .attr(height: height)
      .attr(fill: @colour)
      .attr("fill-opacity": 0.2)

    @element.append("text")
      .text(name)
      .attr(class: "title")
      .attr(x: textPos)
      .attr("text-anchor": if @fx is 600 then "start" else "end")
      .attr(y: 30)
      .attr(fill: @colour)

    @element.append("text")
      .attr(class: "total")
      .attr(x: textPos)
      .attr("text-anchor": if @fx is 600 then "start" else "end")
      .attr(y: 60)
      .attr(fill: @colour)

  addNode: (node) =>
    @nodes.push node
    @graph.nodes.push node

  addLink: (link) =>
    @links.push link
    @graph.links.push link

  removeLinks: (source) =>
    matches = (link) -> link.source is source
    @links.removeMatching(matches)
    @graph.links.removeMatching(matches)

  removeNode: (nodeData) =>
    matches = (node) -> node.data is nodeData
    @nodes.removeMatching(matches)
    @graph.nodes.removeMatching(matches)

  changeYear: (year) =>
    node.changeYear(year) for node in @nodes
    node = @element.selectAll("g.node")
    node.select("circle")
      .transition()
      .duration(1000)
      .attr(r: (d) -> d.radius)
      .each("end", () => @graph.force.start())

    node.select("text")
      .text((d) -> d.data.name.substring(0, d.radius / 3))
    @updateTotal()

  updateTotal: =>
    @total = d3.sum(@nodes, (d) => unless d.data.parent then +d.data.years[@graph.yearIndex].val else 0)
    @element.select('.total')
      .text("#{d3.format(",") @total} Million")

  drawLinks: () =>
    link = @element.selectAll("line.link").data(@links)

    link.exit().remove()

    link.enter()
      .append("line")
      .attr(class: "link")
      .attr(stroke: @colour)
      .style(display: (d) => if d.target.data.years[@graph.yearIndex].val < 1 then "none" else "initial")

  drawNodes: () =>
    @updateTotal()
    node = @element.selectAll("g.node").data(@nodes)
    that = this

    node.exit().remove()

    nodeEnter = node.enter()
      .append("g")
      .attr(class: "node")
      .attr(transform: (d) -> "translate(#{d.quadrant.fx},#{d.quadrant.fy})")

    nodeEnter.append("text")
      .attr("dy", ".3em")
      .style("text-anchor", "middle")
      .text((d) -> d.data.name.substring(0, d.radius / 3))
      .attr(fill: (d) -> d3.rgb(d.colour).darker(2))
      .style("font-size": "12px")

    nodeEnter.append("circle")
      .attr(r: (d) -> d.radius)
      .attr(fill: (d) -> d.colour)
      .attr(stroke: (d) -> d.colour)
      .attr("stroke-width": (d) -> if d.data.children then 4 else 1)
      .attr("stroke-opacity": 0.4)
      .attr("fill-opacity": (d) -> 0.6 * d.opacity)
      .on("mouseover", (d) ->
        d3.select(this)
          .transition()
          .attr("fill-opacity": 0.8 * d.opacity)

        if d.data.children
          d3.select(this).transition().attr("stroke-opacity", 0.8)

        widthScale = that.graph.svg[0][0].clientWidth / that.graph.width
        heightScale = that.graph.svg[0][0].clientHeight / that.graph.height

        d.quadrant.tooltip
          .html(d.showText())
          .style(left: "#{(d.x + d.quadrant.x) * widthScale}px")
          .style(top: "#{(d.y + d.quadrant.y) * heightScale}px")
          .transition()
          .style(opacity: 1)
      )
      .on("mouseout", (d) ->
        d3.select(this)
          .transition()
          .attr("fill-opacity": (d) -> 0.6 * d.opacity)
          .attr("stroke-opacity", 0.4)

        d.quadrant.tooltip.transition().style(opacity: 0)
      )

    nodeEnter.filter((d) -> d.data.children)
      .select("circle")
      .on("click", (d) ->
        source = that.graph.nodes.indexOf(d)

        if d.children
          d._children = d.children
          d.children = null
          counts = (that.addNode(new Node(node, d.quadrant, d.colour, 0.5)) for node in d._children)
          that.addLink {source: source, target: c-1} for c in counts
        else
          d.children = d._children
          d._children = null
          that.removeLinks d
          that.removeNode node for node in d.children

        d.quadrant.tooltip
          .html(d.showText())

        that.drawNodes()
        that.drawLinks()
      )

    @graph.force.nodes(@graph.nodes).start()
    @dataBox.update(@graph.data, @name)

class DataBox
  constructor: (quadrant, years, x, y) ->
    @quadrant = quadrant
    @years = years
    @x = x
    @y = y

    @contain = @quadrant.element.append("g").attr(class: "data-box")
      .attr(transform: "translate(#{@x},#{@y})")
      .style(display: "none")

    @xAxis = @contain.append("g")
      .attr("class", "axis")

    @yAxis = @contain.append("g")
      .attr("class": "y axis")

    @lineChart = @contain.append("g").attr(class: "line-chart")

  update: (data, selected) =>
    lineChartWidth = 180
    lineChartHeight = 140
    that = this
    data = data
    selected = selected

    max = d3.max(data, (d) -> d3.max(d.years, (y) -> y.total))
    timeScale = d3.scale.linear().domain([0, @years.length]).range([20, lineChartWidth - 10])
    yScale = d3.scale.linear().domain([0, max]).range([lineChartHeight - 10, 10]).nice()

    line = d3.svg.line()
      .x((d, i) -> timeScale(i))
      .y((d) -> yScale(d.total))

    yA = d3.svg.axis()
      .scale(yScale)
      .orient("left")
      .innerTickSize(-(lineChartWidth - 40))
      .outerTickSize(0)
      .ticks(5)
      .tickFormat(d3.format("s"))

    @xAxis.selectAll("text")
      .data(@years)
      .enter()
      .append("text")
      .attr(x: (d, i) -> timeScale i)
      .attr(y: lineChartHeight)
      .text((d) -> d)
      .style(display: (d,i) => if i is 0 or i is (@years.length - 1) then "auto" else "none")
      .attr("text-anchor": (d,i) -> if i is 0 then "start" else "end")

    @xAxis.selectAll("line")
      .data(@years)
      .enter()
      .append("line")
      .attr(x1: (d, i) -> timeScale i)
      .attr(y1: 10)
      .attr(y2: lineChartHeight - 10)
      .attr(x2: (d, i) -> timeScale i)
      .style(display: (d,i) => if d is @quadrant.graph.selectedYear then "auto" else "none")

    @yAxis.call(yA)
      .attr(transform: "translate(20, 0)")

    @lineChart.selectAll("g").remove()

    segment = @lineChart.selectAll("g")
      .data(data)
      .enter()
      .append("g")

    segment.append("path")
      .attr(fill: "none")
      .attr(stroke: (d) -> d.colour)
      .attr("stroke-width": 2)
      .attr(d: (d) -> line(d.years))
      .attr("stroke-opacity": (d) => if d.name is selected then 1 else 0.2)

    segment.selectAll("circle")
      .data((d) -> d.years)
      .enter()
      .append("circle")
      .attr(fill: (d) -> d3.select(this.parentNode).datum().colour)
      .attr(r: 3)
      .attr(cx: (d, i) -> timeScale(i))
      .attr(cy: (d) -> yScale(d.total))
      .attr("fill-opacity": (d) -> if d3.select(this.parentNode).datum().name is selected then 1 else 0.2)
      .on("mouseover", (d) -> console.log d.total)

    # #bar graph
    # maxWidth = 120
    # console.log @quadrant.total
    # barScale = d3.scale.linear().domain([0, 1]).range([0, maxWidth])

    # bars = @contain.selectAll("g.bars")
    #   .data(@data[@quadrant.index].data)
    #   .enter()
    #   .append("g")
    #   .attr(class: "bars")
    #   .attr(transform: "translate(20, 160)")

    # bars.append("rect")
    #   .attr(x: 0)
    #   .attr(y: (d, i) -> i * 25 + 3)
    #   .attr(height: 10)
    #   .attr(width: (d) => barScale d.years[@quadrant.graph.yearIndex].val/@quadrant.total)
    #   .attr(fill: @quadrant.colour)

    # bars.append("text")
    #   .attr(x: 0)
    #   .attr(y: (d, i) -> i * 25)
    #   .attr("font-size": 10)
    #   .text((d) => d.item)

    # bars.append("text")
    #   .attr(x: (d) => (barScale d.years[@quadrant.graph.yearIndex].val/@quadrant.total) + 2)
    #   .attr(y: (d, i) -> i * 25 + 12)
    #   .attr("font-size": 8)
    #   .attr(fill: @quadrant.colour)
    #   .text((d) => "$#{d.years[@quadrant.graph.yearIndex].val}M")

  show: () =>
    @contain.style(display: "initial")

  hide: () =>
    @contain.style(display: "none")


graph = (e, assetsData, expensesData, liabilitiesData, revenueData) ->
  segmentData = [
      {name: "liabilities", colour: "#c54927", data: getEntity(liabilitiesData), years: getYears(liabilitiesData)}
      {name: "expenses", colour: "#911048", data: getEntity(expensesData), years: getYears(expensesData)}
      {name: "assets", colour: "#2789ab", data: getEntity(assetsData), years: getYears(assetsData)}
      {name: "revenue", colour: "#27a776", data: getEntity(revenueData), years: getYears(revenueData)}
    ]
  graph = new BubbleGraph(segmentData)

getEntity = (data) ->
  dataMap = data.reduce((map, node) ->
    entity = {years: [], name: node["Item"], parent: node.parent}
    keys = d3.keys node
    years = keys.filter((d) -> !(d is "parent" or d is "Item" or d is "undefined"))
    entity.years.push {year: year, val: node[year]} for year in years
    map[node["Item"]] = entity
    map
  , {})
  treeData = []
  generateTree d, dataMap, treeData for d in d3.map(dataMap).values()
  treeData

getYears = (data) ->
  keys = d3.keys data[0]
  years = keys.filter((d) -> !(d is "parent" or d is "Item" or d is "undefined"))
  ({year: year, total: d3.sum((if item.parent then 0 else item[year]) for item in data)} for year in years)

generateTree = (node, dataMap, treeData, links) ->
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

