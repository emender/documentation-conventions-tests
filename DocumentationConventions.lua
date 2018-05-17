--[[
The Documentation Conventions test verifies that documentation does not contain
any spell checking errors, violations against word usage guidelines, or words
that seem to be out of context.

Copyright (C) 2014-2018 Pavel Tisnovsky, Lana Ovcharenko

This program is free software: you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation, version 3 of the License.

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program. If not, see <http://www.gnu.org/licenses/>.
]]

-- 2 tests are included:
-- DocumentationConventions.testDocumentationGuidelines()
-- DocumentationConventions.testWordUsage()

-- TODO: incorporate atomic typos into the 
-- DocumentationConventions.testWordUsage() function.

DocumentationConventions = {
    metadata = {
        description = "The Documentation Conventions test verifies that documentation does not contain any spell checking errors, violations against word usage guidelines, or words that seem to be out of context.",
        authors = "Pavel Tisnovsky, Lana Ovcharenko",
        emails = "ptisnovs@redhat.com, lovchare@redhat.com",
        changed = "2018-05-30",
        tags = {"DocBook", "Release"}
    },    
    -- These are command line arguments passed by a shell script.
    testDir = nil,
    docDir = nil,
    emenderDir = nil,
    
    -- These are files in the test directory.
    aspellFile = "aspell.txt",
    atomicTyposFile = "atomic_typos.txt",
    
    -- These are external services.
    blacklistUrl = "ccs-apps.gsslab.brq.redhat.com/zw/blacklist/text",
    whitelistUrl = "ccs-apps.gsslab.brq.redhat.com/zw/whitelist/text",
    glossaryUrl = "ccs-apps.gsslab.brq.redhat.com/zw/glossary/json",
    differentSpellingWordsUrl = "ccs-apps.gsslab.brq.redhat.com/zw/different-spelling-words/json",
    
    -- Other variables.
    atomicTypos = nil,
    aspell = nil,
    glossary = nil,
    glossaryCorrect = nil,
    glossaryIncorrect = nil,
    glossaryWithCaution = nil,
    differentSpellingWords = nil,
    whitelist = nil,
    blacklist = nil,
    --
    aspellLowercase = nil,
    glossaryCorrectLowercase = nil,
    glossaryIncorrectLowercase = nil,
    glossaryWithCautionLowercase = nil,
    whitelistLowercase = nil,
    blacklistLowercase = nil,
    --
    blacklisted = {},
    incorrect = {},
    withCaution = {},
    withCautionLowercase = {},
    --
    readableText = nil,
    isReady = true
}

-- Entry point for the test.
function DocumentationConventions.setUp()
    local emenderSrcDir = "/usr/local/share/emender/src"
    if DocumentationConventions.emenderDir then
        emenderSrcDir = DocumentationConventions.emenderDir .. "/src"
    end
    dofile(DocumentationConventions.testDir .. "/lib/publican.lua")
    dofile(DocumentationConventions.testDir .. "/lib/docbook.lua")
    dofile(DocumentationConventions.testDir .. "/lib/xml.lua")
    dofile(emenderSrcDir .. "/common/string.lua")
    local pubObj = publican.create("publican.cfg")
    local docObj = docbook.create(pubObj:findMainFile())
    DocumentationConventions.readableText = docObj:getReadableText()
    local includedFiles = DocumentationConventions:includeFiles(
        DocumentationConventions.docDir .. "/master.adoc", 
        DocumentationConventions.docDir)
    DocumentationConventions.includedFiles = shortenPath(includedFiles, DocumentationConventions.docDir)
    local includeCount = getTableLength(DocumentationConventions.includedFiles)
    if includeCount == 1 then
        pass("Included 1 file.")
    elseif includeCount > 0 then
        pass("Included " .. includeCount .. " files.")
    end
    DocumentationConventions:loadDictionaries()
end

function shortenPath(paths, basePath)
    local newPaths = {}
    basePath = basePath .. "/"
    for path, val in pairs(paths) do
        local newPath = stringRemove(path, basePath)
        newPath = stringRemove(newPath, "./")
        local idx = newPath:find("/../", 1, true)
        if idx then
            local substr = newPath:sub(1, idx - 1)
            if substr:find("/", 1, true) then
                lastIdx = substr:lastIndexOf("/")
                newPath = newPath:sub(1, lastIdx) .. newPath:sub(idx + ("/../"):len())
            else
                newPath = newPath:sub(idx + ("/../"):len())
            end
        end
        newPaths[path] = newPath
    end
    return newPaths
