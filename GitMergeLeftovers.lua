-- GitMergeLeftovers
-- Copyright (C) 2017  Pavel Tisnovsky

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


GitMergeLeftovers = {
    metadata = {
        description = "Verify that the book does not contain any Git Merge Leftovers.",
        authors = "Pavel Tisnovsky",
        emails = "ptisnovs@redhat.com",
        changed = "2017-08-08",
        tags = {"Release"}
    },
    xmlObj = nil,
    pubObj = nil,
    docObj = nil,
    getReadableText = nil,
    language = "en-US",
    requires = {"curl", "xmllint", "xmlstarlet"},
}


function GitMergeLeftovers.setUp()
    dofile(getScriptDirectory() .. "lib/xml.lua")
    dofile(getScriptDirectory() .. "lib/publican.lua")
    dofile(getScriptDirectory() .. "lib/docbook.lua")
    dofile(getScriptDirectory() .. "lib/sql.lua")

    -- Create publican object.
    GitMergeLeftovers.pubObj = publican.create("publican.cfg")

    -- Create xml object.
    GitMergeLeftovers.xmlObj = xml.create(GitMergeLeftovers.pubObj:findMainFile())

    -- Create docbook object.
    GitMergeLeftovers.docObj = docbook.create(GitMergeLeftovers.pubObj:findMainFile())

    -- Get readable text.
    GitMergeLeftovers.readableText = GitMergeLeftovers.docObj:getReadableText()

    -- Get language code from this book.
    local language = GitMergeLeftovers.pubObj:getOption("xml_lang")

    -- Default language is en-US:
    if not language then
      language = "en-US"
    end

    -- Get list of xml files.
    GitMergeLeftovers.fileList = GitMergeLeftovers.getFileList(GitMergeLeftovers.pubObj:findMainFile(), language)
end



function GitMergeLeftovers.testGitLeftovers()

    -- Go through all files and check every file.
    for _, filePath in ipairs(GitMergeLeftovers.fileList) do
        pass("Checking **" .. filePath .. "**.")
        local fileObj = docbook.create(filePath)

        -- Get readable part of the current file.
        local readableParts = fileObj:getReadableText(0)

        -- Perform the test only if readable parts are not nil.
        if readableParts then
            for _, line in ipairs(readableParts) do
                if line:find("<<<<<<<") or line:find(">>>>>>>") then
                    fail("Possible merge conflict leftover has been found: **" .. line .. "**")
                end
            end
        end
    end
end


function GitMergeLeftovers.getFileList(fileN, language)
    -- Handle situtaion when xml file doesn't exist.
    if not path.file_exists(fileN) then
        return nil
    end

    -- create xml object for document main file and turn off the xincludes.
    local xmlObj = xml.create(fileN, 0)
    local wholeFileList = {}
    table.insert(wholeFileList, fileN)

    -- Get content of href attribute from the main file.
    local fileList = xmlObj:parseXml("//newnamespace:include/@href", "http://www.w3.org/2001/XInclude")

    -- If there is no other includes in the current file then return list with only current file.
    if not fileList then
        return wholeFileList
    end

    -- Append en-US directory for each file name and store it back to the table.
    for i, fileName in ipairs(fileList) do
        --print("expand", fileName)
        if not fileName:match("^" .. language) then
            fileList[i] = language .. "/" .. fileName
        end

        local nextFiles = TestWritingStyle.getFileList(fileList[i], language)

        if nextFiles then
            wholeFileList = table.appendTables(wholeFileList, nextFiles)
        end
    end

    -- Return the result table.
    return wholeFileList
end

