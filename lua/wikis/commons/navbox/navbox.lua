---
-- @Liquipedia
-- wiki=commons
-- page=Module:Navbox
--
-- Please see https://github.com/Liquipedia/Lua-Modules to contribute
--

local NavboxModule = {}

local Arguments = require('Module:Arguments')
local Logic = require('Module:Logic')
local String = require('Module:StringUtils')
local Lua = require('Module:Lua')
local HtmlWidgets = Lua.import('Module:Widget/Html/All')

local Table = HtmlWidgets.Table
local Tr = HtmlWidgets.Tr
local Th = HtmlWidgets.Th
local Td = HtmlWidgets.Td
local Div = HtmlWidgets.Div
local Fragment = HtmlWidgets.Fragment

local navbar = require('Module:Navbar/dev/slothy')._navbar

-- variables
local border
local listNumbers = {}
local ODD_EVEN_MARKER = '\127_ODDEVEN_\127'
local RESTART_MARKER = '\127_ODDEVEN0_\127'
local REGEX_MARKER = '\127_ODDEVEN(%d?)_\127'

-- Applies alternating row styles to the navbox content
-- @param wikitext The wikitext content to process
-- @return The processed wikitext with style classes applied
local function stripeRows(wikitext)
	local orphanCategory = '[[Category:Navbox orphans]]'
	if border == 'subgroup' and not Logic.readBool(args.orphan) then
		return wikitext .. orphanCategory
	end

	-- Determine row styles based on evenodd argument
	local firstStyle, secondStyle = 'odd', 'even'
	if args.evenodd then
		if args.evenodd == 'swap' then
			firstStyle, secondStyle = secondStyle, firstStyle
		else
			firstStyle = args.evenodd
			secondStyle = firstStyle
		end
	end

	-- Create style changer function or string
	local styleChanger
	if firstStyle == secondStyle then
		styleChanger = firstStyle
	else
		local styleIndex = 0
		styleChanger = function(code)
			if code == '0' then
				styleIndex = 0
				return firstStyle
			end
			styleIndex = styleIndex + 1
			return styleIndex % 2 == 1 and firstStyle or secondStyle
		end
	end

	-- Apply styles and remove orphan category if needed
	local categoryPattern = orphanCategory:gsub('([%[%]])', '%%%1')
	return (wikitext:gsub(categoryPattern, ''):gsub(REGEX_MARKER, styleChanger))
end

-- Processes content items for proper formatting
-- @param item The content item to process
-- @return The processed content item
local function processContentItem(item)
	if item:sub(1, 2) == '{|' then
		return '\n' .. item ..'\n'
	end
	if item:match('^[*:;#]') then
		return '\n' .. item ..'\n'
	end
	return item
end

-- Inserts a navigation bar into the title cell
-- @param titleCellContent The content array for the title cell
local function insertNavigationBar(titleCellContent)
	if args.navbar ~= 'off' and args.navbar ~= 'plain' and not (not args.name and mw.getCurrentFrame():getParent():getTitle():gsub('/sandbox$', '') == 'Template:Navbox') then
		table.insert(titleCellContent, navbar{
			args.name,
			mini = 1,
			fontstyle = 'border:none;-moz-box-shadow:none;-webkit-box-shadow:none;box-shadow:none;',
			style = 'float:left; text-align:left',
		})
	end
end

-- Creates the title row for the navbox
-- @return A table row widget for the title, or nil if no title is provided
local function createTitleRow()
	if not args.title then return nil end

	local titleSpan = 2
	if args.imageleft then titleSpan = titleSpan + 1 end
	if args.image then titleSpan = titleSpan + 1 end

	local titleContent = {}
	insertNavigationBar(titleContent)

	table.insert(titleContent, Div{
		attributes = {id = mw.uri.anchorEncode(args.title)},
		css = {
			['font-size'] = border == 'subgroup' and '100%' or '114%',
			margin = '0 4em'
		},
		children = {processContentItem(args.title)}
	})

	return Tr{
		children = {
			Th{
				classes = {'navbox-title'},
				attributes = {scope = 'col', colspan = titleSpan},
				children = titleContent
			}
		}
	}
end

