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
        changed = "2018-04-25",
        tags = {"DocBook", "Release"}
    },
    
    -- These are set from external config files.
    docDir = nil,
    includedFiles = nil,
    
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
    testDir = nil
}



-- Entry point for the test.
function DocumentationConventions.setUp()
    dofile(getScriptDirectory() .. "lib/publican.lua")
    dofile(getScriptDirectory() .. "lib/docbook.lua")
    dofile(getScriptDirectory() .. "lib/xml.lua")
    local isReady = DocumentationConventions:checkVariables()
    if not isReady then
        return
    end
    DocumentationConventions:loadDictionaries()
end



function DocumentationConventions:checkVariables()
    self.docDir = getVarFromFile("results.cwd")
    if not self.docDir then
        return false
    end
    pass("Documentation directory: " .. self.docDir)
    if not self.docDir:endsWith("/") then
        self.docDir = self.docDir .. "/"
    end
    local publicanFile = "publican.cfg"
    if not canOpenFile(publicanFile) then
        return false
    end
    local pubObj = publican.create(publicanFile)
    local masterFile = pubObj:findMainFile()
    local docObj = docbook.create(masterFile)
    pass("Master file: " .. masterFile)
    self.readableText = docObj:getReadableText()
    local includesFile = "results.includes"
    if not canOpenFile(includesFile) then
        return false
    end
    self.includedFiles = self:includeFiles(includesFile)
    return true
end



function getVarFromFile(file)
    if not canOpenFile(file) then
        fail("Missing " .. file .. "...")
        return nil
    end
    local input = io.open(file, "r")
    for line in input:lines() do
        return line
    end
end
    


function getVarFromFile(file)
    local input = slurpTable(file)
    if input and #input >= 1 then
        return input[1]
    end
    return nil
end



function canOpenFile(file)
    if not file then
        fail("Missing " .. file .. "...")
        return false
    end
    local input = io.open(file, "r")
    if input then
        input:close()
        return true
    end
    return false
end



