-- docbook.lua - Class that provides functions for working with docbook documents.
-- Copyright (C) 2015, 2016  Pavel Vomacka, Pavel Tisnovsky
--
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


-- Define the class:
docbook = {requires = {}}
docbook.__index = docbook


--
--- Constructor of the docbook class.
--  @param file_path main file of docbook doucument.
--
--  @return New object. When there is some error then it returns nil.
function docbook.create(file_path)
  -- Empty object.
  local docb = {["readableTags"] = {"para", "simpara", "title", "entry"}}

  if not file_path then
    fail("You have to set main file of docbook document.")
  elseif not path.file_exists(file_path) then
    fail("File '" .. file_path .. "' does not exist.")
  end

  -- Store name file into object.
  docb.main_file = file_path

  -- Set metatable for new object.
  setmetatable(docb, docbook)

  -- Return the new object.
  return docb
end


--
--- Creates infofile object and return it. From this object you can get
--  information which are in book(article)info tag.
--
--  @return infofile object
function docbook:getInfoFile()
  return infofile.create(self.main_file)
end


--
--- Creates authorgroup object and return it. From this object you can get
--  information which are in authorgroup tag.
--
--  @return infofile object
function docbook:getAuthorGroup()
  return authorgroup.create(self.main_file)
end


--
--- Creates revhistory object and return it. From this object you can get
--  information which are in revhistory tag.
--
--  @return infofile object
function docbook:getRevHistory()
  return revhistory.create(self.main_file)
end


--
--- Function which get readable text from docbook document.
--
--  @param xinclude - 0 for disabling xincludes, 1 for enabling (default)
--  @return table with content
function docbook:getReadableText(xinclude)
    if not xinclude then xinclude = 1 end
    
    local xmlObj = xml.create(self.main_file, xinclude)

    return xmlObj:getContentOfMoreElements(self.readableTags, true)
end



--
-- Function that returns docbook version as a string major.minor
-- (this one is an ugly hack)
--
function docbook.readDocbookVersion(filename)
    local xmlPatterns = {
        "-//OASIS//DTD DocBook XML V(4%.[0-5])//EN",
        "http://www%.oasis%-open%.org/docbook/xml/(4%.[0-5])/docbookx%.dtd",
        [[<book .*xmlns=["']http://docbook%.org/ns/docbook["'].+version=["'](5%.[0-1])["'].*>]],
        [[<book .*version=["'](5%.[0-1])["'].+xmlns=["']http://docbook%.org/ns/docbook["'].*>]],
        [[<info .*xmlns=["']http://docbook%.org/ns/docbook["'].+version=["'](5%.[0-1])["'].*>]],
        [[<info .*version=["'](5%.[0-1])["'].+xmlns=["']http://docbook%.org/ns/docbook["'].*>]],
        [[<article .*xmlns=["']http://docbook%.org/ns/docbook["'].+version=["'](5%.[0-1])["'].*>]],
        [[<article .*version=["'](5%.[0-1])["'].+xmlns=["']http://docbook%.org/ns/docbook["'].*>]],
        [[<set .*xmlns=["']http://docbook%.org/ns/docbook["'].+version=["'](5%.[0-1])["'].*>]],
        [[<set .*version=["'](5%.[0-1])["'].+xmlns=["']http://docbook%.org/ns/docbook["'].*>]]
    }

    local fin = io.open(filename, "r")
    -- check if file can be opened
    if not fin then
        fail("Can not open master file: **" .. filename .. "**")
        return nil
    end
    for line in fin:lines() do
        for _,xmlPattern in ipairs(xmlPatterns) do
            local version = line:match(xmlPattern)
            if version then
                fin:close()
                return version
            end
        end
    end
    fin:close()
end



function docbook.xpathSelect(selector, expression, filename)
    return "xmlstarlet sel -N xx=\"http://docbook.org/ns/docbook\" -t -m '" .. selector .. "' -v '" .. expression .. "' -n " .. filename .. " 2>/dev/null"
end



--
-- Get all files which are included in current documentation.
--
--  @return table with one item form each file.
function docbook.getFileList(xml, fileN, language)
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

        local nextFiles = docbook.getFileList(xml, fileList[i], language)

        if nextFiles then
            wholeFileList = table.appendTables(wholeFileList, nextFiles)
        end
    end

    -- Return the result table.
    return wholeFileList
end

