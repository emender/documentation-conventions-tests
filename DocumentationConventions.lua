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
    tagsWithReadableText = {"para"},
    admonitions = {"note", "warning", "important"},
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
end



--
-- Read input file and return its content as a (possibly long) string.
--
function readInputFile(inputFileName)

    -- info for user
    yap("Reading input file: " .. inputFileName)

    -- open the file
    local fin = io.open(inputFileName, "r")

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
    -- and try to parse content of this string as JSON format
    -- (returned as table of tables...)
    return json.decode(str, 1, nil)
end





--
-- Helper function that loads aspell dictionary.
--
function loadAspellDictionary(filename)
    local words = {}
    local cnt = 0
    for line in io.lines(filename) do
        if line ~= "" then
            words[string.lower(line)] = true
            cnt = cnt + 1
        end
    end
    pass("Aspell dictionary: " .. cnt .. " words")
    return words
end



--
-- Helper function that loads atomic typos.
--
function loadAtomicTypos(filename)
    local words = {}
    local cnt = 0
    for line in io.lines(filename) do
        local i = string.find(line, "->")
        if i then
            local key = string.sub(line, 1, i-1)
            local val = string.sub(line, i+2)
            words[key]=val
            cnt = cnt + 1
        end
    end
    pass("Atomic typos: " .. cnt .. " words")
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



---
--- Tests that a guide does not contain any violations against our word usage guidelines.
---
function DocumentationConventions.testDocumentationGuidelines()
end

