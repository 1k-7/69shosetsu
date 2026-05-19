-- {"id":808001,"ver":"1.0.0","libVer":"1.0.0","author":"wsu808","repo":"","dep":["unhtml", "FilterOptions", "url"]}

local FilterOptions = Require("FilterOptions")
local HTMLToString = Require("unhtml").HTMLToString
local encode = Require("url").encode

local EMPTY_SPACE = string.rep(" ", 100)

local baseURL = "https://www.fimfiction.net"

--- Maps Fimfiction statuses to Shosetsu statuses
local statusMap = {
  complete = NovelStatus.COMPLETED,
  incomplete = NovelStatus.PUBLISHING,
  hitaus = NovelStatus.PAUSED,
  cancelled = NovelStatus.PAUSED
}

-- Filter IDs
local FID_ORDER = 2
local FID_TAGS = 3
local FID_RATING = 4
local FID_VIEWS = 5
local FID_WORDS = 6
local FID_STATUS = 7

local orderFilter = FilterOptions {
  "latest",
  "relevance",
  "heat",
  "updated",
  { top = "rating" },
  "views",
  "words",
  "comments",
  "likes",
  "dislikes",
  "random"
}

local statusFilter = FilterOptions({
  nil,
  "complete",
  "incomplete",
  "hitaus",
  "cancelled",
}, "All")

--- simplified querystring without enforced url encoding
local function querystring(tbl, url)
  local fields = {}

  for key, value in pairs(tbl) do
    if value ~= nil then
      table.insert(fields, key .. "=" .. tostring(value))
    end
  end

  return (url and url .. "?" or "") .. table.concat(fields, "&")
end

local function shrinkURL(url, type)
  return url:gsub(".-fimfiction%.net/?", "")
end

local function expandURL(url, type)
  return baseURL .. "/" .. url:gsub("^/*", "")
end

local function getListing(data)
  local query = data[QUERY]
  local page = data[PAGE]
  local tags = data[FID_TAGS] or ""

  local filters = {
    status = data[FID_STATUS] and statusFilter:valueOf(data[FID_STATUS]),
    words = data[FID_WORDS],
    views = data[FID_VIEWS],
    wilson = data[FID_RATING]
  }

  local parts = {}
  for k, v in pairs(filters) do
    if v and v ~= "" then
      table.insert(parts, k .. "%3A" .. v)
    end
  end
  for tag in tags:gmatch("%S+") do
    table.insert(parts, encode(tag))
  end

  local advancedQuery = encode(query) .. "+" .. table.concat(parts, "+")

  local params = {
    view_mode = 0,
    order = data[FID_ORDER] and orderFilter:valueOf(data[FID_ORDER]),
    q = advancedQuery,
    page = (page ~= 1) and page or nil
  }

  local url = expandURL(querystring(params, "/stories"))
  local doc = GETDocument(url)

  return map(doc:select(".story_content_box"), function(n)
    local a = n:selectFirst(".story_name")
    local img = n:selectFirst(".story_container__story_image img")

    return Novel {
      title = a:text(),
      link = a:attr("href"),
      imageURL = img and img:attr("data-src")
    }
  end)
end

local function parseNovel(url, loadChapters)
  local doc = GETDocument(expandURL(url))

  local statusClass = doc:selectFirst("[class^='completed-status-']"):attr("class")
  local status = statusClass:match(".*%-(.+)")
  local img = doc:selectFirst("meta[property='og:image']")

  local info = NovelInfo {
    title = doc:selectFirst("meta[property='og:title']"):attr("content"),
    description = doc:selectFirst("meta[property='og:description']"):attr("content")
      .. "\n\n"
      .. HTMLToString(doc:selectFirst(".description-text")),
    imageURL = img and img:attr("content"),
    status = statusMap[status],
    authors = { doc:selectFirst("meta[property='book:author']"):attr("content"):match(".*%/(.+)") },
    genres = map(doc:select(".story_container .story-tags li"), function(t) return t:text() end)
  }

  if loadChapters then
    local chapters = map(doc:select(".chapters li .title-box"), function (ch)
      return NovelChapter {
        title = ch:selectFirst(".chapter-title"):text(),
        link = ch:selectFirst(".chapter-title"):attr("href"),
        release = ch:selectFirst(".date"):ownText()
      }
    end)

    info:setChapters(chapters)
  end

  return info
end

local function getPassage(url)
  local doc = GETDocument(expandURL(url))
  -- remove chapter list dropdown
  doc:selectFirst("h1.chapter-title > div"):remove()
  return pageOfElem(doc:selectFirst("#chapter"))
end

return {
  id = 808001,
  name = "Fimfiction",
  baseURL = baseURL,
  imageURL = "https://static.fimfiction.net/images/favicon.png?9",
  chapterType = ChapterType.HTML,
  hasCloudFlare = true,

  shrinkURL = shrinkURL,
  expandURL = expandURL,

  listings = {
    Listing("Default", true, getListing)
  },

  searchFilters = {
    DropdownFilter(FID_ORDER, "Order by", orderFilter:labels()),
    DropdownFilter(FID_STATUS, "Status", statusFilter:labels()),
    FilterList("Tags", {
      TextFilter(FID_TAGS, "Tags"),
      FilterList([[
Include tags by prefixing them with #
Exclude tags by prefixing with -#
      ]] .. EMPTY_SPACE, {}),
      FilterList("✳️ #slice-of-life -#sex" .. EMPTY_SPACE, {}),
    }),
    FilterList("Rating", {
      TextFilter(FID_RATING, "Rating"),
      FilterList("✳️ >80" .. EMPTY_SPACE, {})
    }),
    FilterList("View count", {
      TextFilter(FID_VIEWS, "Custom view count"),
      FilterList("✳️ >10000" .. EMPTY_SPACE, {}),
      FilterList("✳️ <10000" .. EMPTY_SPACE, {}),
      FilterList("✳️ 5000-9000" .. EMPTY_SPACE, {})
    }),
    FilterList("Word count", {
      TextFilter(FID_WORDS, "Custom word count"),
      FilterList("✳️ >10000" .. EMPTY_SPACE, {}),
      FilterList("✳️ <10000" .. EMPTY_SPACE, {}),
      FilterList("✳️ 5000-9000" .. EMPTY_SPACE, {})
    }),
  },

  parseNovel = parseNovel,
  getPassage = getPassage,

  hasSearch = true,
  isSearchIncrementing = true,
  startIndex = 1,
  search = getListing,
}