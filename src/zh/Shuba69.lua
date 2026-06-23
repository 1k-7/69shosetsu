-- {"id":690069,"ver":"1.0.9","libVer":"1.0.0","author":"Codex","dep":["dkjson>=1.0.0"]}

local json = Require("dkjson")

local baseURL = "https://69shuba.com"
local imageURL = "https://cdn.cdnshu.com/images/apple-touch-icon.png"

local translateURL = "https://translate-pa.googleapis.com/v1/translateHtml"
local translateKey = "AIzaSyATBXajvzQLTDHEQbcpq0Ihe0vWDHmO520"
local jsonMediaType = MediaType("application/json+protobuf; charset=utf-8")
local processorURL = ""
local processorToken = ""
local processorMediaType = MediaType("application/json; charset=utf-8")
local formMediaType = MediaType("application/x-www-form-urlencoded; charset=UTF-8")
local userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126 Safari/537.36"
local gb18030Charset = nil
local utf8Charset = nil
local translatePlainTexts = nil

pcall(function()
	local Charset = luajava.bindClass("java.nio.charset.Charset")
	local function charsetForName(name)
		local ok, charset = pcall(function()
			return Charset:forName(name)
		end)
		if ok and charset then
			return charset
		end

		ok, charset = pcall(function()
			return Charset.forName(name)
		end)
		if ok and charset then
			return charset
		end

		return nil
	end

	gb18030Charset = charsetForName("GB18030")
	utf8Charset = charsetForName("UTF-8")
end)

local ORDER_FILTER_ID = 2
local STATUS_FILTER_ID = 3
local GENRE_FILTER_ID = 4

local ORDER_NAMES = {
	"Popularity",
	"Recommended",
	"New Books"
}

local ORDER_PARAMS = {
	"monthvisit",
	"allvote",
	"newhot"
}

local STATUS_NAMES = {
	"All",
	"Completed",
	"Ongoing"
}

local STATUS_PARAMS = {
	"0",
	"1",
	"2"
}

local GENRE_NAMES = {
	"All",
	"Fantasy",
	"Cultivation/Wuxia",
	"Romance",
	"History/Military",
	"Games",
	"Sci-fi/Space",
	"Mystery/Thriller",
	"Fanfiction",
	"Urban",
	"Workplace",
	"Time Travel",
	"Youth/Campus"
}

local GENRE_PARAMS = {
	"0",
	"1",
	"2",
	"3",
	"4",
	"5",
	"6",
	"7",
	"8",
	"9",
	"10",
	"11",
	"12"
}

local function trim(str)
	if not str then
		return ""
	end
	str = str:gsub("%s+", " ")
	str = str:gsub("^%s+", "")
	return str:gsub("%s+$", "")
end

local function urlEncode(value)
	value = tostring(value or "")
	local okEncoder, Encoder = pcall(function()
		return luajava.bindClass("java.net.URLEncoder")
	end)
	if okEncoder and Encoder then
		local okEncoded, encoded = pcall(function()
			return Encoder:encode(value, "UTF-8")
		end)
		if okEncoded and encoded then
			return tostring(encoded)
		end

		okEncoded, encoded = pcall(function()
			return Encoder.encode(value, "UTF-8")
		end)
		if okEncoded and encoded then
			return tostring(encoded)
		end
	end

	return (value:gsub("([^%w%-_%.~])", function(char)
		return string.format("%%%02X", string.byte(char))
	end))
end

local function shrinkURL(url)
	if not url then
		return ""
	end

	url = url:gsub("^https?://www%.69shuba%.com", "")
	return url:gsub("^https?://69shuba%.com", "")
end

local function expandURL(url)
	if not url or url == "" then
		return baseURL
	end
	if url:match("^https?://") then
		return url
	end
	if url:sub(1, 1) ~= "/" then
		url = "/" .. url
	end
	return baseURL .. url
end

local function browserHeaders(referer)
	local builder = HeadersBuilder()
		:add("User-Agent", userAgent)
		:add("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")
		:add("Accept-Language", "zh-CN,zh;q=0.9,en;q=0.8")
		:add("Cache-Control", "no-cache")

	if referer and referer ~= "" then
		builder:add("Referer", referer)
	end

	return builder:build()
end

