geo = new Geo()

graph = (e, assetsData, expensesData, liabilitiesData, revenueData) ->
	segmentData = [
		{name: "revenue", colour: "#27a776", data: getEntity revenueData}
		{name: "expenses", colour: "#911048", data: getEntity expensesData}
		{name: "assets", colour: "#2789ab", data: getEntity assetsData}
		{name: "liabilities", colour: "#c54927", data: getEntity liabilitiesData}
	]
	nodes = []

	width = 1200
	height = 800
	center = {x: width/2, y: height/2}
	svg = d3.select(".content").append("svg").attr(width: width).attr(height: height)
	quadrantData = [{x:0,y:0, fx:width/2, fy: height/2}, {x:width/2,y:0, fx: 0, fy: height/2}, {x:0,y:height/2, fx: width/2, fy: 0}, {x:width/2,y:height/2, fx: 0, fy: 0}]
	quadrants = (new Quadrant(i, svg, q.x, q.y, center.x, center.y, q.fx, q.fy, segmentData[i].colour) for q, i in quadrantData)
	segment.nodes = (new Node(i, node, quadrants[q], segment.colour, nodes) for node,i in segment.data) for segment, q in segmentData
	quadrant.drawNodes() for quadrant in quadrants

	node = svg.selectAll(".quadrant g.node")

	tick = (e) ->
		k = 0.2 * e.alpha
		(o.data.y += (o.quadrant.fy - o.data.y) * k; o.data.x += (o.quadrant.fx - o.data.x) * k) for o in segment.nodes for segment in segmentData
		
		node.each(collide(e.alpha))
			.attr(transform: (d) -> "translate(#{d.data.x},#{d.data.y})")

	collide = (alpha) ->
		(d) ->
			quadtree = d3.geom.quadtree(nodes)
			r = d.data.radius
			d.data.x = Math.max(d.data.radius, Math.min(width/2 - d.data.radius, d.data.x))
			d.data.y = Math.max(d.data.radius, Math.min(height/2 - d.data.radius, d.data.y))
			nx1 = d.data.x - r
			nx2 = d.data.x + r
			ny1 = d.data.y - r
			ny2 = d.data.y + r

			quadtree.visit((quad, x1, y1, x2, y2) ->
				if quad.point and !(quad.point is d.data)
					x = d.data.x - quad.point.x
					y = d.data.y - quad.point.y
					l = Math.sqrt(x * x + y * y)
					r = d.data.radius + quad.point.radius
					if (l < r)
						l = (l - r) / l * alpha * 10
						d.data.x -= x *= l
						d.data.y -= y *= l
						quad.point.x += x
						quad.point.y += y
				x1 > nx2 || x2 < nx1 || y1 > ny2 || y2 < ny1
		)

	force = d3.layout.force()
		.nodes(nodes)
		.size([width, height])
		.gravity(0)
		.charge(2)
		.on("tick", tick)
		.start()

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

class Node
	constructor: (index, data, quadrant, colour, nodesData) ->
		@index = index
		@quadrant = quadrant
		@data = data
		@colour = colour
		@children = data.children
		minR = 20
		maxR = 120
		minA = geo.areaFromRadius(minR)
		maxA = geo.areaFromRadius(maxR)
		circleScale = d3.scale.linear().domain([1, 100000])
		@quadrant.nodes.push this
		nodesData.push data
		data.x = quadrant.fx
		data.y = quadrant.fy
		data.radius = if data.years[0].val <= 0 then 0 else @calculateRadius(circleScale(data.years[0].val), data.years[0].val, minA, maxA)
	
	calculateRadius: (ratio, value, minArea, maxArea) => 
		area = ((maxArea - minArea) * ratio) + minArea
		geo.radiusFromArea(area)

class Quadrant
	constructor: (index, container, x, y, width, height, fx, fy, colour) ->
		@index = index
		@nodes = []
		@container = container
		@x = x
		@y = y
		@fx = fx
		@fy = fy
		@width = width
		@height = height
		@colour = colour

		@element = @container.append("g")
			.attr(class: "quadrant")
			.attr(transform: "translate(#{x},#{y})")

		@element.append("rect")
			.attr(width: width)
			.attr(height: height)
			.attr(fill: @colour)
			.attr("fill-opacity": 0.2)

	drawNodes: () ->
		node = @element.selectAll("g.node")
			.data(@nodes)
			.enter()
			.append("g")
			.attr(class: "node")
			.attr(transform: (d) -> "translate(#{d.quadrant.fx},#{d.quadrant.fy})")

		node.append("text")
			.attr("dy", ".3em")
			.style("text-anchor", "middle")
			.text((d) -> d.data.item.substring(0, d.data.radius / 3))
			.attr(fill: (d) -> d3.rgb(d.colour).darker(2))
			.style("font-size": "12px")

		node.append("circle")
			.attr(r: (d) -> d.data.radius)
			.attr(fill: (d) -> d.colour)
			.attr(stroke: (d) -> d.colour)
			.attr("stroke-width": (d) -> if d.data.children then 4 else 1)
			.attr("stroke-opacity": 0.4)
			.attr("fill-opacity": 0.6)
			.on("click", (d) -> console.log d)

		node.filter((d) -> d.data.children)
			.select("circle")
			.on("mouseover", () -> d3.select(this).transition().attr("stroke-opacity", 0.8))
			.on("mouseout", () -> d3.select(this).transition().attr("stroke-opacity", 0.4))
			.on("click", (d) =>
				if d.children
						d._children = d.children
						d.children = null
				else
					d.children = d._children
					d._children = null
					@nodes.push(new Node(i + d.index, node, d.quadrant, d.colour, node)) for node,i in d.children
					console.log @nodes
				@drawNodes()
			)

