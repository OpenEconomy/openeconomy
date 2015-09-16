geo = new Geo()

graph = (e, fundingData, spendingData) ->
	segmentData = [
		{name: "funding", colour: "#27a776", data: getEntity fundingData}
		{name: "spending", colour: "#911048", data: getEntity spendingData}
	]
	nodes = []

	width = 1200
	height = 800
	center = {x: width/2, y: height/2}
	svg = d3.select(".content").append("svg").attr(width: width).attr(height: height)
	quadrantData = [{x:0,y:0, fx:width/2, fy: height/2}, {x:width/2,y:0, fx: 0, fy: height/2}]
	quadrants = (new Quadrant(i, svg, q.x, q.y, center.x, height, q.fx, q.fy) for q in quadrantData)
	segment.nodes = (new Node(i, node, quadrants[q], segment.colour, nodes) for node,i in segment.data) for segment, q in segmentData
	quadrant.drawNodes() for quadrant in quadrants
	console.log nodes
	node = svg.selectAll(".quadrant g.node")

	tick = (e) ->
		k = 0.1 * e.alpha
		(o.data.y += (o.quadrant.fy - o.data.y) * k; o.data.x += (o.quadrant.fx - o.data.x) * k) for o in segment.nodes for segment in segmentData
		
		node.each(collide(e.alpha))
			.attr(transform: (d) -> "translate(#{d.data.x},#{d.data.y})")

	collide = (alpha) ->
		(d) ->
			quadtree = d3.geom.quadtree(nodes)
			r = d.data.radius
			d.data.x = Math.max(d.data.radius, Math.min(width/2 - d.data.radius, d.data.x))
			d.data.y = Math.max(d.data.radius, Math.min(height - d.data.radius, d.data.y))
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
		.charge(10)
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
	console.log treeData
	treeData

generateTree = (node, dataMap, treeData) ->
	parent = dataMap[node.parent]
	if parent
		children = (parent.children || (parent.children = []))
		children.push(node)
	else
		treeData.push node

queue()
	.defer(d3.csv, 'data/bikevision/funding.csv')
	.defer(d3.csv, 'data/bikevision/spending.csv')
	.await(graph)

class Node
	constructor: (index, data, quadrant, colour, nodesData) ->
		@index = index
		@quadrant = quadrant
		@data = data
		@colour = colour
		minR = 20
		maxR = 100
		minA = geo.areaFromRadius(minR)
		maxA = geo.areaFromRadius(maxR)
		circleScale = d3.scale.linear().domain([1, 70])

		@quadrant.nodes.push this
		nodesData.push @data
		data.x = quadrant.fx
		data.y = quadrant.fy
		data.radius = if data.years[0].val <= 0 then 0 else @calculateRadius(circleScale(data.years[0].val), data.years[0].val, minA, maxA)
	
	calculateRadius: (ratio, value, minArea, maxArea) => 
		area = ((maxArea - minArea) * ratio) + minArea
		geo.radiusFromArea(area)

class Quadrant
	constructor: (index, container, x, y, width, height, fx, fy) ->
		@index = index
		@nodes = []
		@container = container
		@x = x
		@y = y
		@fx = fx
		@fy = fy
		@width = width
		@height = height

		@element = @container.append("g")
			.attr(class: "quadrant")
			.attr(transform: "translate(#{x},#{y})")

		@element.append("rect")
			.attr(width: width)
			.attr(height: height)
			.attr(fill: "transparent")
			.attr(stroke: "black")

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
			.attr(fill: (d) -> d.colour)

		node.append("circle")
			.attr(r: (d) -> d.data.radius)
			.attr(fill: (d) -> d.colour)
			.attr(stroke: (d) -> d.colour)
			.attr("fill-opacity": 0.5)
			.on("click", (d) -> console.log d)

