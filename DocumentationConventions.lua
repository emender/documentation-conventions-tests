-- DocumentationConventions.lua

-- The Documentation Conventions test verifies that a guide does not contain
-- any spell checking errors, violations against word usage guidelines, or
-- words that seem to be out of context.

-- Copyright (C) 2014-2017 Pavel Tisnovsky

-- This program is free software:  you can redistribute it and/or modify it
-- under the terms of  the  GNU General Public License  as published by the
-- Free Software Foundation, version 3 of the License.
--
-- This program  is  distributed  in the hope  that it will be useful,  but
-- WITHOUT  ANY WARRANTY;  without  even the implied warranty of MERCHANTA-
-- BILITY or  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
-- License for more details.
--
-- You should have received a copy of the GNU General Public License  along
-- with this program. If not, see <http://www.gnu.org/licenses/>.

DocumentationConventions = {
    metadata = {
        description = "The Documentation Conventions test verifies that a guide does not contain any spell checking errors, violations against word usage guidelines, or words that seem to be out of context.",
        authors = "Pavel Tisnovsky",
        emails = "ptisnovs@redhat.com",
        changed = "2017-04-27",
        tags = {"DocBook", "Release"}
    },
    aspellFileName = "aspell.txt",
    atomicTyposFileName = "atomic_typos.txt",
    tagsWithReadableText = {"para"},
    admonitions = {"note", "warning", "important"},
    whitelistServiceUrl = "glossary.service.org:3000/whitelist/",
    blacklistServiceUrl = "glossary.service.org:3000/blacklist/",
    glossaryServiceUrl = "glossary.service.org:3000/glossary/",
}



--
--- Function which runs first. This is place where all objects are created.
--
function DocumentationConventions.setUp()
    dofile(getScriptDirectory() .. "lib/xml.lua")
    dofile(getScriptDirectory() .. "lib/publican.lua")
    dofile(getScriptDirectory() .. "lib/docbook.lua")
    dofile(getScriptDirectory() .. "lib/sql.lua")

    -- Create publican object.
    DocumentationConventions.pubObj = publican.create("publican.cfg")

    -- Create xml object.
    DocumentationConventions.xmlObj = xml.create(DocumentationConventions.pubObj:findMainFile())

    -- Create docbook object.
    DocumentationConventions.docObj = docbook.create(DocumentationConventions.pubObj:findMainFile())

    -- Get readable text.
    DocumentationConventions.readableText = DocumentationConventions.docObj:getReadableText()

    -- Get language code from this book.
    local language = DocumentationConventions.pubObj:getOption("xml_lang")

    -- Default language is en-US:
    if not language then
      language = "en-US"
    end

    DocumentationConventions.atomicTypos = loadAtomicTypos(getTestDirectory() .. DocumentationConventions.atomicTyposFileName)
    DocumentationConventions.aspellDictionary = loadAspellDictionary(getTestDirectory() .. DocumentationConventions.aspellFileName)
    DocumentationConventions.glossary = fetchGlossary(DocumentationConventions.glossaryServiceUrl)
    DocumentationConventions.glossaryCorrectWords = correctWordsFromGlossary(DocumentationConventions.glossary)
    DocumentationConventions.glossaryIncorrectWords = incorrectWordsFromGlossary(DocumentationConventions.glossary)
    DocumentationConventions.glossaryWithCautionWords = withCautionWordsFromGlossary(DocumentationConventions.glossary)
    DocumentationConventions.correctWords = fetchCorrectWords(DocumentationConventions.whitelistServiceUrl)
    DocumentationConventions.incorrectWords = fetchIncorrectWords(DocumentationConventions.blacklistServiceUrl)
end