local function formHeaders(referer)
	local builder = HeadersBuilder()
		:add("User-Agent", userAgent)
		:add("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")
		:add("Accept-Language", "zh-CN,zh;q=0.9,en;q=0.8")
		:add("Cache-Control", "no-cache")
		:add("Origin", baseURL)

	if referer and referer ~= "" then
		builder:add("Referer", referer)
	end

	return builder:build()
end

local function textOf(element)
	return element and trim(element:text()) or ""
end

local function attrOf(element, name)
	if not element then
		return ""
	end
	return element:attr(name) or ""
end

local function javaString(value)
	if type(value) == "string" then
		return value
	end

	local ok, str = pcall(function()
		return value:toString()
	end)
	if ok and str then
		return tostring(str)
	end

	return tostring(value)
end

local function isChallengeHTML(html)
	html = (html or ""):lower()
	if html == "" then
		return false
	end
	return html:find("enable javascript and cookies to continue", 1, true) ~= nil
		or html:find("just a moment", 1, true) ~= nil and html:find("cf_chl", 1, true) ~= nil
		or html:find("challenge-platform", 1, true) ~= nil
		or html:find("challenges.cloudflare.com/turnstile", 1, true) ~= nil
		or html:find("performing security verification", 1, true) ~= nil
end

local decodeResponseHTML

local function getDecodedHTML(url, headers)
	if not gb18030Charset or not utf8Charset then
		return nil
	end

	local okResponse, response = pcall(function()
		if headers then
			return Request(GET(url, headers))
		end
		return Request(GET(url))
	end)
	if not okResponse or not response then
		return nil
	end

	return decodeResponseHTML and decodeResponseHTML(response) or nil
end

local function postDecodedHTML(url, bodyText, headers)
	if not gb18030Charset or not utf8Charset then
		return nil
	end

	local body = RequestBody(bodyText, formMediaType)
	local okResponse, response = pcall(function()
		return Request(POST(url, headers, body))
	end)
	if not okResponse or not response then
		return nil
	end

	return decodeResponseHTML and decodeResponseHTML(response) or nil
end

decodeResponseHTML = function(response)
	local okCode, code = pcall(function()
		return response:code()
	end)
	if okCode and code and code >= 400 then
		return nil
	end

	local okBytes, bytes = pcall(function()
		return response:body():bytes()
	end)
	if not okBytes or not bytes then
		return nil
	end

	local function decodeWith(charset)
		local okText, text = pcall(function()
			return luajava.newInstance("java.lang.String", bytes, charset)
		end)
		if okText and text then
			return javaString(text)
		end
		return nil
	end

	local contentType = ""
	pcall(function()
		contentType = response:headers():get("Content-Type") or ""
	end)
	contentType = contentType:lower()

	if contentType:find("gbk", 1, true) or contentType:find("gb2312", 1, true) or contentType:find("gb18030", 1, true) then
		return decodeWith(gb18030Charset)
	end

	local utf8HTML = decodeWith(utf8Charset)
	if utf8HTML and not utf8HTML:find("\239\191\189", 1, true) then
		return utf8HTML
	end

	return decodeWith(gb18030Charset) or utf8HTML
end

local function getDocument(url, headers, allowFallback)
	local html = getDecodedHTML(url, headers)
	if html and html ~= "" and not isChallengeHTML(html) then
		return Document(html)
	end
	if allowFallback == false then
		return Document("<html></html>")
	end

	local okDocument, document = pcall(function()
		return GETDocument(url)
	end)
	if okDocument and document then
		return document
	end
	return Document("<html></html>")
end

local function callProcessor(action, payload)
	if not processorURL or processorURL == "" then
		return nil
	end

	payload = payload or {}
	payload.action = action
	local body = RequestBody(json.encode(payload), processorMediaType)
	local headersBuilder = HeadersBuilder()
		:add("Content-Type", "application/json")
		:add("Accept", "application/json")

	if processorToken and processorToken ~= "" then
		headersBuilder:add("Authorization", "Bearer " .. processorToken)
	end

	local ok, response = pcall(function()
		return Request(POST(processorURL, headersBuilder:build(), body))
	end)
	if not ok or not response then
		return nil
	end

	local okCode, code = pcall(function()
		return response:code()
	end)
	if okCode and code and code >= 400 then
		return nil
	end

	local okBody, responseBody = pcall(function()
		return response:body():string()
	end)
	if not okBody or not responseBody or responseBody == "" then
		return nil
	end

	local okJSON, decoded = pcall(function()
		return json.decode(responseBody)
	end)
	if not okJSON or type(decoded) ~= "table" then
		return nil
	end

	return decoded
