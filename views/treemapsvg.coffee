geo = new Geo()

graph = (e, assetsData, expensesData, liabilitiesData, revenueData) ->
	console.log getEntity expensesData
	circleData = [
		{name: "liabilities", colour: "#c54927", data: getEntity liabilitiesData}
		{name: "assets", colour: "#2789ab", data: getEntity assetsData}
		{name: "expenses", colour: "#911048", data: getEntity expensesData}
		{name: "revenue", colour: "#27a776", data: getEntity revenueData}
	]

	width = 1000
	height = 800
	center = {x: width/2, y: height/2}
	svg = d3.select(".content").append("svg").attr(width: width).attr(height: height)
	layout = [
		{x: 0, y: 0}
		{x: center.x, y: 0 }
		{x: 0, y: center.y}
		{x: center.x, y: center.y}	
	]
	treemap = (new TreeMap(i, svg, width/2, height/2, layout[i].x, layout[i].y, c, c.colour) for c, i in circleData)

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

class TreeMap
	constructor: (index, container, w, h, x, y, data, colour) ->
		@index = index
		@container = container
		@total = d3.sum(data.data, (d) -> d.years[0].val)
		areaScale = d3.scale.linear().domain([0, 65000])
		areaRatio = w/h
		area = areaScale @total * w * h
		height = Math.sqrt(area/areaRatio)
		width = height * areaRatio

		console.log height, width

		treemap = d3.layout.treemap()
			.size([width, height])
			.sticky(true)
			.value((d) -> d.years[0].val)

		g = container.append("g")
			.attr("transform", "translate(" + x + "," + y + ")")

		cell = g.datum({item: data.name, children: data.data}).selectAll(".node")
				.data(treemap.nodes)
			.enter().append("g")
				.attr(class: "cell")
				.attr("transform", (d) -> "translate(" + d.x + "," + d.y + ")")

		cell.append("rect")
			.attr("width": (d) -> d.dx)
			.attr("height": (d) -> d.dy	)
			.style(fill: (d) -> if d.children then colour else "transparent")
			.attr(stroke: "white")

		cell.append("text")
			.attr(x: (d) -> d.x)
			.attr(y: (d) -> console.log d; d.y)
			.text((d) -> if d.children then null else d.item.substring(0, d.dx / 3))