--
-- Filter termns from the Glossary that have the use-it value set to specified constant
-- (use it, don't use, use with caution)
--
function filterGlossary(glossary, useValue)
    local terms = {}
    for _,term in ipairs(glossary) do
        if term.use == useValue then
            terms[term.word] = term
        end
    end
    return terms
end



--
-- Returns a table with all correct words read from the Glossary
--
function correctWordsFromGlossary(glossary)
    return filterGlossary(glossary, 1)
end



--
-- Returns a table with all incorrect words read from the Glossary
--
function incorrectWordsFromGlossary(glossary)
    return filterGlossary(glossary, 0)
end



--
-- Returns a table with all words read from the Glossary that should be used with caution
--
function withCautionWordsFromGlossary(glossary)
    return filterGlossary(glossary, 2)
end



--
-- Read input file and return its content as a (possibly long) string.
--
function readInputFile(inputFileName)

    -- info for user
    yap("Reading input file: " .. inputFileName)

    -- open the file
    local fin = io.open(inputFileName, "r")

    if not fin then
       fail("Unable to open file: " .. inputFileName)
       return nil
    end

    -- read whole contents of the open file
    local str = fin:read("*all")

    -- current position in file = file size at this point
    local current = fin:seek()
    fin:close()

    -- print basic info for user
    yap("Done. " .. current .. " bytes read.")
    return str
end



--
-- Read input file and convert data from JSON format to a regular Lua object.
--
function readInputFileInJsonFormat(inputFileName)
    -- read whole file into the string
    local str = readInputFile(inputFileName)

    if not str then
        return nil
    end

    -- and try to parse content of this string as JSON format
    -- (returned as table of tables...)
    return json.decode(str, 1, nil)
end



--
-- Downloads data (glossary, whitelist, blacklist) from the selected service.
function downloadDataFromService(url, filename)
    yap("Reading data from URL: " .. url)
    local command = "wget -O " .. filename .. " " .. url
    os.execute(command)
    yap("Downloaded data stored into file: " .. filename)
end



--
-- Fetch correct words from database.
--
function fetchGlossary(serviceUrl)
    local filename = "glossary.json"
    local url = serviceUrl .. "json"
    downloadDataFromService(url, filename)
    local words = readInputFileInJsonFormat(filename)
    if not words or #words == 0 then
        fail("Read zero words, possible error communicating with the service")
    else
        pass("Read " .. #words .. " words")
    end
    return words
end



--
-- Check if any word has been loaded.
--
function checkWordCount(cnt)
    if cnt == 0 then
        fail("Read zero words, possible error communication with the service")
    else
        pass("Read " .. cnt .. " words")
    end
end



--
-- Fetch correct words from database.
--
function fetchCorrectWords(serviceUrl)
    local filename = "whitelist.txt"
    local url = serviceUrl.. "text"
    downloadDataFromService(url, filename)
    local words = {}
    local cnt = 0
    local fin = io.open(filename, "r")
    if not fin then
        fail("Can not open file " .. filename .. " for reading")
        return {}
    end
    for line in fin:lines() do
        -- use lowercase words!
        local word = string.lower(string.trim(line))
        words[word]=true
        cnt = cnt + 1
    end
    fin:close()
    checkWordCount(cnt)
    return words
end



--
-- Fetch incorrect words from database.
--
function fetchIncorrectWords(serviceUrl)
    local filename = "blacklist.txt"
    local url = serviceUrl .. "text"
    downloadDataFromService(url, filename)
    local words = {}
    local cnt = 0
    local fin = io.open(filename, "r")
    if not fin then
        fail("Can not open file " .. filename .. " for reading")
        return {}
    end
    for line in fin:lines() do
        local i = string.find(line, "\t")
        if i then
            local word = string.sub(line, 1, i-1)
            local description = string.sub(line, i+1)
            words[word]=description
            cnt = cnt + 1
        end
    end
    fin:close()
    checkWordCount(cnt)
    return words
end



--
-- Helper function that loads aspell dictionary.
--
function loadAspellDictionary(filename)
    local words = {}
    local cnt = 0
    yap("Reading aspell dictionary from " .. filename)
    local fin = io.open(filename, "r")
    if not fin then
        fail("Can not open file " .. filename .. " for reading")
        return {}
    end
    for line in fin:lines() do
        if line ~= "" then
            words[string.lower(line)] = true
            cnt = cnt + 1
        end
    end
    fin:close()
    checkWordCount(cnt)
    return words
end



--
-- Helper function that loads atomic typos.
--
function loadAtomicTypos(filename)
    local words = {}
    local cnt = 0
    yap("Reading atomic typos from " .. filename)
    local fin = io.open(filename, "r")
    if not fin then
        fail("Can not open file " .. filename .. " for reading")
        return {}
    end
    for line in fin:lines() do
        local i = string.find(line, "->")
        if i then
            local key = string.sub(line, 1, i-1)
            local val = string.sub(line, i+2)
            words[key]=val
            cnt = cnt + 1
        end
    end
    fin:close()
    checkWordCount(cnt)
    return words
end



--
-- Helper function that returns test directory
--
function getTestDirectory()
    local path = debug.getinfo(1).source
    if not path then
        return nil
    end
    if path:startsWith("@") then
        return string.sub(path, 2, string.lastIndexOf(path, "/"))
    else
        return string.sub(path, 1, string.lastIndexOf(path, "/"))
    end
end



function spellNumber(number)
    if number == 0 then
        return "**never**."
    elseif number == 1 then
        return "**once**."
    elseif number == 2 then
        return "**twice**."
    else
        return "**" .. number .. "** times."
    end
end



--
-- Print overall test results
--
function printResults(incorrectWords, withCautionWords)
    -- Print the result of test.
    local total = 0
    for word, count in pairs(incorrectWords) do
        -- use singular or plural
        local number = spellNumber(count)
        total = total + count
        fail("The word **" .. word .. "** occurred " .. number)
    end
    if total == 1 then
        warn("Found **one** incorrect word!")
    elseif total > 1 then
        warn("Found **" .. total .. "** incorrect words!")
    end
end



--
-- Print incorrect words
--
function printIncorrectWords(incorrectWords, withCautionWords)
    -- Print the result of test.
    local total = 0
    for word, count in pairs(incorrectWords) do
        fail("The spell checker marked the word **" .. word .. "** as incorrect. **Recommended action**: if this word is correct, add it to the CCS Custom Dictionary or update the Glossary of Terms and Conventions for Product Documentation.")
    end
end



--
-- Check if the word should be tested or not
--
function isWordForTesting(word)
    -- special case - don't try to check words containing / character
    if string.find(word, "/") then
        return false
    end
    -- another special case - ignore uppercase words
    if string.upper(word) == word then
        return false
    end
    return true
end



function registerIncorrectWord(incorrectWords, word)
    if not incorrectWords[word] then
        incorrectWords[word] = 1
    else
        incorrectWords[word] = incorrectWords[word] + 1
    end
end



function DocumentationConventions:isWhitelistedWord(word)
    return self.correctWords and self.correctWords[string.lower(word)]
end



function DocumentationConventions:isWordInAspell(word)
    return self.aspellDictionary[string.lower(word)] 
end



function DocumentationConventions:isGlossaryCorrectWord(word)
    return self.glossaryCorrectWords and self.glossaryCorrectWords[word]
end



---
--- Tests that a guide does not contain any violations against our word usage guidelines.
---
function DocumentationConventions.testDocumentationGuidelines()
    local readableText = DocumentationConventions.readableText
    if readableText and #readableText > 0 then
        local readableParts = table.concat(DocumentationConventions.readableText, " ")
        local incorrectWords = {}
        local withCautionWords = {}
        -- Go through readable parts word by word.
        --for word in readableParts:gmatch("[%w%p-]+") do
        for word in readableParts:gmatch("[%w%-?]+") do
            if isWordForTesting(word) then
                word = string.trimString(word)
      
                -- let's not be case sensitive
                if not DocumentationConventions:isWordInAspell(word) then
                    -- The word can not be found in aspell, se let's check if it is in the internal whitelist or Glossary
                    -- First our writing style database and the whitelist.
                    if not DocumentationConventions:isWhitelistedWord(word) and
                       not DocumentationConventions:isGlossaryCorrectWord(word) then
                        registerIncorrectWord(incorrectWords, word)
                    end
      
                    -- Create helpWord variable which is without "'s" at the end of the string.
                    -- So, we can check for example "API's".
                    local helpWord = word
                    if word:match("'s$") then
                        helpWord = word:gsub("'s$", "")
                    end
                    -- words are filtered using aspell, now filter words which are allowed
                end
            end
        end
        printIncorrectWords(incorrectWords, withCautionWords)
    else
       fail("No readable text found")
    end
end