end

local function firstElement(element, selectors)
	if not element then
		return nil
	end
	for _, selector in ipairs(selectors) do
		local selected = element:selectFirst(selector)
		if selected then
			return selected
		end
	end
	return nil
end

local function normalizeImageURL(url)
	if not url or url == "" then
		return ""
	end
	if url:match("^//") then
		return "https:" .. url
	end
	if url:match("^https?://") then
		return url
	end
	return expandURL(url)
end

local function bookIDFromURL(url)
	url = (url or ""):gsub("[#?].*$", "")
	return url:match("/book/(%d+)%.html$")
		or url:match("/book/(%d+)%.htm$")
		or url:match("/book/(%d+)/")
		or url:match("/book/(%d+)$")
end

local function bookRefererFromChapterURL(url)
	local id = (url or ""):match("/txt/(%d+)/")
	if id then
		return baseURL .. "/book/" .. id .. "/"
	end
	return baseURL .. "/"
end

local function parseNovelLink(url)
	local shrunk = shrinkURL(url)
	local id = bookIDFromURL(shrunk)
	if id then
		return "/book/" .. id .. ".htm"
	end
	return shrunk
end

local function parseNovelCard(element)
	local titleElement = nil
	if element:tagName() == "a" and attrOf(element, "href"):find("/book/") then
		titleElement = element
	else
		titleElement = firstElement(element, {
			'.newnav h3 a[href*="/book/"]',
			'h3 a[href*="/book/"]',
			'h1 a[href*="/book/"]',
			'a[href*="/book/"]'
		})
	end

	local imageElement = firstElement(element, {
		"a.imgbox img",
		".bookimg2 img",
		"img"
	})

	if not titleElement then
		titleElement = element:selectFirst('a[href*="/book/"]')
	end

	if not titleElement then
		return nil
	end

	local title = textOf(titleElement)
	if title == "" and imageElement then
		title = attrOf(imageElement, "title")
		if title == "" then
			title = attrOf(imageElement, "alt")
		end
	end

	local link = parseNovelLink(titleElement:attr("href"))
	if title == "" or link == "" then
		return nil
	end

	return Novel {
		title = title,
		link = link,
		imageURL = normalizeImageURL(attrOf(imageElement, "data-src") ~= "" and attrOf(imageElement, "data-src") or attrOf(imageElement, "src"))
	}, link, title
end

