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
    differentSpellingWordsServiceUrl = "glossary.service.org:3000/different-spelling-words/",
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
    DocumentationConventions.differentSpellingWords = fetchDifferentSpellingWords(DocumentationConventions.differentSpellingWordsServiceUrl)
    DocumentationConventions.correctWords = fetchCorrectWords(DocumentationConventions.whitelistServiceUrl)
    DocumentationConventions.incorrectWords = fetchIncorrectWords(DocumentationConventions.blacklistServiceUrl)
    DocumentationConventions.format = loadFormatInfo()
    DocumentationConventions.workDirectory = loadWorkDirectory()
    DocumentationConventions.masterDirectory = loadMasterDirectory()
    DocumentationConventions.includeFiles = loadListOfIncludeFiles()
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
-- Fetch different spelling words from the service.
--
function fetchDifferentSpellingWords(serviceUrl)
    local filename = "different_spelling_words.json"
    local url = serviceUrl .. "json"
    downloadDataFromService(url, filename)
    local terms = readInputFileInJsonFormat(filename)
    pass("Read " .. #terms .. " terms")
    local words = {}
    for _,term in ipairs(terms) do
        words[term.word] = true
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
-- Loads list of included files from the file results.includes
--
function loadListOfIncludeFiles()
    local list = {}
    local fin = io.open("results.includes", "r")

    if fin then
        local prefix = "Found an include:"
        for line in fin:lines() do
            if line:startsWith(prefix) then
                filename = line:sub(1+prefix:len()):trim()
                pass("Included file: " .. filename)
                table.insert(list, filename)
            end
        end

        fin:close()
        return list
    else
        warn("Can not read list of included files from the file results.include")
        return {}
    end
end



function correctInput(input)
    return input and #input >= 1
end


--
-- Load information about the format of book
--
function loadFormatInfo()
    local input = slurpTable("results.format")
    if correctInput(input) then
        pass("Input format: " .. input[1])
        return input[1]
    else
        fail("Can not read input format from the file results.format")
        return nil
    end
end



--
-- Load information about the work directory
--
function loadWorkDirectory()
    local input = slurpTable("results.cwd")
    if correctInput(input) then
        pass("Work directory: " .. input[1])
        return input[1]
    else
        fail("Can not read source directory from file results.cwd")
        return nil
    end
end



--
-- Load information about the directory with the master file
--
function loadMasterDirectory()
    local input = slurpTable("results.master")
    if correctInput(input) then
        pass("Master directory: " .. input[1])
        return input[1]
    else
        fail("Can not read master directory from file results.master")
        return nil
    end
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



function performGrep(word, path, filename, workDir)
    local regexp1 = "\\W" .. word .. "\\W"
    local regexp2 = "^" .. word .. "\\W"
    local regexp3 = "\\W" .. word .. "$"
    local regexp4 = "^" .. word .. "$"
    local ror = "\\|"
    local path = "`realpath --relative-to='" .. workDir .. "' " .. path .. "/" .. filename .. "`"
    --print(path)

    local cmd = "grep -n -H '" .. regexp1 .. ror .. regexp2 .. ror .. regexp3 .. ror .. regexp4 .. "' " .. path

    return execCaptureOutputAsTable(cmd)
end



function DocumentationConventions:getFilelistForWord(word)
    local path = self.masterDirectory
    local all_matches = {}

    local matches = performGrep(word, path, "master.adoc", self.workDirectory)

    all_matches = table.appendTables(all_matches, matches)

    for _, includedFile in ipairs(self.includeFiles) do
        local matches = performGrep(word, path, includedFile, self.workDirectory)
        all_matches = table.appendTables(all_matches, matches)
    end

    return all_matches
end



--
-- Print incorrect words
--
function printIncorrectWords(incorrectWords)
    for word, count in pairs(incorrectWords) do
        fail("The spell checker marked the word **" .. word .. "** as incorrect. **Recommended Action**: if this word is correct, add it to the CCS Custom Dictionary or update the Glossary of Terms and Conventions for Product Documentation.")
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



function registerWord(wordlist, word)
    if not wordlist[word] then
        wordlist[word] = 1
    else
        wordlist[word] = wordlist[word] + 1
    end
end



function wordInTable(tbl, word)
    return tbl and tbl[word]
end

function readWordFromTable(tbl, word)
    if tbl then
        return tbl[word]
    else
        return nil
    end
end

function DocumentationConventions:isWhitelistedWord(word)
    return wordInTable(self.correctWords, string.lower(word))
end



function DocumentationConventions:isBlacklistedWord(word)
    return wordInTable(self.incorrectWords, string.lower(word))
end



function DocumentationConventions:isWordInAspell(word)
    return wordInTable(self.aspellDictionary, string.lower(word))
end



function DocumentationConventions:isGlossaryCorrectWord(word)
    return wordInTable(self.glossaryCorrectWords, word)
end



function DocumentationConventions:getGlossaryIncorrectWord(word)
    return readWordFromTable(self.glossaryIncorrectWords, word)
end



function DocumentationConventions:getGlossaryWithCautionWord(word)
    return readWordFromTable(self.glossaryWithCautionWords, word)
end



--
-- Check one word for any problems
--
function DocumentationConventions:checkWord(incorrectWords, word)
    word = string.trimString(word)

    -- let's not be case sensitive
    if not self:isWordInAspell(word) then
        -- The word can not be found in aspell, se let's check if it is in the internal whitelist or Glossary
        -- First our writing style database and the whitelist.
        if not self:isWhitelistedWord(word) and
           not self:isGlossaryCorrectWord(word) then
            registerWord(incorrectWords, word)
        end

        -- Create helpWord variable which is without "'s" at the end of the string.
        -- So, we can check for example "API's".
        local helpWord = word
        if word:match("'s$") then
            helpWord = word:gsub("'s$", "")
        end
    end
    local blacklistedWord = self:isBlacklistedWord(word)
    local glossaryIncorrectWord = self:getGlossaryIncorrectWord(word)
    local glossaryWithCautionWords = self:getGlossaryWithCautionWord(word)
    if glossaryIncorrectWord then
        local message = "The word **" .. word .. "** does not comply with our guidelines. **Explanation**: " .. glossaryIncorrectWord.description
        if glossaryIncorrectWord.correct_forms ~= "" then
            message = message .. " **Recommended Action**: use " .. glossaryIncorrectWord.correct_forms
        end
        --fail(message)
    elseif blacklistedWord then
        --fail("The word **" .. word .. "** does not comply with our guidelines. Please look into CCS Blacklist database.")
    end
    if glossaryWithCautionWords then
        local message = "Use the word **" .. word .. "** with caution. **Explanation**: " .. glossaryWithCautionWords.description .. " **Recommended Action**: Verify if the word is used correctly by reading the whole sentence and correct the sentence as necessary. If the word is used correctly, mark it as reviewed in the waiving system."
        warn(message)
    end
end



function getWordList(readableParts)
    local words = {}
    for word in readableParts:gmatch("[%w%p-]+") do
        table.insert(words, word)
    end
    return words
end



function DocumentationConventions:checkAllWords(readableParts)
    local incorrectWords = {}
    -- Go through readable parts word by word.
    for word in readableParts:gmatch("[%w%-?]+") do
        if isWordForTesting(word) then
            DocumentationConventions:checkWord(incorrectWords, word)
        end
    end
    return incorrectWords
end



--
-- Try to read word source from the glossary
--
function DocumentationConventions:getWordSource(word)
    for _, term in ipairs(self.glossary) do
        if term.word == word then
            return term.source_name
        end
    end
    return "unknown"
end



function DocumentationConventions:checkAtomicTyposAndWordsWithDifferentSpelling(readableParts)
    local words = getWordList(readableParts)
    for i = 1, #words do
        local wordp2, wordp1, word, wordn1, wordn2 = unpack(words, i-2)
        if self.differentSpellingWords[word] then
           local source = self:getWordSource(word)
           local context = (wordp2 or "") .. " " .. (wordp1 or "") .. " " .. word .. " " .. (wordn1 or "") .. " " .. (wordn2 or "")
           local expanation = "**Explanation**: The correct usage of this word depends on the word's part of speech. See the " .. source .. " for details. "
           local action = "**Recommended Action**: Verify if the word is used correctly by reading the whole sentence and correct the sentence as necessary. If the word is used correctly, mark it as reviewed in the waiving system."
           warn("The word **" .. word .. "** might have different spelling in '" .. context .. "' " .. expanation .. " " .. action)
        end
    end
end



---
--- Tests that a guide does not contain any violations against our word usage guidelines.
---
function DocumentationConventions.testDocumentationGuidelines()
    local readableText = DocumentationConventions.readableText
    if readableText and #readableText > 0 then
        local readableParts = table.concat(readableText, " ")
        local incorrectWords = DocumentationConventions:checkAllWords(readableParts)
        printIncorrectWords(incorrectWords)
    else
       fail("No readable text found")
    end
end



---
--- Test the spelling
---
function DocumentationConventions.testSpelling()
    local readableText = DocumentationConventions.readableText
    if readableText and #readableText > 0 then
        local readableParts = table.concat(readableText, " ")
        DocumentationConventions:checkAtomicTyposAndWordsWithDifferentSpelling(readableParts)
    else
       fail("No readable text found")
    end
end