end

function stringRemove(str, substr)
    while str:find(substr, 1, true) do
        local idx = str:find(substr, 1, true)
        str = str:sub(1, idx - 1) .. str:sub(idx + substr:len())
    end
    return str
end

function DocumentationConventions:includeFiles(file, currentDir, result)
    result = result or {}
    result[file] = currentDir
    includes = getIncludes(file, currentDir)
    -- Base case.
    if getTableLength(includes) == 0 then
        return {}
    end
    -- Recursion.
    for include, newDir in pairs(includes) do
        result = appendTables(result, self:includeFiles(include, newDir, result))
    end
    return result
end

function getIncludes(file, currentDir)
    local includes = {}
    local input = io.open(file, "r")
    if not input then
        return {}
    end
    for line in input:lines() do
        if line:startsWith("include::") then
            local include = line:gsub("include::", "")
            local end_idx = include:lastIndexOf("%[")
            if end_idx then
                include = include:sub(1, end_idx - 1)
            end
            if include:match("{.+}") then
                include = include:gsub("{.+}", currentDir)
            else
                if include:startsWith("/") then
                    include = currentDir .. include
                else
                    include = currentDir .. "/" .. include
                end
            end
            local newDir = getCurrentDir(include)
            includes[include] = newDir
        end
    end
    input:close()
    return includes
end

function getCurrentDir(file)
    local lastSlashIdx = file:lastIndexOf("/")
    if not lastSlashIdx then
        return "."
    end
    return file:sub(1, lastSlashIdx - 1)
end

function DocumentationConventions:loadDictionaries()
    -- Store the words both in their original formatting and lowercase.
--    self.atomicTypos = self:getAtomicTypos()
    self.aspell, self.aspellLowercase = self:getAspell()
    self.glossary = self:getGlossary(self.glossaryUrl)
    self.glossaryCorrect, self.glossaryCorrectLowercase = filterGlossary(self.glossary, 1)
    self.glossaryIncorrect, self.glossaryIncorrectLowercase = filterGlossary(self.glossary, 0)
    self.glossaryWithCaution, self.glossaryWithCautionLowercase = filterGlossary(self.glossary, 2)
    self.differentSpellingWords = self:getDifferentSpellingWords(self.differentSpellingWordsUrl)
    self.whitelist, self.whitelistLowercase = self:getWhitelist(self.whitelistUrl)
    self.blacklist, self.blacklistLowercase = self:getBlacklist(self.blacklistUrl)
end

function DocumentationConventions:getAtomicTypos()
    local words = {}
    local count = 0
    local input = io.open(self.testDir .. "/" .. self.atomicTyposFile, "r")
    if not input then
        warn("Cannot open atomic typos file: " .. self.testDir .. "/" .. self.atomicTyposFile)
        return {}
    end
    for line in input:lines() do
      local i = line:find("->", 1, true)
      if i then
          local key = line:sub(1, i - 1):trim()
          local val = line:sub(i + 2):trim()
          words[key] = val
          count = count + 1
      end
    end
    input:close()
    checkWordCount("atomic typos", count)
    return words
end

function DocumentationConventions:getAspell()
    local words = {}
    local wordsLower = {}
    local count = 0
    local input = io.open(self.testDir .. "/" .. self.aspellFile, "r")
    if not input then
        warn("Cannot open Aspell file: " .. self.testDir .. "/" .. self.aspellFile)
        return {}
    end
    for line in input:lines() do
        if line ~= "" then
            words[line:trim()] = true
            wordsLower[line:lower():trim()] = true
            count = count + 1
        end
    end
    input:close()
    checkWordCount("Aspell words", count)
    return words, wordsLower
end