local function parseNovelCards(elements)
	local seen = {}
	local novels = {}
	local titles = {}

	map(elements, function(element)
		local novel, link, title = parseNovelCard(element)
		if novel and link ~= "" and not seen[link] then
			seen[link] = true
			novels[#novels + 1] = novel
			titles[#titles + 1] = title
		end
	end)

	if translatePlainTexts and #titles > 0 then
		local translatedTitles = translatePlainTexts(titles)
		for i, translatedTitle in ipairs(translatedTitles) do
			if translatedTitle and translatedTitle ~= "" and novels[i] then
				novels[i]:setTitle(translatedTitle)
			end
		end
	end

	return novels
end

local function parseProcessorNovels(items)
	if type(items) ~= "table" then
		return nil
	end

	local seen = {}
	local novels = {}
	local titles = {}

	for _, item in ipairs(items) do
		local title = trim(item.title or item.name or "")
		local link = parseNovelLink(item.link or item.url or "")
		if title ~= "" and link ~= "" and not seen[link] then
			seen[link] = true
			novels[#novels + 1] = Novel {
				title = title,
				link = link,
				imageURL = normalizeImageURL(item.imageURL or item.image or "")
			}
			titles[#titles + 1] = title
		end
	end

	if translatePlainTexts and #titles > 0 then
		local translatedTitles = translatePlainTexts(titles)
		for i, translatedTitle in ipairs(translatedTitles) do
			if translatedTitle and translatedTitle ~= "" and novels[i] then
				novels[i]:setTitle(translatedTitle)
			end
		end
	end

	return novels
end

local function parseListingPage(url)
	local document = getDocument(url)
	local list = document:select("#article_list_content > li")
	if list:size() > 0 then
		return parseNovelCards(list)
	end

	local ranking = document:select('.ranking a[href*="/book/"]')
	if ranking:size() > 0 then
		return parseNovelCards(ranking)
	end

	return parseNovelCards(document:select('a[href*="/book/"]'))
end

local function listingURL(path, page)
	if page <= 1 then
		return baseURL .. path
	end

	if path:match("%.html$") then
		return baseURL .. path:gsub("%.html$", "_" .. page .. ".html")
	end
	if path:match("%.htm$") then
		return baseURL .. path:gsub("%.htm$", "_" .. page .. ".htm")
	end
	return baseURL .. path:gsub("/$", "") .. "_" .. page .. ".htm"
end

local function listFromPath(path)
	return function(data)
		local page = data[PAGE]
		if not page or page < 1 then
			page = 1
		end
		return parseListingPage(listingURL(path, page))
	end
end

local function filteredList(data)
	local page = data[PAGE]
	if not page or page < 1 then
		page = 1
	end

	local order = ORDER_PARAMS[(data[ORDER_FILTER_ID] or 0) + 1] or ORDER_PARAMS[1]
	local status = STATUS_PARAMS[(data[STATUS_FILTER_ID] or 0) + 1] or STATUS_PARAMS[1]
	local genre = GENRE_PARAMS[(data[GENRE_FILTER_ID] or 0) + 1] or GENRE_PARAMS[1]

	return parseListingPage(baseURL .. "/novels/" .. order .. "_" .. genre .. "_" .. status .. "_" .. page .. ".htm")
end

local function parseSearchDocument(document)
	local list = document:select("#article_list_content > li, .search-list li, .bookbox, .booklist li")
	if list:size() > 0 then
		return parseNovelCards(list)
	end
	return parseNovelCards(document:select('a[href*="/book/"]'))
end

local function parseSearchPage(url)
	return parseSearchDocument(getDocument(url, browserHeaders(baseURL .. "/")))
end

local function postSearchPage(url, bodyText)
	local html = postDecodedHTML(url, bodyText, formHeaders(baseURL .. "/"))
	if html and html ~= "" and not isChallengeHTML(html) then
		return parseSearchDocument(Document(html))
	end
	return {}
end

local parseNovel

local function directBookLinkFromQuery(query)
	query = trim(query)
	if query == "" then
		return nil
	end

	local id = bookIDFromURL(query) or query:match("/txt/(%d+)/")
	if not id and query:match("^%d+$") then
		id = query
	end
	if not id then
		return nil
	end

	return "/book/" .. id .. ".htm"
end

local function parseDirectSearchNovel(link)
	local document = getDocument(expandURL(link), browserHeaders(baseURL .. "/"))
	local title = textOf(firstElement(document, { ".booknav2 h1", "h1" }))
	if title == "" or title == "69shuba.com" or title == "www.69shuba.com" then
		return nil
	end

	local image = firstElement(document, { ".bookimg2 img", ".bookbox img", "img[title]" })
	if translatePlainTexts then
		local translated = translatePlainTexts({ title })
		title = translated[1] ~= "" and translated[1] or title
	end

	return Novel {
		title = title,
		link = parseNovelLink(link),
		imageURL = normalizeImageURL(attrOf(image, "src"))
	}
end

local function directBookSearch(query)
	local link = directBookLinkFromQuery(query)
	if not link then
		return nil
	end

	local ok, novel = pcall(function()
		return parseDirectSearchNovel(link)
	end)
	if ok and novel then
		return { novel }
	end

	return {}
end

local function search(data)
	data = data or {}
	local query = trim(data[QUERY] or "")
	if query == "" then
		return filteredList(data)
	end

	local directNovels = directBookSearch(query)
	if directNovels then
		return directNovels
	end

	local processorResult = callProcessor("search", {
		query = query,
		source = "zh-CN",
		target = "en"
	})
	local processorNovels = processorResult and parseProcessorNovels(processorResult.novels)
	if processorNovels and #processorNovels > 0 then
		return processorNovels
	end

	local encodedQuery = urlEncode(query)
	local urls = {
		baseURL .. "/modules/article/search.php?searchkey=" .. encodedQuery,
		baseURL .. "/modules/article/search.php?searchtype=articlename&searchkey=" .. encodedQuery,
		baseURL .. "/search.php?q=" .. encodedQuery,
		baseURL .. "/s.php?searchkey=" .. encodedQuery,
		baseURL .. "/search.htm?keyword=" .. encodedQuery
	}

	for _, url in ipairs(urls) do
		local novels = parseSearchPage(url)
		if #novels > 0 then
			return novels
		end
	end

	local postTargets = {
		baseURL .. "/modules/article/search.php",
		baseURL .. "/search.php",
		baseURL .. "/s.php"
	}
	local postBodies = {
		"searchkey=" .. encodedQuery,
		"searchtype=articlename&searchkey=" .. encodedQuery,
		"q=" .. encodedQuery,
		"keyword=" .. encodedQuery
	}

	for _, url in ipairs(postTargets) do
		for _, bodyText in ipairs(postBodies) do
			local novels = postSearchPage(url, bodyText)
			if #novels > 0 then
				return novels
			end
		end
	end

	return {}
end

local function parseStatus(text)
	text = text or ""
	if text:find("全本") or text:find("完结") then
		return NovelStatus.COMPLETED
	end
	if text:find("连载") then
		return NovelStatus.PUBLISHING
	end
	return NovelStatus.UNKNOWN
end

local function parseMetadataLine(text, label)
	return trim((text or ""):match(label .. "[:：]%s*(.+)") or "")
end

parseNovel = function(novelURL, loadChapters)
	local infoURL = expandURL(parseNovelLink(novelURL))
	local document = getDocument(infoURL)

	local nav = document:selectFirst(".booknav2")
	local title = textOf(firstElement(document, { ".booknav2 h1", "h1" }))
	local image = firstElement(document, { ".bookimg2 img", ".bookbox img", "img[title]" })
	local tags = map(document:select("#tagul a, .tagul a"), textOf)

	local author = ""
	local genres = {}
	local statusText = ""
	local description = ""

	if nav then
		map(nav:select("p"), function(row)
			local rowText = textOf(row)
			local parsedAuthor = parseMetadataLine(rowText, "作者")
			local parsedGenre = parseMetadataLine(rowText, "分类")
			if parsedAuthor ~= "" then
				author = parsedAuthor
			elseif parsedGenre ~= "" then
				genres = { parsedGenre }
			elseif rowText:find("连载") or rowText:find("全本") or rowText:find("完结") then
				statusText = rowText
			end
		end)
	end

	local descriptionElement = firstElement(document, {
		".tabsnav .tab-content",
		".bookintro",
		".intro",
		"#intro"
	})
	if descriptionElement then
		description = textOf(descriptionElement)
		description = description:gsub("^简介%s*", "")
	end

	local translatedTitle = title
	local translatedDescription = description
	if translatePlainTexts then
		local translatedInfo = translatePlainTexts({ title, description })
		translatedTitle = translatedInfo[1] ~= "" and translatedInfo[1] or title
		translatedDescription = translatedInfo[2] ~= "" and translatedInfo[2] or description
		tags = translatePlainTexts(tags)
		genres = translatePlainTexts(genres)
	end

	local novelInfo = NovelInfo {
		title = translatedTitle,
		link = parseNovelLink(novelURL),
		imageURL = normalizeImageURL(attrOf(image, "src")),
		description = translatedDescription,
		authors = author ~= "" and { author } or {},
		genres = genres,
		tags = tags,
		status = parseStatus(statusText),
		language = "en"
	}

	if loadChapters then
		local id = bookIDFromURL(novelURL) or bookIDFromURL(infoURL)
		local catalogURL = id and (baseURL .. "/book/" .. id .. "/") or infoURL:gsub("%.htm$", "/")
		local catalog = getDocument(catalogURL)
		local chapterElements = catalog:select('#catalog li[data-num] a[href*="/txt/"]')
		if chapterElements:size() == 0 then
			chapterElements = document:select('a[href*="/txt/"]')
		end

		local chapterElementList = {}
		map(chapterElements, function(chapter)
			chapterElementList[#chapterElementList + 1] = chapter
		end)

		local chapterTitles = {}
		local chapters = {}
		for i = #chapterElementList, 1, -1 do
			local chapter = chapterElementList[i]
			local chapterTitle = textOf(chapter:selectFirst("span")) ~= "" and textOf(chapter:selectFirst("span")) or textOf(chapter)
			chapterTitles[#chapterTitles + 1] = chapterTitle
			chapters[#chapters + 1] = NovelChapter {
				title = chapterTitle,
				link = shrinkURL(chapter:attr("href")),
				order = i,
				release = textOf(chapter:selectFirst("small")) ~= "" and textOf(chapter:selectFirst("small")) or attrOf(chapter:parent(), "data-etime")
			}
		end
		chapters = AsList(chapters)
		if translatePlainTexts and #chapterTitles > 0 then
			local translatedChapterTitles = translatePlainTexts(chapterTitles)
			for i, translatedTitle in ipairs(translatedChapterTitles) do
				if translatedTitle and translatedTitle ~= "" and chapters[i] then
					chapters[i]:setTitle(translatedTitle)
				end
			end
		end

		novelInfo:setChapters(chapters)
	end

	return novelInfo
end

local function removeUselessContent(element)
	element:select("script, style, iframe, ins, .yueduad1, #txtright, .txtinfo, .tools, .readpage, .jubao, .hide720, .setbox, .ad, [id*=ad], [class*=ad]"):remove()
	element:select("a[href*=javascript]"):remove()
end

local function collectParagraphs(element)
	local html = tostring(element)
	html = html
		:gsub("<br%s*/?>", "\n")
		:gsub("</p>", "\n")
		:gsub("</div>", "\n")
		:gsub("<script.->.-</script>", "\n")
		:gsub("<style.->.-</style>", "\n")
		:gsub("<[^>]->", "")
		:gsub("&nbsp;", " ")
		:gsub("　", " ")
		:gsub("\r", "\n")

	local paragraphs = {}
	for line in html:gmatch("[^\n]+") do
		line = trim(line)
		if line ~= "" then
			paragraphs[#paragraphs + 1] = line
		end
	end

	return paragraphs
end

local function escapeHTML(text)
	text = text or ""
	text = text:gsub("&", "&amp;")
	text = text:gsub("<", "&lt;")
	text = text:gsub(">", "&gt;")
	return text:gsub(string.char(34), "&quot;")
end

local function paragraphsToHTML(paragraphs)
	local html = {}
	for _, paragraph in ipairs(paragraphs) do
		html[#html + 1] = "<p>" .. escapeHTML(paragraph) .. "</p>"
	end
	return table.concat(html, "")
end

local function translateHTML(html)
	if html == "" then
		return html
	end

	local processorResult = callProcessor("translate_html", {
		html = html,
		source = "zh-CN",
		target = "en"
	})
	if processorResult and processorResult.html and processorResult.html ~= "" then
		return processorResult.html
	end

	local payload = {
		{ html, "zh-CN", "en" },
		"wt_lib"
	}
	local body = RequestBody(json.encode(payload), jsonMediaType)
	local headers = HeadersBuilder()
		:add("Content-Type", "application/json+protobuf")
		:add("Origin", baseURL)
		:add("X-Goog-Api-Key", translateKey)
		:build()

	local ok, response = pcall(function()
		return Request(POST(translateURL, headers, body))
	end)

	if not ok or not response then
		return html
	end

	local okBody, responseBody = pcall(function()
		return response:body():string()
	end)
	if not okBody or not responseBody or responseBody == "" then
		return html
	end

	local okJSON, decoded = pcall(function()
		return json.decode(responseBody)
	end)
	if not okJSON or not decoded or not decoded[1] then
		return html
	end

	if type(decoded[1]) == "table" then
		local fragments = {}
		for _, fragment in ipairs(decoded[1]) do
			fragment = tostring(fragment)
			if fragment:find("<%s*/?%s*p") or fragment:find("<%s*br") then
				fragments[#fragments + 1] = fragment
			else
				fragments[#fragments + 1] = "<p>" .. escapeHTML(fragment) .. "</p>"
			end
		end
		return table.concat(fragments, "")
	end

	local translated = tostring(decoded[1])
	if translated:find("<%s*/?%s*p") or translated:find("<%s*br") then
		return translated
	end
	return "<p>" .. escapeHTML(translated) .. "</p>"
end

function translatePlainTexts(texts)
	texts = texts or {}
	local translated = {}
	local batch = {}
	local positions = {}
	local batchLength = 0

	for i, text in ipairs(texts) do
		translated[i] = text
	end

	local function flush()
		if #batch == 0 then
			return
		end

		local translatedHTML = translateHTML(paragraphsToHTML(batch))
		local translatedDoc = Document(translatedHTML)
		local translatedParagraphs = translatedDoc:select("p")

		if translatedParagraphs:size() > 0 then
			local translatedIndex = 1
			map(translatedParagraphs, function(paragraph)
				local position = positions[translatedIndex]
				local text = textOf(paragraph)
				if position and text ~= "" then
					translated[position] = text
				end
				translatedIndex = translatedIndex + 1
			end)
		end

		batch = {}
		positions = {}
		batchLength = 0
	end

	for i, text in ipairs(texts) do
		text = trim(text)
		if text ~= "" then
			if batchLength > 0 and batchLength + #text > 4500 then
				flush()
			end
			batch[#batch + 1] = text
			positions[#positions + 1] = i
			batchLength = batchLength + #text
		end
	end
	flush()

	return translated
end

local function translateParagraphs(paragraphs)
	local translated = {}
	local batch = {}
	local batchLength = 0

	local function flush()
		if #batch == 0 then
			return
		end

		local sourceHTML = paragraphsToHTML(batch)
		local translatedHTML = translateHTML(sourceHTML)
		local translatedDoc = Document(translatedHTML)
		local translatedParagraphs = translatedDoc:select("p")

		if translatedParagraphs:size() > 0 then
			map(translatedParagraphs, function(paragraph)
				local text = textOf(paragraph)
				if text ~= "" then
					translated[#translated + 1] = text
				end
			end)
		else
			for _, paragraph in ipairs(batch) do
				translated[#translated + 1] = paragraph
			end
		end

		batch = {}
		batchLength = 0
	end

	for _, paragraph in ipairs(paragraphs) do
		if batchLength > 0 and batchLength + #paragraph > 4500 then
			flush()
		end
		batch[#batch + 1] = paragraph
		batchLength = batchLength + #paragraph
	end
	flush()

	return translated
end

local function getPassage(chapterURL)
	local expandedURL = expandURL(chapterURL)
	local referer = bookRefererFromChapterURL(expandedURL)
	local processorResult = callProcessor("chapter_html", {
		url = expandedURL,
		referer = referer,
		source = "zh-CN",
		target = "en"
	})
	if processorResult and processorResult.html and processorResult.html ~= "" then
		return pageOfElem(Document(processorResult.html), true)
	end

	local document = getDocument(expandedURL, browserHeaders(referer), false)
	local chapter = document:selectFirst(".txtnav")
	if not chapter then
		chapter = firstElement(document, { "#content", ".content", ".chaptercontent", ".read-content", ".container" })
	end
	if not chapter then
		return pageOfElem(Document("<p>Unable to locate chapter content.</p>"), true)
	end

	local title = textOf(firstElement(chapter, { "h1" }))
	if title == "" then
		title = textOf(firstElement(document, { "h1" }))
	end

	removeUselessContent(chapter)
	local paragraphs = collectParagraphs(chapter)

	if #paragraphs > 0 and title ~= "" and paragraphs[1] == title then
		table.remove(paragraphs, 1)
	end

	local translated = translateParagraphs(paragraphs)
	if translatePlainTexts and title ~= "" then
		title = translatePlainTexts({ title })[1] or title
	end
	local html = title ~= "" and ("<h1>" .. escapeHTML(title) .. "</h1>") or ""
	html = html .. paragraphsToHTML(translated)

	return pageOfElem(Document(html), true)
end

return {
	id = 690069,
	name = "69 Shuba (Translated)",
	baseURL = baseURL,
	imageURL = imageURL,
	hasCloudFlare = true,
	hasSearch = true,
	isSearchIncrementing = false,
	chapterType = ChapterType.HTML,
	startIndex = 1,

	listings = {
		Listing("Popular", true, filteredList),
		Listing("Latest Updates", true, listFromPath("/last.html")),
		Listing("All Novels", true, listFromPath("/all.html")),
		Listing("Completed", true, listFromPath("/novels/full")),
		Listing("Male", true, listFromPath("/novels/male")),
		Listing("Female", true, listFromPath("/novels/female"))
	},

	searchFilters = {
		DropdownFilter(ORDER_FILTER_ID, "Sort", ORDER_NAMES),
		DropdownFilter(STATUS_FILTER_ID, "Status", STATUS_NAMES),
		DropdownFilter(GENRE_FILTER_ID, "Genre", GENRE_NAMES)
	},

	shrinkURL = shrinkURL,
	expandURL = expandURL,
	search = search,
	parseNovel = parseNovel,
	getPassage = getPassage
}
