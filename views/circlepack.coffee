geo = new Geo()

graph = (e, assetsData, expensesData, liabilitiesData, revenueData) ->
	console.log getEntity expensesData
	circleData = [
		{name: "revenue", colour: "#27a776", data: getEntity revenueData}
		{name: "expenses", colour: "#911048", data: getEntity expensesData}
		{name: "assets", colour: "#2789ab", data: getEntity assetsData}
		{name: "liabilities", colour: "#c54927", data: getEntity liabilitiesData}
	]
	width = 1000
	height = 1000
	center = {x: width/2, y: height/2}
	minD = 60
	maxD = 400
	svg = d3.select(".content").append("svg").attr(width: width).attr(height: height)
	layout = [
		{x: ((r) -> center.x - r * 2), y: ((r) -> center.y - r * 2) }
		{x: ((r) -> center.x), y: ((r) -> center.y - r * 2) }
		{x: ((r) -> center.x - r * 2), y: ((r) -> center.y) }
		{x: ((r) -> center.x), y: ((r) -> center.y) }	
	]
	circles = (new Circle(i, svg.append("g").attr(class: c.name), layout[i].x, layout[i].y, c, maxD, c.colour) for c, i in circleData)
	# svg.append("line").attr(x1: center.x).attr(x2: center.x).attr(y1: 0).attr(y2: height).attr(stroke: "black")
	# svg.append("line").attr(y1: center.y).attr(y2: center.y).attr(x1: 0).attr(x2: height).attr(stroke: "black")

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

class Circle
	constructor: (index, container, xF, yF, data, maxD, colour) ->
		@index = index
		@nodes = []
		@container = container
		@total = d3.sum(data.data, (d) -> d.years[0].val)
		circleScale = d3.scale.linear().domain([0, 65000])
		maxA = geo.areaFromRadius(maxD/2)
		diameter = @calculateRadius(circleScale(@total), @total, maxA) * 2
		x = xF diameter/2
		y = yF diameter/2
		console.log diameter, x, y

		pack = d3.layout.pack()
			.size([diameter, diameter])
			.value((d) -> d.years[0].val)
		container.attr(transform: "translate(#{x},#{y})")
		node = container.datum({item: data.name, children: data.data}).selectAll(".node")
				.data(pack.nodes)
			.enter().append("g")
				.attr("class", (d) -> if d.children then "node" else "leaf node")
				.attr("transform", (d) -> "translate(" + d.x + "," + d.y + ")")

		node.filter((d) -> !d.children ).append("text")
			.attr("dy", ".3em")
			.style("text-anchor", "middle")
			.text((d) -> d.item.substring(0, d.r / 3))
			.attr(fill: colour)

		node.append("circle")
			.attr("r", (d) -> d.r)
			.attr(fill: colour)
			.attr("fill-opacity": 0.2)
			.attr(stroke: colour)

	calculateRadius: (ratio, value, maxArea) => 
		area = maxArea * ratio
		geo.radiusFromArea(area)

