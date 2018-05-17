-- publican.lua - Class that provides functions for working with publican documents.
-- Copyright (C) 2015 Pavel Vomacka
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
publican = {requires = {}}
publican.__index = publican


--
--- Constructor of the publican class. It allows to set name of publican configuration file
--  and path to the publican conf file. This function returns new object of this class
--  when everything is correct, otherwise nil.
--
--  Attributes of publican object: path, configuration_file, language
--
--  @param conf_file the name of configuration file"".
--  @param new_path to the publican configuration file.
--  @return New object. When there is some error then it returns nil.
function publican.create(conf_file, new_path)
  -- Check whether name of file is set.
  if conf_file == nil then
    fail("publican.lua: The name of configuration file has to be set. e.g. 'publican.cfg'")
    return nil
  end

  -- Create variable for new object.
  local publ = {}

  if new_path == nil then
    new_path = ""
  end

  -- Set metatable for new object.
  setmetatable(publ, publican)

  publ.path = new_path
  publ.configuration_file = conf_file
  publ.options = publ:fetchOptions()

  -- Check whether configuration file exists.
  if not publ:isPublicanProject() then
    return nil
  end

  -- Get language code from publican cfg file.
  publ.language = publ:getOption("xml_lang")

  -- TEMPORARY - default language is en-US:
  if not publ.language then
    publ.language = "en-US"
  end

  -- Return the new object.
  return publ
end

--
--- Function that checks whether set directory is the root directory of publican document.
--
--  @return true when there is publican. Otherwise false.
function publican:isPublicanProject()

  -- Check whether publican.cfg exist.
  if not path.file_exists(self.configuration_file) then
    fail("publican.lua: File '" .. self.configuration_file .. "' does not exists.")
    return false
  end

  return true
end


--
--- Function that parse given 'name: value' string (line from publican config file).
--
--  @return two variables - the first is name of option and the second is value of this option.
function publican.parseNameAndValue(str)
  -- Pattern with two captures, the first for name, the second for value.
  local match_f = str:gmatch("([^:]*)(.*)")
  local name = ""
  local value = ""

  -- Run iterator function to get name and value.
  name, value = match_f()

  -- Return name and trimmed value.
  return name, string.trimString(value)
end


--
--- Function that fetch all commands from publican configuration file
--
--  @return table with all options in this form: [name]=value
function publican:fetchOptions()
  -- Execute command, trim output and return it.
  local output = slurpTable(path.compose(self.path, self.configuration_file))

  -- Prepare list for trimmed output.
  local trimmed_output = {}
  for _, item in ipairs(output) do
    -- If line starts with # then skip this item because it is comment.
    if item:match("^[^#]") then
      name, value = publican.parseNameAndValue(item)
      trimmed_output[name] = value
    end
  end

  -- Return table with name and value of the option.
  return trimmed_output
end


--
--- Function that finds the file where the document starts.
--
--  @return path to the file from current directory
function publican:findMainFile()
    local main_file = self:getOption("mainfile")

    -- If mainfile option was found then return mainfile and add xml suffix.
    if main_file then
        return path.compose(self.path, self.language, main_file .. ".xml")
    else
        -- If mainfile option was not found then try to find entity file and use its name.
        local content_dir = path.compose(self.path, self.language)

        -- Lists the files in language directory.
        local command = "ls " .. content_dir .. "/*.ent 2>/dev/null"

        -- Execute command and return the output and substitute .xml suffix for .ent.
        local result = execCaptureOutputAsString(command)

        if result ~= "" then
            local newString, counter = string.gsub(result, "%.ent$", ".xml", 1)
            return newString
        end

        -- Return nil when there is not entity file.
        return nil
    end
end


--
--- Function that parse values from publican config file.
--
--  @param item_name is name of value which we want to find. The name without colon.
--  @return the value.
function publican:getOption(item_name)
  return self.options[item_name]
end


--
--- Function that return all options from pulican configuration file.
--
--  @return table with all publican options in this form: [name]=value
function publican:getAllOptions()
  return self.options
end



--
--- Function that finds document type and returns it. The type can be Book, Article or Set.
--
--  @return 'Book', 'Article' or 'Set' string according to type of book.
function publican:getDocumentType()
  local default_type = "Book"

  local d_type = self:getOption("type")

  -- In case that type is not mentioned in publican.cfg, default type is used.
  if d_type == "" then
    d_type = default_type
  end

  return d_type
end

--
--- Function that allows find all options from publican.cfg which names match pattern.
--
--  @param pattern by which options will be found.
--  @return table with options which match the pattern in this form: key = name_of_option, value = value_of_option.
function publican:matchOption(pattern)
  -- Go through all options and choose only those which match the pattern.
  local result_list = {}
  local found = false

  for name, value in pairs(self.options) do
    if name:match(pattern) then
      result_list[name] = value
      found = true
    end
  end

  -- In case that there is no option which match the pattern, return nil.
  if not found then
    return nil
  end

  -- Return list witch only options which match the pattern.
  return result_list
end