function DocumentationConventions:includeFiles(file)
    local list = {}
    local input = io.open(file, "r")
    local prefix = "Found an include:"
    for line in input:lines() do
        if line:startsWith(prefix) then
            local filename = line:sub(#prefix + 1):trim()
            if canOpenFile(filename) then
                pass("Included file: " .. filename)
                table.insert(list, filename)
            else
                warn("Could not include file: " .. filename)
            end
        end
    end
    input:close()
    return list
end



function DocumentationConventions:loadDictionaries()
    -- Store the words both in their original formatting and lowercase.
    self.testDir = getTestDir()
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
    local input = io.open(self.testDir .. self.atomicTyposFile, "r")
    if not input then
        warn("Cannot open atomic typos file: " .. self.testDir .. self.atomicTyposFile)
        return {}
    end
    for line in input:lines() do
      local i = line:find("->")
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
    local input = io.open(self.testDir .. self.aspellFile, "r")
    if not input then
        warn("Cannot open Aspell file: " .. self.testDir .. self.aspellFile)
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
    local file = self.testDir .. "glossary.json"
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
    local file = self.testDir .. "different_spelling_words.json"
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
    local file = self.testDir .. "whitelist.txt"
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
    local file = self.testDir .. "blacklist.txt"
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
    if not url then
        return
    end
    local command = "wget -O " .. file .. " " .. url .. "> /dev/null 2>&1"
    os.execute(command)
end



function getTestDir()
    local path = debug.getinfo(1).source
    if path:startsWith("@") then
        path = path:sub(2, path:lastIndexOf("/"))
    end
    return path
end



function createTableFromWord(word)
    local paramTable = {}
    if word.source and word.source ~= "" then
        paramTable.source = word.source
    end
    if word.correctForms and word.correctForms ~= "" then
        paramTable.correctForms = word.correct_forms
    end
    if word.lowercaseSource then
        paramTable.lowercaseSource = word.lowercaseSource
    end
    paramTable.count = 1
    return paramTable
end



function DocumentationConventions:checkWord(word)
    local isBlacklistedLowercase = false
    local isIncorrectLowercase = false
    local isWithCautionLowercase = false
    local blacklistedTable = {}
    local incorrectTable = {}
    local withCautionTable = {}
    
    if self.blacklist[word] then
        if not self.blacklisted[word] then
            self.blacklisted[word] = createTableFromWord({count = 1})
        else 
            self.blacklisted[word].count = self.blacklisted[word].count + 1
        end
        return
    end
    
    if self.blacklistLowercase[word] then
        isBlacklistedLowercase = true
        blacklistedTable = {lowercaseSource = "blacklist words"}
    end
    
    local w = self.glossaryIncorrect[word]
    if w then
        if not self.incorrect[word] then
            self.incorrect[word] = createTableFromWord({source = w.source_name, correctForms = w.correct_forms, count = 1})
        else 
            self.incorrect[word].count = self.incorrect[word].count + 1
        end
        return
    end
    
    w = self.glossaryIncorrectLowercase[word]
    if w then
        isIncorrectLowercase = true
        incorrectTable = {lowercaseSource = "glossary incorrect words", source = w.source_name, correctForms = w.correct_forms}
    end
    
    if self.glossaryCorrect[word] or
            self.whitelist[word] or
            self.aspell[word] then
        return
    end
    
    w = self.glossaryWithCaution[word]
    if w then
        if not self.withCaution[word] then
            self.withCaution[word] = createTableFromWord({source = w.source_name, correctForms = w.correct_forms, count = 1})
        else 
            self.withCaution[word].count = self.withCaution[word].count + 1
        end
        return
    end
    
    w = self.glossaryWithCautionLowercase[word]
    if w then
        isWithCautionLowercase = true
        withCautionTable = {lowercaseSource = "glossary with caution words", source = w.source_name, correctForms = w.correct_forms}
    end 
    
    -- If all else fails, check for a lowercase match.
    local table = {}
    if isBlacklistedLowercase then
        table = blacklistedTable
    elseif isIncorrectLowercase then
        table = incorrectTable
    elseif isWithCautionLowercase then
        table = withCautionTable
    else
        -- Nothing found.
        return
    end
    
    if not self.withCautionLowercase[word] then
        self.withCautionLowercase[word] = createTableFromWord(table.joinTables(table, {count = 1}))
    else
        self.withCautionLowercase[word].count = self.withCautionLowercase[word].count + 1
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



function grep(word, file)
    local regexp1 = "\\W" .. word .. "\\W"
    local regexp2 = "^" .. word .. "\\W"
    local regexp3 = "\\W" .. word .. "$"
    local regexp4 = "^" .. word .. "$"
    local ror = "\\|"
    local cmd = "grep -n -H '" .. regexp1 .. ror .. regexp2 .. ror .. regexp3 .. ror .. regexp4 .. "' " .. file
    return execCaptureOutputAsTable(cmd)
end



function DocumentationConventions:getFilesContainingWord(word)
    local allMatches = {}
    local master = "master.adoc"
    local masterMatches = {}
    if canOpenFile(master) then
        masterMatches = grep(word, master)
    end
    allMatches = table.appendTables(allMatches, masterMatches)
    for _, file in ipairs(self.includedFiles) do
        local matches = grep(word, file)
        allMatches = table.appendTables(allMatches, matches)
    end
    return allMatches
end



function getPrintMessage(word, paramTable, files)
    local message = "***" .. word .. "*** COUNT: " .. paramTable.count
    if paramTable.source then
        message = message .. ". SOURCE: " .. paramTable.source
    end
    if paramTable.correctForms then
        message = message .. ". CORRECT FORMS: " .. paramTable.correct_forms
    end
    message = message .. ". ENCOUNTERED IN: ["
    for _, file in ipairs(files) do
        message = message .. "'" .. file .. "', "
    end
    message = message:sub(1, #message - 2) .. "]"
    if paramTable.lowercaseMatch then
        message = message .. ". FOUND A LOWERCASE MATCH IN: " .. paramTable.lowercaseMatch .. " words."
    end
    return message
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
            local fileCount = getTableLength(files)
            if fileCount > 0 then
                table.insert(messages, getPrintMessage(word, paramTable, files))
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
            for _, message in ipairs(messages) do
                fail(message)
            end
        end
    end
    if incorrectCount > 0 then
        local messages = {}
        for word, paramTable in pairs(self.incorrect) do
            local files = DocumentationConventions:getFilesContainingWord(word)
            local fileCount = getTableLength(files)
            if fileCount > 0 then
                table.insert(messages, getPrintMessage(word, paramTable, files))
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
            for _, message in ipairs(messages) do
                fail(message)
            end
        end
    end
    if withCautionCount > 0 then
        local messages = {}
        for word, paramTable in pairs(self.withCaution) do
            local files = DocumentationConventions:getFilesContainingWord(word)
            local fileCount = getTableLength(files)
            if fileCount > 0 then
                table.insert(messages, getPrintMessage(word, paramTable, files))
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
            for _, message in ipairs(messages) do
                warn(message)
            end
        end
    end
    if withCautionLowercaseCount > 0 then
        local messages = {}
        for word, paramTable in pairs(self.withCautionLowercase) do
            local files = DocumentationConventions:getFilesContainingWord(word)
            local fileCount = getTableLength(files)
            if fileCount > 0 then
                table.insert(messages, getPrintMessage(word, paramTable, files))
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
            for _, message in ipairs(messages) do
                warn(message)
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
                local source = "SOURCE: " .. self:getGlossaryWordSource(word)
                local context = (wordp2 or "") .. " " .. (wordp1 or "") .. " " .. word .. " " .. (wordn1 or "") .. " " .. (wordn2 or "")
                local message = "**" .. word .. "** CONTEXT: '" .. context .. "'. " .. source
                table.insert(messages, message)
            end
        end
    end
    if count > 0 then
        if count == 1 then
            warn(string.upper("Verify that this word is used correctly. If it is, mark it as reviewed in the waiving system."))
        else
            warn(string.upper("Verify that these words are used correctly. If they are, mark them as reviewed in the waiving system."))
        end
        for _, message in ipairs(messages) do
            warn(message)
        end
    end
end



-- Test the documentation against the existing guidelines.
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



-- Test the documentation for incorrectly used words.
function DocumentationConventions.testWordUsage()
    local readableText = DocumentationConventions.readableText
    if readableText and #readableText > 0 then
        local readableParts = table.concat(readableText, " ")
        DocumentationConventions:checkWordUsage(readableParts)
    else
       fail("No readable text found.")
    end
end

