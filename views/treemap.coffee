geo = new Geo()

graph = (e, assetsData, expensesData, liabilitiesData, revenueData) ->
	console.log getEntity expensesData
	circleData = [
		{name: "revenue", colour: "#27a776", data: getEntity revenueData}
		{name: "expenses", colour: "#911048", data: getEntity expensesData}
		{name: "assets", colour: "#2789ab", data: getEntity assetsData}
		{name: "liabilities", colour: "#c54927", data: getEntity liabilitiesData}
	]
	console.table expensesData

	width = 1000
	height = 800
	center = {x: width/2, y: height/2}
	div = d3.select(".content").attr(class: "treemap")
	layout = [
		{x: ((r) -> center.x - r * 2), y: ((r) -> center.y - r * 2) }
		{x: ((r) -> center.x), y: ((r) -> center.y - r * 2) }
		{x: ((r) -> center.x - r * 2), y: ((r) -> center.y) }
		{x: ((r) -> center.x), y: ((r) -> center.y) }	
	]
	treemap = (new TreeMap(i, div, width/2, height/2, c, c.colour) for c, i in circleData)
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

class TreeMap
	constructor: (index, container, w, h, data, colour) ->
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

		div = container.append("div")
			.style("position", "absolute")
			.style("width", (width) + "px")
			.style("height", (height) + "px")

		node = div.datum({item: data.name, children: data.data}).selectAll(".node")
				.data(treemap.nodes)
			.enter().append("div")
				.attr(class: "node")
				.call(position)
				.style("background": (d) -> if d.children then colour else null)
				.text((d) -> if d.children then null else d.item)


position = () ->
	this.style("left": (d) -> d.x + "px")
		.style("top": (d) -> d.y + "px")
		.style("width": (d) -> Math.max(0, d.dx - 1) + "px")
		.style("height": (d) -> Math.max(0, d.dy - 1) + "px")