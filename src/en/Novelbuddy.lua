-- {"id":95566,"ver":"2.0.1","libVer":"1.0.0","author":"Confident-hate","dep":["dkjson>=1.0.0, unhtml>=1.0.0"]}

local baseURL = "https://novelbuddy.com"
local apiURL = "https://api.novelbuddy.com"
local json = Require("dkjson")
local unhtml = Require("unhtml")

---@param v Element
local text = function(v)
    return v:text():gsub(" ,", "")
end

---@param url string
---@param type int
local function shrinkURL(url)
    return url:gsub("https://novelbuddy.com", "")
end

---@param url string
---@param type int
local function expandURL(url)
    return baseURL .. url
end

local GENRE_FILTER = 2
local GENRE_VALUES = { 
    "All",
    "Action",
    "Action Adventure",
    "Adult",
    "Adventure",
    "Bender",
    "Chinese",
    "Comedy",
    "Cultivation",
    "Drama",
    "Eastern",
    "Ecchi",
    "Fan-Fiction",
    "Fanfiction",
    "Fantasy",
    "Game",
    "Gender",
    "Gender Bender",
    "Harem",
    "Historica",
    "Historical",
    "History",
    "Horror",
    "Isekai",
    "Josei",
    "Lolicon",
    "Magic",
    "Martial",
    "Martial Arts",
    "Mature",
    "Mecha",
    "Military",
    "Modern Life",
    "Mystery",
    "Psychologic",
    "Psychological",
    "Reincarnation",
    "Romance",
    "School Life",
    "Sci-fi",
    "Seinen",
    "Shoujo",
    "Shoujo Ai",
    "Shounen",
    "Shounen Ai",
    "Slice Of Life",
    "Smut",
    "Sports",
    "Supernatural",
    "System",
    "Tragedy",
    "Urban",
    "Urban Life",
    "Wuxia",
    "Xianxia",
    "Xuanhuan",
    "Yaoi",
    "Yuri"
}

local GENRE_PARAMS = {
    "",
    "/genres/action",
    "/genres/action-adventure",
    "/genres/adult",
    "/genres/adventure",
    "/genres/bender",
    "/genres/chinese",
    "/genres/comedy",
    "/genres/cultivation",
    "/genres/drama",
    "/genres/eastern",
    "/genres/ecchi",
    "/genres/fan-fiction",
    "/genres/fanfiction",
    "/genres/fantasy",
    "/genres/game",
    "/genres/gender",
    "/genres/gender-bender",
    "/genres/harem",
    "/genres/historica",
    "/genres/historical",
    "/genres/history",
    "/genres/horror",
    "/genres/isekai",
    "/genres/josei",
    "/genres/lolicon",
    "/genres/magic",
    "/genres/martial",
    "/genres/martial-arts",
    "/genres/mature",
    "/genres/mecha",
    "/genres/military",
    "/genres/modern-life",
    "/genres/mystery",
    "/genres/psychologic",
    "/genres/psychological",
    "/genres/reincarnation",
    "/genres/romance",
    "/genres/school-life",
    "/genres/sci-fi",
    "/genres/seinen",
    "/genres/shoujo",
    "/genres/shoujo-ai",
    "/genres/shounen",
    "/genres/shounen-ai",
    "/genres/slice-of-life",
    "/genres/smut",
    "/genres/sports",
    "/genres/supernatural",
    "/genres/system",
    "/genres/tragedy",
    "/genres/urban",
    "/genres/urban-life",
    "/genres/wuxia",
    "/genres/xianxia",
    "/genres/xuanhuan",
    "/genres/yaoi",
    "/genres/yuri"
}

local SORT_BY_FILTER = 3
local SORT_BY_VALUES = {"Views", "Top Day", "Top Week", "Top Month", "Updated", "Created"}
local SORT_BY_PARAMS = {"?sort=views", "?sort=top-day", "?sort=top-week", "?sort=top-month", "?sort=updated_date", "?sort=created_date"}

local STATUS_FILTER = 4
local STATUS_VALUES = {"All", "Ongoing", "Completed"}
local STATUS_PARAMS = {"&status=all", "&status=ongoing", "&status=completed"}

local searchFilters = {
    DropdownFilter(GENRE_FILTER, "Genre", GENRE_VALUES),
    DropdownFilter(SORT_BY_FILTER, "Sort By", SORT_BY_VALUES),
    DropdownFilter(STATUS_FILTER, "Status", STATUS_VALUES)
}



local headers = HeadersBuilder():add("Accept", "text/css"):build()

--- takes a url, returns table formatted json
--- @param url string
--- @return string
local function jsonGET(url)
    local res = Request(GET(url, headers))
    return json.decode(res:body():string())
end