function DocumentationConventions:getGlossary(url)
    local file = self.testDir .. "/glossary.json"
    downloadData(url, file)
    local words = readInputFile(file)
    if not words then
        checkWordCount("glossary words", 0)
        return {}
    end
    checkWordCount("glossary words", #words)
    return words
end

function filterGlossary(glossary, useValue)
    local words = {}
    local wordsLower = {}
    for _, table in ipairs(glossary) do
        if table.use == useValue then
            local tableCopy = table
            tableCopy.source_name = tableCopy.source_name:trimString()
            tableCopy.correct_forms = tableCopy.correct_forms:trimString()
            words[table.word:trim()] = tableCopy
            wordsLower[table.word:lower():trim()] = tableCopy
        end
    end
    return words, wordsLower
end

function DocumentationConventions:getDifferentSpellingWords(url)
    local file = self.testDir .. "/different_spelling_words.json"
    downloadData(url, file)
    local terms = readInputFile(file)
    if not terms then
        checkWordCount("words with different spelling", 0)
        return {}
    end
    checkWordCount("words with different spelling", #terms)
    local words = {}
    for _, term in ipairs(terms) do
        words[term.word:trim()] = true
    end
    return words
end

function DocumentationConventions:getWhitelist(url)
    local file = self.testDir .. "/whitelist.txt"
    downloadData(url, file)
    local words = {}
    local wordsLower = {}
    local count = 0
    local input = io.open(file, "r")
    if not input then
        checkWordCount("whitelist words", 0)
        return {}
    end
    for line in input:lines() do
        words[line:trim()] = true
        wordsLower[line:lower():trim()] = true
        count = count + 1
    end
    input:close()
    checkWordCount("whitelist words", count)
    return words, wordsLower
end

function DocumentationConventions:getBlacklist(url)
    local file = self.testDir .. "/blacklist.txt"
    downloadData(url, file)
    local words = {}
    local wordsLower = {}
    local count = 0
    local input = io.open(file, "r")
    if not input then
        checkWordCount("blacklist words", 0)
        return {}
    end
    for line in input:lines() do
        local i = line:find("\t")
        local word = ""
        if i then
            word = line:sub(1, i - 1):trim()
        else
            word = line:trim()
        end
        words[word] = true
        wordsLower[word:lower()] = true
        count = count + 1
    end
    input:close()
    checkWordCount("blacklist words", count)
    return words, wordsLower
end

function readInputFile(file)
    local string = readInputFileAsString(file)
    if not string then
        return nil
    end
    return json.decode(string, 1, nil)
end

function readInputFileAsString(file)
    local input = io.open(file, "r")
    if not input then
       warn("Cannot open file: " .. file)
       return nil
    end
    local string = input:read("*all")
    input:close()
    return string
end

function checkWordCount(service, count)
    if count == 0 then
        warn("Possible error communicating with service: " .. service)
    else
        pass("Processed " .. count .. " " .. service .. ".")
    end
end

function downloadData(url, file)
    local command = "wget -O " .. file .. " " .. url .. " > /dev/null 2>&1"
    os.execute(command)
end

function createTable(params)
    local t = {}
    for param, value in pairs(params) do
        if value ~= "" then
            t[param] = value
        end
    end
    return t
end

function DocumentationConventions:checkWord(word)
    local isBlacklistedLowercase = false
    local isIncorrectLowercase = false
    local isWithCautionLowercase = false
    local lowercaseTable = {}
    
    if self.blacklist and self.blacklist[word] then
        if not self.blacklisted[word] then
            self.blacklisted[word] = createTable({})
        end
        return
    end
    
    if self.blacklistLowercase and self.blacklistLowercase[word] then
        isBlacklistedLowercase = true
        lowercaseTable = {lowercaseSource = "blacklist words"}
    end
    
    if self.glossaryIncorrect then
        local w = self.glossaryIncorrect[word]
        if w then
            if not self.incorrect[word] then
                self.incorrect[word] = createTable({source = w.source_name, correctForms = w.correct_forms})
            end
            return
        end
    end
    
    if self.glossaryIncorrectLowercase then
        w = self.glossaryIncorrectLowercase[word]
        if w then
            isIncorrectLowercase = true
            lowercaseTable = {lowercaseSource = "glossary incorrect words", source = w.source_name, correctForms = w.correct_forms}
        end
        
    end
    
    if (self.glossaryCorrect and self.glossaryCorrect[word]) or
            (self.whitelist and self.whitelist[word]) or
            (self.aspell and self.aspell[word]) then
        return
    end
    
    if self.glossaryWithCaution then
        w = self.glossaryWithCaution[word]
        if w then
            if not self.withCaution[word] then
                self.withCaution[word] = createTable({source = w.source_name, correctForms = w.correct_forms})
            end
            return
        end
    end
    
    if self.glossaryWithCautionLowercase then
        w = self.glossaryWithCautionLowercase[word]
        if w then
            isWithCautionLowercase = true
            lowercaseTable = {lowercaseSource = "glossary with caution words", source = w.source_name, correctForms = w.correct_forms}
        end 
    end
    
    if not isBlacklistedLowercase and not isIncorrectLowercase and not isWithCautionLowercase then
        return
    end
    
    if not self.withCautionLowercase[word] then
        self.withCautionLowercase[word] = createTable(lowercaseTable)
    end
end

function getTableLength(table)
    if not table then
        return 0
    end
    local length = 0
    for _, _ in pairs(table) do
        length = length + 1
    end
    return length
end

function calculateLine(lines, idx)
    local line = nil
    for i, lineIdx in ipairs(lines) do
        if idx > lineIdx then
            line = i
        end
    end
    if not line then
        line = #lines
    end
    return line
end

function findExtraWords(text, number)
    local cutoffIdx1 = text:find("\n", 1, true)
    local cutoffIdx2 = text:find(".", 1, true)
    if cutoffIdx1 and cutoffIdx2 then
        if cutoffIdx1 < cutoffIdx2 then
            text = text:sub(1, cutoffIdx1 - 1)
        else
            text = text:sub(1, cutoffIdx2 - 1)
        end
    elseif cutoffIdx1 then
        text = text:sub(1, cutoffIdx1 - 1)
    elseif cutoffIdx2 then
        text = text:sub(1, cutoffIdx2 - 1)
    end
    local words = text:gmatch("[^%s]+")
    local count = 0
    local extraWords = nil
    for word in words do
        if not extraWords then
            extraWords = word
        else
            extraWords = extraWords .. " " .. word
        end
        count = count + 1
        if count == number then
            break
        end
    end
    return extraWords
end

function findWordContext(string, word, startIdx)
    local leftSubstr = string:sub(1, startIdx - 1)
    local rightSubstr = string:sub(startIdx + #word)
    local leftContext = findExtraWords(leftSubstr:reverse(), 2)
    local rightContext = findExtraWords(rightSubstr, 2)
    local context = word
    if leftContext then
        context = leftContext:reverse() .. " " .. context
    end
    if rightContext then
        context = context .. " " .. rightContext
    end
    return context
end

function countLines(string)
    local lines = {0}
    local startSearchIdx = 1
    local idx1, idx2 = string:find("\n", startSearchIdx)
    while idx1 do
        table.insert(lines, idx1)
        startSearchIdx = idx2 + 1
        idx1, idx2 = string:find("\n", startSearchIdx)
        if idx2 == #string then
            idx1 = nil
        end
    end
    return lines
end

function replaceRegexWithSpaces(string, regex)
    local idx1, idx2 = string:find(regex)
    while idx1 do
        local substr = string:sub(idx1, idx2)
        local spaces = ""
        for i = 1, #substr do
            spaces = spaces .. " "
        end
        string = string:sub(1, idx1 - 1) .. spaces .. string:sub(idx2 + 1)
        idx1, idx2 = string:find(regex)
    end
    return string
end

function findWordInString(word, string, startSearchIdx)
    local words = string:sub(startSearchIdx):gmatch("[%w-/:_]+")
    local currentIdx = startSearchIdx
    for w in words do
        local startIdx = string:find(w, currentIdx, true)
        local _, colonCount = w:gsub(":", "")
        local colonIdx = w:find(":", 1, true)
        if colonCount == 1 and colonIdx == #w then
            if string:sub(startIdx, startIdx + #w):find("\n") 
                    or string:sub(startIdx, startIdx + #w):find(" ") then
                -- ":"" is not part of the word.
                local newWord = w:sub(1, colonIdx - 1) .. w:sub(colonIdx + 1)
                if newWord == word then
                    return startIdx
                end
            else
                if w == word then
                    return startIdx
                end
            end
        elseif w == word then
            return startIdx
        else
            currentIdx = startIdx + #w
        end
    end
    return nil
end

function findWordMatchesInFile(word, file)
    local input = io.open(file, "r")
    if not input then
        return {}
    end
    local text = ""
    for line in input:lines() do
        text = text .. line .. "\n"
    end
    local lines = countLines(text)
    local newText = replaceRegexWithSpaces(text, "<<.->>")
    newText = replaceRegexWithSpaces(newText, "```.-```")
    newText = replaceRegexWithSpaces(newText, "`.-`")
    local matches = {}
    local startSearchIdx = 1
    local idx1 = findWordInString(word, newText, startSearchIdx)
    while idx1 do
        local context = findWordContext(text, word, idx1)
        local line = calculateLine(lines, idx1)
        local shortPath = DocumentationConventions.includedFiles[file]
        table.insert(matches, shortPath .. " (line " .. line .. "): " .. context)
        startSearchIdx = idx1 + #word
        idx1 = findWordInString(word, newText, startSearchIdx)
    end 
    return matches
end

function DocumentationConventions:getFilesContainingWord(word)
    local allMatches = {}
    for file, _ in pairs(self.includedFiles) do
        local matches = findWordMatchesInFile(word, file)
        for _, val in ipairs(matches) do 
            table.insert(allMatches, val) 
        end
    end
    return allMatches
end

function DocumentationConventions:getPrintMessage(word, paramTable, files)
    local result = "**" .. word .. "**"
    local spaces = "      "
    local message = ""
    if paramTable.source then
        message = message .. "\n\t" .. spaces .. "SOURCE: " .. paramTable.source
    end
    if paramTable.correctForms then
        message = message .. "\n\t" .. spaces .. "CORRECT FORMS: " .. paramTable.correctForms
    end
    message = message .. "\n\t" .. spaces .. "ENCOUNTERED IN:"
    local counter = 1
    for _, file in ipairs(files) do
        message = message .. "\n\t" .. spaces .. counter .. ". " .. file
        counter = counter + 1
    end
    if paramTable.lowercaseMatch then
        message = message .. "\n\t" .. spaces .. "FOUND A LOWERCASE MATCH IN: " .. paramTable.lowercaseMatch
    end
    message = "\t" .. spaces .. "COUNT: " .. (counter - 1) .. message
    return result, message
end

function DocumentationConventions:printResults()
    local blacklistedCount = getTableLength(self.blacklisted)
    local incorrectCount = getTableLength(self.incorrect)
    local withCautionCount = getTableLength(self.withCaution)
    local withCautionLowercaseCount = getTableLength(self.withCautionLowercase)
    if blacklistedCount > 0 then
        local messages = {}
        for word, paramTable in pairs(self.blacklisted) do
            local files = DocumentationConventions:getFilesContainingWord(word)
            if #files > 0 then
                local result, message = self:getPrintMessage(word, paramTable, files)
                messages[message] = result
            else
                blacklistedCount = blacklistedCount - 1
            end
        end
        if blacklistedCount > 0 then
            if blacklistedCount == 1 then
                fail(string.upper("This word is blacklisted in the CCS Blacklist database:"))
            else
                fail(string.upper("These " .. blacklistedCount .. " words are blacklisted in the CCS Blacklist database:"))
            end
            for message, result in pairs(messages) do
                fail(result)
                print(message)
            end
        end
    end
    if incorrectCount > 0 then
        local messages = {}
        for word, paramTable in pairs(self.incorrect) do
            local files = DocumentationConventions:getFilesContainingWord(word)
            if #files > 0 then
                local result, message = self:getPrintMessage(word, paramTable, files)
                messages[message] = result
            else
                incorrectCount = incorrectCount - 1
            end
        end
        if incorrectCount > 0 then
            if incorrectCount == 1 then
                fail(string.upper("This word was marked as incorrect:"))
            else
                fail(string.upper("These " .. incorrectCount .. " words were marked as incorrect:"))
            end
            for message, result in pairs(messages) do
                fail(result)
                print(message)
            end
        end
    end
    if withCautionCount > 0 then
        local messages = {}
        for word, paramTable in pairs(self.withCaution) do
            local files = DocumentationConventions:getFilesContainingWord(word)
            if #files > 0 then
                local result, message = self:getPrintMessage(word, paramTable, files)
                messages[message] = result
            else
                withCautionCount = withCautionCount - 1
            end
        end
        if withCautionCount > 0 then
            if withCautionCount == 1 then
                warn(string.upper("This word should be used with caution:"))
            else
                warn(string.upper("These " .. withCautionCount .. " words should be used with caution:"))
            end
            for message, result in pairs(messages) do
                warn(result)
                print(message)
            end
        end
    end
    if withCautionLowercaseCount > 0 then
        local messages = {}
        for word, paramTable in pairs(self.withCautionLowercase) do
            local files = DocumentationConventions:getFilesContainingWord(word)
            if #files > 0 then
                local result, message = self:getPrintMessage(word, paramTable, files)
                messages[message] = result
            else
                withCautionLowercaseCount = withCautionLowercaseCount - 1
            end
        end
        if withCautionLowercaseCount > 0 then
            if withCautionLowercaseCount == 1 then
                warn(string.upper("This word was only matched by making it lowercase:"))
            else
                warn(string.upper("These " .. withCautionLowercaseCount .. " words were only matched by making them lowercase:"))
            end
            for message, result in pairs(messages) do
                warn(result)
                print(message)
            end
        end
    end
end

function DocumentationConventions:getGlossaryWordSource(word)
    for _, term in ipairs(self.glossary) do
        if term.word == word then
            return term.source_name:trimString()
        end
    end
    return "unknown"
end

function getWordList(readableParts)
    local words = {}
    for word in readableParts:gmatch("[%w%p-]+") do
        table.insert(words, word)
    end
    return words
end

function DocumentationConventions:checkWordUsage(readableParts)
    local words = getWordList(readableParts)
    local messages = {}
    local uniqueWords = {}
    local count = 0
    for i = 1, #words do
        local wordp2, wordp1, word, wordn1, wordn2 = unpack(words, i - 2)
        if self.differentSpellingWords[word] then
            if not uniqueWords[word] then
                uniqueWords[word] = true
                count = count + 1
                local result = "**" .. word .. "**"
                local spaces = "      "
                local source = "\t" .. spaces .. "SOURCE: " .. self:getGlossaryWordSource(word)
                local context = (wordp2 .. " " or "") .. (wordp1 .. " " or "") .. word .. " " .. (wordn1 .. " " or "") .. (wordn2 .. " " or "")
                local message = source .. "\n\t" .. spaces .. "CONTEXT: " .. context
                messages[message] = result
            end
        end
    end
    if count > 0 then
        if count == 1 then
            warn(string.upper("Verify that this word is used correctly. If it is, mark it as reviewed in the waiving system."))
        else
            warn(string.upper("Verify that these words are used correctly. If they are, mark them as reviewed in the waiving system."))
        end
        for message, result in pairs(messages) do
            warn(result)
            print(message)
        end
    end
end

function appendTables(table1, table2)
    local table3 = {}
    for key, val in pairs(table1) do
        if not table3[key]  then
            table3[key] = val
        end
    end
    for key, val in pairs(table2) do
        if not table3[key] then
            table3[key] = val
        end
    end
    return table3
end

-- Test documentation against the existing guidelines.
function DocumentationConventions.testDocumentationGuidelines()
    local readableText = DocumentationConventions.readableText
    if readableText and #readableText > 0 then
        local readableParts = table.concat(readableText, " ")
        for word in readableParts:gmatch("[%w%-?]+") do
            DocumentationConventions:checkWord(word:trimString())
        end
        DocumentationConventions:printResults()
    else
       fail("No readable text found.")
    end
end

-- Test documentation for incorrectly used words.
function DocumentationConventions.testWordUsage()
    local readableText = DocumentationConventions.readableText
    if readableText and #readableText > 0 then
        local readableParts = table.concat(readableText, " ")
        DocumentationConventions:checkWordUsage(readableParts)
    else
       fail("No readable text found.")
    end
end