-- Calculates the column span needed for the navbox
-- @return The number of columns in the navbox
local function getSpanCount()
	local spanCount = 2
	if args.imageleft then spanCount = spanCount + 1 end
	if args.image then spanCount = spanCount + 1 end
	return spanCount
end

-- Creates the top section of the navbox (the "above" section)
-- @return A table row widget for the top section, or nil if no 'above' content is provided
local function createTopSection()
	if not args.above then return nil end

	return Tr{
		children = {
			Td{
				classes = {'navbox-abovebelow', 'wiki-backgroundcolor-light', args.aboveclass or nil},
				attributes = {colspan = getSpanCount()},
				children = {
					Div{
						children = {processContentItem(args.above)}
					}
				}
			}
		}
	}
end

-- Creates the bottom section of the navbox (the "below" section)
-- @return A table row widget for the bottom section, or nil if no 'below' content is provided
local function createBottomSection()
	if not args.below then return nil end

	return Tr{
		children = {
			Td{
				classes = {'navbox-abovebelow', 'wiki-backgroundcolor-light', args.belowclass or nil},
				attributes = {colspan = getSpanCount()},
				children = {
					Div{
						children = {processContentItem(args.below)}
					}
				}
			}
		}
	}
end

-- Creates a content list row for the navbox
-- @param rowIndex The index of the row being created
-- @param listNumber The list number for the current row
-- @return A table row widget containing the list content
local function createListRow(rowIndex, listNumber)
	local rowContent = {}

	-- Add the left image if this is the first row and an image is specified
	if rowIndex == 1 and args.imageleft then
		table.insert(rowContent, Td{
			classes = {'navbox-image'},
			css = {
				width = '1px',
				padding = '0px 2px 0px 0px'
			},
			cssText = args.imageleftstyle,
			attributes = {rowspan = #listNumbers},
			children = {
				Div{
					children = {processContentItem(args.imageleft)}
				}
			}
		})
	end

	-- Add the group header if specified
	local hasGroup = false
	if args['group' .. listNumber] then
		hasGroup = true
		table.insert(rowContent, Th{
			attributes = {scope = 'row'},
			classes = {'navbox-group'},
			css = {
				width = '1%',
				['padding-left'] = args.grouppadding or nil,
				['padding-right'] = args.grouppadding or nil
			},
			children = {args['group' .. listNumber]}
		})
	end

	-- Process list content with proper styling
	local listContent = args['list' .. listNumber]
	local rowStyle = ODD_EVEN_MARKER
	if listContent and listContent:sub(1, 12) == '</div><table' then
		rowStyle = listContent:find('<th[^>]*"navbox%-title"') and RESTART_MARKER or 'odd'
	end

	-- Define list cell properties
	local listCellProperties = {
		classes = {'navbox-list', 'navbox-' .. rowStyle},
		css = {padding = '0px'},
		children = {
			Div{
				classes = {'hlist'},
				css = {padding = (rowIndex == 1 and args.list1padding) or args.listpadding or '0em 0.25em'},
				children = {processContentItem(listContent)}
			}
		}
	}

	-- Adjust properties based on whether there's a group
	if hasGroup then
		table.insert(listCellProperties.classes, 'hlist-group')
		if not args.groupwidth then
			listCellProperties.css = listCellProperties.css or {}
			listCellProperties.css.width = '100%'
		end
	else
		listCellProperties.attributes = {colspan = 2}
	end

	table.insert(rowContent, Td(listCellProperties))

	-- Add the right image if this is the first row and an image is specified
	if rowIndex == 1 and args.image then
		table.insert(rowContent, Td{
			classes = {'navbox-image'},
			css = {
				width = '1px',
				padding = '0px 0px 0px 2px'
			},
			attributes = {rowspan = #listNumbers},
			children = {NavboxModule._makeImage(args.image, args.imagedark)}
		})
	end

	return Tr{children = rowContent}
end

-- Builds the main table structure for the navbox
-- @return The completed table widget
local function buildMainTable()
	local tableClasses = {'nowraplinks'}

	-- Set up table collapsibility if needed
	if args.title and (args.state ~= 'plain' and args.state ~= 'off') then
		table.insert(tableClasses, 'collapsible')
		table.insert(tableClasses, args.state or 'autocollapse')
	end

	local tableStyles = {['border-spacing'] = 0}

	-- Apply appropriate border styling
	if border == 'subgroup' or border == 'none' then
		table.insert(tableClasses, 'navbox-subgroup')
		table.insert(tableClasses, 'wiki-backgroundcolor-light')
		if args.style then
			tableStyles = String.merge(tableStyles, String.parseStyle(args.style))
		end
	else
		table.insert(tableClasses, 'navbox-inner')
	end

	-- Build table content by assembling all rows
	local tableContent = {}

	local titleRow = createTitleRow()
	if titleRow then table.insert(tableContent, titleRow) end

	local topSection = createTopSection()
	if topSection then table.insert(tableContent, topSection) end

	for index, listNumber in ipairs(listNumbers) do
		table.insert(tableContent, createListRow(index, listNumber))
	end

	local bottomSection = createBottomSection()
	if bottomSection then table.insert(tableContent, bottomSection) end

	-- Return the completed table
	return Table{
		classes = tableClasses,
		css = tableStyles,
		children = tableContent
	}
end

-- Creates an image element with optional dark mode support
-- @param lightImage The image to display in light mode or when dark mode is not specified
-- @param darkImage Optional image to display in dark mode
-- @return A div containing the image(s)
function NavboxModule._makeImage(lightImage, darkImage)
	if not darkImage then
		return Div{children = {processContentItem(lightImage)}}
	end

	return Fragment{
		children = {
			Div{classes = {'show-when-light-mode'}, children = {processContentItem(lightImage)}},
			Div{classes = {'show-when-dark-mode'}, children = {processContentItem(darkImage)}}
		}
	}
end

-- Main navbox rendering function
-- @param parameters The arguments table for the navbox
-- @return The HTML output for the navbox
function NavboxModule._navbox(parameters)
	args = parameters
	listNumbers = {}

	-- Collect all list numbers from arguments
	for key, _ in pairs(args) do
		if type(key) == 'string' then
			local listIdentifier = key:match('^list(%d+)$')
			if listIdentifier then
				local numberValue = tonumber(listIdentifier)
				if args[key] ~= nil then
					table.insert(listNumbers, numberValue)
				end
			end
		end
	end
	table.sort(listNumbers)

	-- Determine border style
	border = mw.text.trim(args.border or args[1] or '')
	if border == 'child' then
		border = 'subgroup'
	end

	-- Build the main table
	local mainTable = buildMainTable()
	local output

	-- Wrap the table with appropriate container based on border style
	if border == 'none' then
		output = Div{
			attributes = {
				role = 'navigation',
				['data-nosnippet'] = 0,
				['aria-labelledby'] = args.title and mw.uri.anchorEncode(args.title) or nil,
				['aria-label'] = not args.title and 'Navbox' or nil
			},
			classes = {'navigation-not-searchable'},
			children = {mainTable}
		}
	elseif border == 'subgroup' then
		output = Fragment{
			children = {
				'</div>',
				mainTable,
				'<div>'
			}
		}
	else
		output = Div{
			attributes = {
				role = 'navigation',
				['data-nosnippet'] = 0,
				['aria-labelledby'] = args.title and mw.uri.anchorEncode(args.title) or nil,
				['aria-label'] = not args.title and 'Navbox' or nil
			},
			classes = {'navigation-not-searchable', 'navbox'},
			cssText = args.style,
			css = {padding = '3px'},
			children = {mainTable}
		}
	end

	-- Apply row striping and return the final HTML
	return stripeRows(tostring(output:render()))
end

-- Main entry point function for the module
-- @param frame The frame object passed from the wiki template
-- @return The HTML output for the navbox
function NavboxModule.navbox(frame)
	local args = Arguments.getArgs(frame, {wrappers = 'Template:Navbox'})

	-- Initialize arguments to ensure they're processed
	local dummyVar
	dummyVar = args.title
	dummyVar = args.above
	for i = 1, 20 do
		dummyVar = args["group" .. tostring(i)]
		dummyVar = args["list" .. tostring(i)]
	end
	dummyVar = args.below

	return NavboxModule._navbox(args)
end

return NavboxModule