--- @param chapterURL string @url of the chapter
--- @return string @of chapter
local function getPassage(chapterURL)
    local htmlElement = GETDocument(chapterURL)
    local reader = htmlElement:selectFirst(".novel-reader-content")
    local title = reader:selectFirst("h2"):text() .. reader:selectFirst("p"):text()
    local chapter = reader:selectFirst(".novel-tts-content") -- actual chapter content
    chapter:prepend("<h1>" .. title .. "</h1>")

    -- stolen Code from novelvault, see comment line 550
    local toRemove = {}
    chapter:traverse(NodeVisitor(function(v)
        local tag = v:tagName()
        if tag == "br" then
            local previous = v:previousElementSibling()
            local next = v:nextElementSibling()

            if previous and next and previous:tagName() == "p" and next:tagName() == "p" then
                table.insert(toRemove, v)
            end
        
        elseif tag == "div" and v:hasClass("my-4") then
            table.insert(toRemove, v)
        end
    end, function() end, true)) -- Enable elements only to avoid crashes

    for _, node in ipairs(toRemove) do
        node:remove()
    end

    return pageOfElem(chapter, true)
end

--- @param data table
local function search(data)
    local queryContent = data[QUERY]
    local page = "&page=" .. data[PAGE]
    local searchData = jsonGET(apiURL .. "/titles/search?q=" .. queryContent .. page).data
    return map(searchData.items, function(v)
        return Novel {
            title = v.name,
            imageURL = v.cover,
            link = v.url
        }
    end)
end

--- @param novelURL string @URL of novel
--- @return NovelInfo
local function parseNovel(novelURL)
    local url = baseURL .. novelURL
    local document = GETDocument(url)
    local jsonData = json.decode(document:getElementById("__NEXT_DATA__"):html())
    local novelData = jsonData.props.pageProps.initialManga
    local novelID = novelData.id
    local chapterURL = apiURL .. "/titles/" .. novelID .. "/chapters"
    local chapterList = jsonGET(chapterURL).data.chapters
    local chapterOrder = #chapterList
    return NovelInfo {
        title = novelData.name,
        -- alternativeTitles = novelData.altName or "", -- Seems to be broken
        -- description = unhtml:HTMLToString("<div>"..novelData.summary.."</div>"),
        description = novelData.summary,
        imageURL = novelData.cover,
        status = ({
            Ongoing = NovelStatus.PUBLISHING,
            OnGoing = NovelStatus.PUBLISHING,
            Completed = NovelStatus.COMPLETED,
        })[novelData.status] or NovelStatus.UNKNOWN,
        authors = map(novelData.authors, function (v) return v.name end),
        genres = map(novelData.genres, function (v) return v.name end),
        tags = map(novelData.tags, function (v) return v.name end),
        chapters = AsList(
            map(chapterList, function(v)
                chapterOrder = chapterOrder - 1
                return NovelChapter {
                    order = chapterOrder,
                    title = v.name,
                    link = baseURL .. v.url,
                    release = v.updated_at:sub(1,10), -- substr match YYYY-MM-DD out of ISO datetime
                    --- sourceId = v.id -- Novel.kt's Chapter class at kotlin-lib only takes Int id
                }
            end)
        )
    }
end


-- Weirdly not served in json like everything else. At least I couldn't find
-- it by looking at the network tab in browser's inspect window.
-- You'd think if search is json, this would be too.
local function parseListing(listingURL)
    local document = GETDocument(listingURL)
    return map(document:select(".object-cover"), function(v)
        return Novel {
            title = v:attr("title"),
            imageURL = v:attr("src"),
            link = v:parent():attr("href")
        }
    end)
end

local function getListing(name, inc, listingString)
    return Listing(name, inc, function(data)
        local page = "&page=" .. data[PAGE]
        local genre = data[GENRE_FILTER]
        local genreValue = ""
        local sortby = data[SORT_BY_FILTER]
        local sortByValue = ""
        local status = data[STATUS_FILTER]
        local statusValue = ""
        if status ~= nil then
            statusValue = STATUS_PARAMS[status+1]
        end
        if genre ~= nil then
            genreValue = GENRE_PARAMS[genre+1]
        end
        if sortby ~= nil then
            sortByValue = SORT_BY_PARAMS[sortby+1]
        end
        local url = baseURL .. genreValue .. sortByValue .. statusValue .. page
        if genreValue == "" then
            url = baseURL .. listingString .. sortByValue .. statusValue .. page
        end
        return parseListing(url)
    end)
end

return {
    id = 95566,
    name = "NovelBuddy",
    baseURL = baseURL,
    imageURL = "https://novelbuddy.com/static/sites/novelbuddy/icons/apple-touch-icon.png",
    hasSearch = true,
    listings = {
        getListing("Popular", true, "/popular"),
        getListing("Newest", true, "/newest"),
        getListing("Latest", true, "/latest")
    },
    parseNovel = parseNovel,
    getPassage = getPassage,
    chapterType = ChapterType.HTML,
    search = search,
    shrinkURL = shrinkURL,
    expandURL = expandURL,
    searchFilters = searchFilters
}

