geo = new Geo()

graph = (e, assetsData, expensesData, liabilitiesData, revenueData) ->
	segmentData = [
		{name: "liabilities", colour: "#c54927", data: getEntity liabilitiesData}
		{name: "assets", colour: "#2789ab", data: getEntity assetsData}
		{name: "expenses", colour: "#911048", data: getEntity expensesData}
		{name: "revenue", colour: "#27a776", data: getEntity revenueData}
	]
	# {data: entities, name: segmentname, nodes}
	nodes = []

	width = 1200
	height = 800
	center = {x: width/2, y: height/2}
	# minR = 10
	maxR = 80
	rings = 6
	ringMin = 80
	ringMax = height/2 - maxR
	nodeScale = d3.scale.linear().range([ringMin, ringMax])
	ringScale = d3.scale.linear().domain([rings - 1, 0]).range([ringMin, ringMax])

	svg = d3.select(".content").append("svg").attr(width: width).attr(height: height)
	quadrantData = [{x:0,y:0, fx:width/2, fy: height/2}, {x:width/2,y:0, fx: 0, fy: height/2}, {x:0,y:height/2, fx: width/2, fy: 0}, {x:width/2,y:height/2, fx: 0, fy: 0}]
	quadrants = (new Quadrant(i, svg, q.x, q.y, center.x, center.y, q.fx, q.fy) for q, i in quadrantData)
	segment.nodes = (new Node(i, node, quadrants[q], segment.colour, nodes, nodeScale) for node,i in segment.data) for segment, q in segmentData
	quadrant.drawNodes() for quadrant in quadrants
	console.log quadrants
	# extentLiab = d3.extent(liabilities, (d) -> d.years[0].val)



	svg.selectAll('circle.ring')
	  .data([0..rings - 1])
	  .enter()
	  .append('circle')
	  .attr(class: 'ring')
	  .attr(r: (d) => ringScale d)
	  .attr(cx: center.x)
	  .attr(cy: center.y)
	  .attr(fill: 'none')
	  .attr(stroke: '#000000')
	  .attr(opacity: 0.1)

	node = svg.selectAll(".quadrant circle.node")
	
	force = d3.layout.force()
		.nodes(nodes)
		.size([width, height])
		.gravity(0)
		.charge(10)
		.start()

getEntity = (data) ->
	keys = d3.keys data[0]
	years = (d["Year"] for d in data)
	entities = keys.filter((d) -> !(d is "Total" or d is "Year"))
	output = ({years: [], entity: e} for e in entities)
	e.years.push({year: year, val: data[yi][e.entity]}) for year,yi in years for e, ei in output
	output
    
queue()
	.defer(d3.csv, 'data/WA2/assets.csv')
	.defer(d3.csv, 'data/WA2/expenses.csv')
	.defer(d3.csv, 'data/WA2/liabilities.csv')
	.defer(d3.csv, 'data/WA2/revenue.csv')
	.await(graph)

class Node
	constructor: (index, data, quadrant, colour, nodesData, ringScale) ->
		@index = index
		@quadrant = quadrant
		@data = data
		@colour = colour
		minR = 20
		maxR = 80
		minA = geo.areaFromRadius(minR)
		maxA = geo.areaFromRadius(maxR)
		circleScale = d3.scale.linear().domain([0, 40000])
		@r = ringScale circleScale(data.years[0].val)
		console.log @r

		@quadrant.nodes.push this
		nodesData.push @data
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
		@segment = 360/4 * index

		@element = @container.append("g")
			.attr(class: "quadrant")
			.attr(transform: "translate(#{x},#{y})")

		@element.append("rect")
			.attr(width: width)
			.attr(height: height)
			.attr(fill: "transparent")
			.attr(stroke: "black")
			.attr("stroke-opacity": 0.2)

	drawNodes: () ->
		# coord = geo.p2c(r, index * quadrant.segment)
		# data.x = coord.x
		# data.y = coord.y
		numNodes = @nodes.length

		(coord = geo.p2c(node.r, i/numNodes * 90 - @segment); node.data.x = coord.x + @fx; node.data.y = coord.y + @fy) for node,i in @nodes

		@element.selectAll("circle.node")
			.data(@nodes)
			.enter()
			.append("circle")
			.attr(class: "node")
			.attr(r: (d) -> d.data.radius)
			.attr(cx: (d) -> d.data.x)
			.attr(cy: (d) -> d.data.y)
			.attr(fill: (d) -> d.colour)
			.attr(stroke: (d) -> d.colour)
			.attr("fill-opacity": 0.6)
			.on("click", (d) -> console.log d)

