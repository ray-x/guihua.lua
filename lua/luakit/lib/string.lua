--[[--字符串操作
@module string
@author iwiniwin

Date   2020-01-16 13:27:14
Last Modified by   iwiniwin
Last Modified time 2020-01-16 13:44:59
]]


-- local string = {};
---Allows the ability to index into a string using square-bracket notation
-- For example:
--		s = "hello"
--		s[1] = "h"
getmetatable('').__index = function(str, i)
	if (type(i) == 'number') then
		return string.sub(str, i, i)
	end
	
	return string[i]
end
 

--- Allows the ability to index into a string like above, but using normal brackes to
-- return the substring
-- For example:
--		s = "hello"
--		s(2,5) = "ello"
--
-- However, it also allows indexing into the string to return the byte (unicode) value
-- of the character found at the index. This only occurs if the second value is omitted
-- For example:
--      s = "hello"
--      s(2) = 101 (e)
--
-- Furthermore, it also allows for the ability to replace a character at the given index
-- with the given characters, iff the second value is a string
-- For example:
--		s = "hello"
--		s(2,'p') = "hpllo"
getmetatable('').__call = function(str, i, j)
	if (type(i) == 'number' and type(j) == 'number') then
		return string.sub(str, i, j)
	elseif (type(i) == 'number' and type(j) == 'string') then
		return table.concat{string.sub(str, 1, i - 1), j, string.sub(str, i + 1)}
	elseif (type(i) == 'number' and type(j) == 'nil') then
		return string.byte(str, i)
	end
	
	return string[i]
end



---Checks to see if the string starts with the given characters
function string.starts_with(str, chars)
	return chars == '' or string.sub(str, 1, string.len(chars)) == chars
end



---Checks to see if the string ends with the given characters
function string.ends_with(str, chars)
	return chars == '' or string.sub(str, -string.len(chars)) == chars
end



---Removes the length from the start of the string, returning the result
---Length can be a number or string
function string.remove_from_start(str, length)
	if (type(length) == 'number') then
		return string.sub(str, length + 1, string.len(str))
	elseif (type(length) == 'string') then
		return string.sub(str, string.len(length) + 1, string.len(str))
	else
		return str
	end
end



---Removes the length from the end of the string, returning the result
---Length can be a number or string
function string.remove_from_end(str, length)
	if (type(length) == 'number') then
		return string.sub(str, 1, string.len(str) - length)
	elseif (type(length) == 'string') then
		return string.sub(str, 1, string.len(str) - string.len(length))
	else
		return str
	end
end



---Removes a number of occurrences of the pattern from the string
---If limit is blank, removes all occurrences
function string.remove(str, pattern, limit)
	if (pattern == '' or pattern == nil) then
		return str
	end

	if (limit == '' or limit == nil) then
		str = string.gsub(str, pattern, '')
	else
		str = string.gsub(str, pattern, '', limit)
	end
	return str
end


--拼接字符串
function string.concat(str1, str2, concatStr)
	local ret =  table.concat({str1, str2}, concatStr)
	return ret
end



---Removes all occurrences of the pattern from the string
function string.remove_all(str, pattern)
	if (pattern == '' or pattern == nil) then
		return str
	end

	str = string.gsub(str, pattern, '')
	return str
end





---Removes the first occurrence of the pattern from the string
function string.remove_first(str, pattern)
	if (pattern == '' or pattern == nil) then
		return str
	end

	str = string.gsub(str, pattern, '', 1)
	return str
end



---Returns whether the string contains the pattern
function string.contains(str, pattern)
	if (pattern == '' or string.find(str, pattern, 1)) then
		return true
	end
	
	return false
end



---A case-insensitive string.find, returning start and end position of pattern in string
function string.findi(str, pattern)
	return string.find(string.lower(str), string.lower(pattern), 1)
end



---Returns the first substring which matches the pattern in the string from a start index
function string.find_pattern(str, pattern, start)
	if (pattern == '' or pattern == nil) then
		return ''
	end
	
	if (start == '' or start == nil) then
		start = 1
	end

	return string.sub(str, string.find(str, pattern, start))
end



------Split the string by the given pattern, returning an array of the result
------If pattern is omitted or nil, then default is to split on spaces
------Array index starts at 1
---function string.split(str, pattern)
---	local split = {}
---	local index = 1
	
---	if (pattern == '' or pattern == nil) then
---		pattern = '%s'
---	end
	
---	local previousstart = 1
---	local startpos, endpos = string.find(str, pattern, 1)
	
---	while (startpos ~= nil) do
---		split[index] = string.sub(str, previousstart, startpos - 1)
---		previousstart = endpos + 1
---		index = index + 1
---		startpos, endpos = string.find(str, pattern, endpos + 1)
---	end
	
---	split[index] = string.sub(str, previousstart, string.len(str))
	
---	return split
---end

---分割字字符串
--@usage split[index] = string.sub(str, previousstart, string.len(str))

--[[--
分割字字符串
]]
function string.split(str, delimiter)
	if (delimiter == '') then return false end
	local pos, arr = 0, {}
	-- for each divider found
	for st, sp in function() return string.find(str, delimiter, pos, true) end do
		table.insert(arr, string.sub(str, pos, st - 1))
		pos = sp + 1
	end
	table.insert(arr, string.sub(str, pos))
	return arr
end



---Returns the array of word contained within the string
---Array index starts at 1
function string.to_word_array(str)
	local words = {}
	local index = 1
	
	for word in string.gmatch(str, '%w+') do
		words[index] = word
		index = index + 1
	end
	
	return words
end



---Returns the number of letters within the string
function string.letter_count(str)
	local _, count = string.gsub(str, '%a', '')
	return count
end



---Returns the number of spaces within the string
function string.space_count(str)
	local _, count = string.gsub(str, '%s', '')
	return count
end



---Returns the number of times the pattern occurs within the string
function string.pattern_count(str, pattern)
	if (pattern == '' or pattern == nil) then
		return nil
	end

	local _, count = string.gsub(str, pattern, '')
	return count
end



---Returns a table of how many of each character appears in the string
---Table in the format: ["char"] = 2
function string.char_totals(str)
	local totals = {}
	local temp = ''
	
	for i = 1, string.len(str), 1 do
		temp = str[i]
		if (totals[temp]) then
			totals[temp] = totals[temp] + 1
		else
			totals[temp] = 1
		end
	end
	
	return totals
end

--模糊搜索，返回true、false,匹配单词中如果含有特殊字符串，返回false
function string.fuzzy_match(sourceStr,  searchStr)
	if string.find(searchStr,"[().%+-*?[^$]")then
		return 
	end 
	sourceStr = string.upper(sourceStr)
	searchStr = string.upper(searchStr)
	searchStr = string.gsub(searchStr,"",".*")
	if string.find(sourceStr,searchStr) then 
		return true
	end 
end

---Returns the number of words within the string
function string.word_count(str)
	local _, count = string.gsub(str, '%w+', '')
	return count
end



---Returns a string which contains the lengths of each each word found in the given string
function string.word_length(str)
	local lengths = string.gsub(str, '%w+', function(w) return string.len(w) end)
	return lengths
end



---Returns a table of how many of each word appears in the string
---Table in the format: ["word"] = 2
function string.word_totals(str)
	local totals = {}
	
	for word in string.gmatch(str, '%w+') do
		if (totals[word]) then
			totals[word] = totals[word] + 1
		else
			totals[word] = 1
		end
	end
	
	return totals
end



---Returns byte (unicode) representation of each character within the string as an array
---Array index starts at 1
function string.to_byte_array(str)
	local bytes = {}
	
	for i = 1, string.len(str), 1 do
		bytes[i] = string.byte(str, i)
	end
	
	return bytes
end



---Returns character representation of each character within the string as an array
---Array index starts at 1
function string.to_char_array(str)
	local chars = {}
	
	for i = 1, string.len(str), 1 do
		chars[i] = str[i]
	end
	
	return chars
end



---Returns a string where occurrences of the pattern are put into upper-case
function string.pattern_to_upper(str, pattern)
	if (pattern == '' or pattern == nil) then
		return str
	end

	local upper = string.gsub(str, pattern, string.upper)
	return upper
end



---Returns a string where occurrences of the pattern are put into lower-case
function string.pattern_to_lower(str, pattern)
	if (pattern == '' or pattern == nil) then
		return str
	end

	local lower = string.gsub(str, pattern, string.lower)
	return lower
end



---Returns a string, where the given string's occurrences of the pattern is replaced by
---the given characters, restricted by the given limit
function string.replace(str, pattern, chars, limit)
	if (pattern == '' or pattern == nil) then
		return str
	end

	if (limit == '' or limit == nil) then
		str = string.gsub(str, pattern, chars)
	else
		str = string.gsub(str, pattern, chars, limit)
	end
	return str
end



---Replaces the character at the given index with the given characters
function string.replace_at(str, index, chars)
	return table.concat{string.sub(str, 1, index - 1), chars, string.sub(str, index + 1)}
end



---Returns a string, where the given string's occurrences of the pattern is replaced by
---the given characters
function string.replace_all(str, pattern, chars)
	if (pattern == '' or pattern == nil) then
		return str
	end

	str = string.gsub(str, pattern, chars)
	return str
end



---Returns a string, where the given string's first occurrence of the pattern is replaced
---by the given characters
function string.replace_first(str, pattern, chars)
	if (pattern == '' or pattern == nil) then
		return str
	end

	str = string.gsub(str, pattern, chars, 1)
	return str
end



---Returns the index within the string for the first occurrence of the pattern after the
---given starting index
function string.index_of(str, pattern, start)
	if (pattern == '' or pattern == nil) then
		return nil
	end
	
	if (start == '' or start == nil) then
		start = 1
	end

	local position = string.find(str, pattern, start)
	return position
end



---Returns the index within the string for the first occurrence of the pattern
function string.first_index_of(str, pattern)
	if (pattern == '' or pattern == nil) then
		return nil
	end

	local position = string.find(str, pattern, 1)
	return position
end



---Returns the index within the string for the last occurrence of the pattern
function string.last_index_of(str, pattern)
	if (pattern == '' or pattern == nil) then
		return nil
	end
	
	local position = string.find(str, pattern, 1)
	local previous = nil
	
	while (position ~= nil) do
		previous = position
		position = string.find(str, pattern, previous + 1)
	end
	
	return previous
end



---Returns the character at the specified index in the string
function string.char_at(str, index)
	return str[index]
end



---Returns the byte (unicode) value of the character at given index in the string
---Basically the same as 'string.byte'
function string.byte_at(str, index)
	return string.byte(str, index)
end



---Returns the byte (unicode) value for the single given character
---nil is returned if not single character or otherwise
function string.byte_value(char)
	if (string.len(char) == 1) then
		return string.byte(char, 1)
	end
	
	return nil
end



---Compares two strings lexiographically. 1 is returned if str1 is greater than
---str2. -1 if str1 is less than str2. And 0 if they are equal
---This comparing is case-sensitive
function string.compare(str1, str2)
	local len1 = string.len(str1)
	local len2 = string.len(str2)
	local smallestLen = 0;
	
	if (len1 <= len2) then
		smallestLen = len1
	else
		smallestLen = len2
	end
	
	for i = 1, smallestLen, 1 do
		if (str1(i) > str2(i)) then
			return 1
		elseif (str1(i) < str2(i)) then
			return -1
		end
	end
	
	local lengthDiff = len1 - len2
	if (lengthDiff < 0) then
		return -1
	elseif (lengthDiff > 0) then
		return 1
	else
		return 0
	end
end



---Compares two strings lexiographically. 1 is returned if str1 is greater than
---str2. -1 if str1 is less than str2. And 0 if they are equal
---This comparing is case-insensitive
function string.comparei(str1, str2)
	return string.compare(string.lower(str1), string.lower(str2))
end



---Returns whether the two strings are equal to one another. True of they are,
---false otherwise
---This equals function is case-sensitive
function string.equal(str1, str2)
	local len1 = string.len(str1)
	local len2 = string.len(str2)
	
	if (len1 ~= len2) then
		return false
	end
	
	for i = 1, len1, 1 do
		if (str1[i] ~= str2[i]) then
			return false
		end
	end
	
	return true
end



---Returns whether the two strings are equal to one another. True of they are,
---false otherwise
---This equals function is case-insensitive
function string.equali(str1, str2)
	return string.equal(string.lower(str1), string.lower(str1))
end

---Returns the string representation of the given value. Be it either a
---number, boolean, string or a table. nil is returned otherwise for functions,
---threads, userdata and nil.
function string.valueof(value)
	local t = type(value)

	if (t == 'string') then
		return value
	elseif (t == 'number') then
		return '' .. value .. ''
	elseif (t == 'boolean') then
		if (value) then
			return "true"
		else
			return "false"
		end
	elseif (t == 'table') then
		local str = ""
		for k,v in pairs(value) do
			str = str .. "[" .. k .. "] = " .. v .. "\n"
		end
		str = string.sub(str, 1, string.len(str) - string.len("\n"))
		return str
	else
		return "nil"
	end
end



---Returns a string, where the given characters have been inserted into the
---string at the required index. An index of 0 specifies the front of the string
function string.insert(str, chars, index)
	if (index == 0) then
		return chars .. str
	elseif (index == string.len(str)) then
		return str .. chars
	else
		return string.sub(str, 1, index) .. chars .. string.sub(str, index + 1, string.len(str))
	end
end



---Returns a string, where the given characters have been inserted into the
---string rep times at the required index. An index of 0 specifies the front of
---the string
---For example:
--		string.insert_rep("ello", "h", 4, 0) = "hhhhello"
function string.insert_rep(str, chars, rep, index)
	local rep = string.rep(chars, rep)
	return string.insert(str, rep, index)
end



---Returns a string where all characters starting at the given index have
---been removed up to the end of the string (including the start index character)
function string.remove_to_end(str, index)
	if (index == 1) then
		return ""
	else
		return string.sub(str, 1, index - 1)
	end
end



---Returns a string where all char_aters starting at the given index have
---been removed down to the start of the string (including the start index character)
function string.remove_to_start(str, index)
	if (index == string.len(str)) then
		return ""
	else
		return string.sub(str, index + 1, string.len(str))
	end
end



---Returns a string where the given string has had any leading and
---trailing characters removed
---If char is left blank, then whitespaces are removed
--@usage
--string.trim("[[[word[[[", "%[") => "word"
--string.trim("   word   ") => "word"
function string.trim(str, char)
	if (char == '' or char == nil) then
		char = '%s'
	end

	local trimmed = string.gsub(str, '^' .. char .. '*(.-)' .. char .. '*$', '%1')
	return trimmed
end



---Returns a string where the given string has had any leading
---characters removed
---If char is left blank, then whitespaces are removed
function string.trim_start(str, char)
	if (char == '' or char == nil) then
		char = '%s'
	end

	local trimmed = string.gsub(str, '^' .. char .. '*', '')
	return trimmed
end



---Returns a string where the gievn string has had any trailing
---characters removed
---If char is left blank, then whitespaces are removed
function string.trim_end(str, char)
	if (char == '' or char == nil) then
		char = '%s'
	end

	local length = string.len(str)
	
	while (length > 0 and string.find(str, '^' .. char .. '', length)) do
		length = length - 1
	end
	
	return string.sub(str, 1, length)
end



---Returns a string where the given string has had variables substituted into it
--@usage
--string.subvar("x=$(x), y=$(y)", {x=200, y=300}) => "x=200, y=300"
--string.subvar("x=$(x), y=$(y)", {['x']=200, ['y']=300}) => "x=200, y=300"
function string.subvar(str, _table)
	str = string.gsub(str, "%$%(([%w_]+)%)", function(key)
		local value = _table[key]
		return value ~= nil and tostring(value)
	end)
	
	return str
end



---Rotates the string about the given index, returning the result.
--@usage
--string.rotate("hello, 3) => "lohel"
function string.rotate(str, index)
	local str1 = string.sub(str, 1, index)
	local str2 = string.sub(str, index + 1, string.len(str))
	return str2 .. str1
end



---Averages the two strings together. This is done by adding the byte (unicode) values
---of parallel characters and dividing by 2.
function string.average(str1, str2)
	local len1 = string.len(str1)
	local len2 = string.len(str2)
	local smallestLen = 0
	local newstr = ''
	
	if (len1 <= len2) then
		smallestLen = len1
	else
		smallestLen = len2
	end
	
	for i = 1, smallestLen, 1 do
		newstr = newstr .. string.char( (str1(i) + str2(i)) / 2 )
	end
	
	if (len1 <= len2) then
		newstr = newstr .. string.sub(str2, smallestLen + 1, string.len(str2))
	else
		newstr = newstr .. string.sub(str1, smallestLen + 1, string.len(str1))
	end
	
	return newstr
end



---Swaps the two characters at the given indices of the string
function string.swap(str, index1, index2)
	local temp = str[index1]
	str = str(index1, str[index2])
	return str(index2, temp)
end



---Sorts the string into ascending order according to their unicode values.
function string.sort_ascending(str)
	local chars = str:to_char_array()
	table.sort(chars, function(a,b) return a(1) < b(1) end)
	return table.concat(chars)
end



---Sorts the string into descending order according to their unicode values.
function string.sort_descending(str)
	local chars = str:to_char_array()
	table.sort(chars, function(a,b) return a(1) > b(1) end)
	return table.concat(chars)
end



---Returns the character with the highest byte (unicode) value
function string.highest(str)
	local s = string.sort_descending(str)
	return s[1]
end



---Returns the character with the lowest byte (unicode) value
function string.lowest(str)
	local s = string.sort_ascending(str)
	return s[1]
end



---Checks to see if the string is empty
function string.is_empty(str)
	if (str == '' or str == nil) then
		return true
	end
	
	return false
end



---Returns a table for the percentage of how much the string is formed of
---each word.
--@usage
--string.word_percents("hello, world!") = {"hello" = 38.46, "world" = 38.46}
function string.word_percents(str)
	local t = string.word_totals(str)
	local count = string.len(str)
	
	for k,v in pairs(t) do
		t[k] = ((string.len(k) * v) / count) * 100.0
	end
	
	return t
end



---Returns the percentage for how much of the string is formed by the given word
--@usage
--string.word_percent("hello, world!", "hello") = 50
function string.word_percent(str, word)
	local t = string.word_percents(str)
	
	if (t[word]) then
		return t[word]
	end
	
	return 0
end



---Returns a table for the percentage of how much the string is formed of
---each character.
--@usage
--string.char_percents("hello") = {"h" = 20, "e" = 20, "l" = 40, "o" = 20}
function string.char_percents(str)
	local t = string.char_totals(str)
	local count = string.len(str)
	
	for k,v in pairs(t) do
		t[k] = (v/count) * 100.0
	end
	
	return t
end



---Returns the percentage for how much of the string is formed by the given character
--@usage
--string.char_percent("hello", "h") = 20
function string.char_percent(str, char)
	local t = string.char_percents(str)
	
	if (t[char]) then
		return t[char]
	end
	
	return 0
end



---Returns the percentage for how much of the string is formed by whitespace
function string.space_percent(str)
	local count = string.space_count(str)
	return (count / string.len(str)) * 100.0
end



---Returns the number of uppercase characters in the string
function string.upper_count(str)
	local _, count = string.gsub(str, '%u', '')
	return count
end



---Returns the percentage for how much of the string is formed by uppercase
---characters
function string.upper_percent(str)
	local count = string.upper_count(str)
	return (count / string.len(str)) * 100.0
end



---Returns the number of lowercase characters in the string
function string.lower_count(str)
	local _, count = string.gsub(str, '%l', '')
	return count
end



---Returns the percentage for how much of the string is formed by lowercase
---characters
function string.lower_percent(str)
	local count = string.lower_count(str)
	return (count / string.len(str)) * 100.0
end



---Returns the number of single digits in the string
function string.digit_count(str)
	local _, count = string.gsub(str, '%d', '')
	return count
end



---Returns a table of how many of each single digit appears in the string
function string.digit_totals(str)
	local totals = {}
	
	for digit in string.gmatch(str, '%d') do
		if (totals[digit]) then
			totals[digit] = totals[digit] + 1
		else
			totals[digit] = 1
		end
	end
	
	return totals
end



---Returns a table for the percentage of how much the string is formed of
---each single digit.
--@usage
--string.digit_percents("hello, 2world!") = {"2" = 7.14}
function string.digit_percents(str)
	local t = string.digit_totals(str)
	local count = string.len(str)
	
	for k,v in pairs(t) do
		t[k] = ((string.len(k) * v) / count) * 100.0
	end
	
	return t
end



---Returns the percentage for how much of the string is formed by the given single digit
--@usage
--string.digit_percent("hello2", "2") = 16.67
function string.digit_percent(str, digit)
	local t = string.digit_percents(str)
	
	if (t[digit]) then
		return t[digit]
	end
	
	return 0
end



---Returns the amount of punctuation in the string
function string.punc_count(str)
	local _, count = string.gsub(str, '%p', '')
	return count
end



---Returns a table of how many of each punctuation appears in the string
function string.punc_totals(str)
	local totals = {}
	
	for punc in string.gmatch(str, '%p') do
		if (totals[punc]) then
			totals[punc] = totals[punc] + 1
		else
			totals[punc] = 1
		end
	end
	
	return totals
end



---Returns a table for the percentage of how much the string is formed of
---each punctuation.
--@usage
--string.punc_percents("hello, world!") = {"," = 7.69, "!" = 7.69}
function string.punc_percents(str)
	local t = string.punc_totals(str)
	local count = string.len(str)
	
	for k,v in pairs(t) do
		t[k] = ((string.len(k) * v) / count) * 100.0
	end
	
	return t
end



---Returns the percentage for how much of the string is formed by the given punctuation
--@usage
--string.punc_percent("hello, world!", ",") = 7.69
function string.punc_percent(str, punc)
	local t = string.punc_percents(str)
	
	if (t[punc]) then
		return t[punc]
	end
	
	return 0
end



---Concatenates an array of strings together, with optional seperation characters
---This is basically the same as doing table.concat(table, sep)
function string.join(array, sep)
	return table.concat(array, sep)
end



---Returns the Levenshtein distance between the two given strings
function string.levenshtein(str1, str2)
	local len1 = string.len(str1)
	local len2 = string.len(str2)
	local matrix = {}
	local cost = 0
	
	if (len1 == 0) then
		return len2
	elseif (len2 == 0) then
		return len1
	elseif (str1 == str2) then
		return 0
	end
	
	for i = 0, len1, 1 do
		matrix[i] = {}
		matrix[i][0] = i
	end
	for j = 0, len2, 1 do
		matrix[0][j] = j
	end
	
	for i = 1, len1, 1 do
		for j = 1, len2, 1 do
			if (str1[i] == str2[j]) then
				cost = 0
			else
				cost = 1
			end
			
			matrix[i][j] = math.min(matrix[i-1][j] + 1, matrix[i][j-1] + 1, matrix[i-1][j-1] + cost)
		end
	end
	
	return matrix[len1][len2]
end



---Makes the string's first character lowercase
function string.lower_first(str)
	return str(1, string.lower(str[1]))
end



---Makes the string's first character uppercase
function string.upper_first(str)
	return str(1, string.upper(str[1]))
end



---Randomly shuffles the given string
function string.shuffle(str)
	local temp = ''
	local length = string.len(str)
	local ran1, ran2 = 0, 0
	math.randomseed(os.time())
	
	for i = 1, length , 1 do
		ran1 = math.random(length)
		ran2 = math.random(length)
		temp = str[ran1]
		str = str(ran1, str[ran2])
		str = str(ran2, temp)
	end
	
	return str
end



---Converts the given integer value into a binary string of length limit
---If limit is omitted, then a binary string of length 8 is returned
function dectobin(dec, limit)
	if (limit == '' or limit == nil) then
		limit = 8
	end

	local bin = ''
	local rem = 0
	
	for i = 1, dec, 1 do
		rem = dec % 2
		dec = dec - rem
		bin = rem .. bin
		dec = dec / 2
		if (dec <= 0) then break end
	end
	
	local padding = limit - (string.len(bin) % limit)
	if (padding ~= limit) then
		bin = string.insert_rep(bin, '0', padding, 0)
	end
	
	return bin
end



---Returns the uuencoded representation of the given string
function string.uuencode(str)
	local padding = 3 - (string.len(str) % 3)
	if (padding ~= 3) then
		str = string.insert_rep(str, string.char(1), padding, string.len(str))
	end
	
	local uuenc = ''
	local bin1, bin2, bin3, binall = '', '', '', ''
	
	for i = 1, string.len(str) - 2, 3 do
		bin1 = dectobin(string.byte(str[i]), 8)
		bin2 = dectobin(string.byte(str[i+1]), 8)
		bin3 = dectobin(string.byte(str[i+2]), 8)
		
		binall = bin1 .. bin2 .. bin3

		uuenc = uuenc .. string.char(tonumber(binall(1,6), 2) + 32)
		uuenc = uuenc .. string.char(tonumber(binall(7,12), 2) + 32)
		uuenc = uuenc .. string.char(tonumber(binall(13,18), 2) + 32)
		uuenc = uuenc .. string.char(tonumber(binall(19,24), 2) + 32)
	end
	
	return uuenc
end



---Returns the actual string from a uuencoded string
function string.uudecode(str)	
	local padding = 4 - (string.len(str) % 4)
	if (padding ~= 4) then
		str = string.insert_rep(str, string.char(1), padding, string.len(str))
	end
	
	local uudec = ''
	local bin1, bin2, bin3, bin4, binall = '', '', '', '', ''
	
	for i = 1, string.len(str) - 3, 4 do
		bin1 = dectobin(string.byte(str[i]) - 32, 6)
		bin2 = dectobin(string.byte(str[i+1]) - 32, 6)
		bin3 = dectobin(string.byte(str[i+2]) - 32, 6)
		bin4 = dectobin(string.byte(str[i+3]) - 32, 6)
		
		binall = bin1 .. bin2 .. bin3 .. bin4
		
		uudec = uudec .. string.char(tonumber(binall(1,8), 2))
		uudec = uudec .. string.char(tonumber(binall(9,16), 2))
		uudec = uudec .. string.char(tonumber(binall(17,24), 2))
	end
	
	return string.trim(uudec, string.char(1))
end



---Returns a simple hash key for a string. If the check value is ommited
---then the string is hashed by the prime value of 17
---Best results occur when the check value is prime
function string.hash(str, check)
	local sum = 0
	local checksum = 17
	local length = string.len(str)
	
	if (check ~= '' and check ~= nil) then checksum = check end
	
	sum = str(1) + 1
	sum = sum + str(length) + length
	sum = sum + str(length/2) + math.ceil(length/2)
	
	return sum % checksum
end

---url字符转换
function string.urlencode_char(char)
	return "%" .. string.format("%02X", string.byte(char))
end

---url字符转换
function string.urlencode(str)
	---convert line endings
	str = string.gsub(tostring(str), "\n", "\r\n")
	---escape all characters but alphanumeric, '.' and '-'
	str = string.gsub(str, "([^%w%.%- ])", string.urlencode_char)
	---convert spaces to "+" symbols
	return string.gsub(str, " ", "+")
end

function string.ltrim(str)
    return string.gsub(str, "^[ \t\n\r]+", "")
end

function string.rtrim(str)
    return string.gsub(str, "[ \t\n\r]+$", "")
end

function string.trim(str)
    str = string.gsub(str, "^[ \t\n\r]+", "")
    return string.gsub(str, "[ \t\n\r]+$", "")
end

---检测手机号码是否正确
function string.is_phone_num( PhoneNumText )
    local phoneNum = string.trim(PhoneNumText);
    local start, length = string.find(phoneNum, "^1[3|4|5|8|7][0-9]%d+$"); ---判断手机号码是否正确
    if start ~= nil and length == 11 then
        return true ;
    end
    return false;
end

---计算文字utf8的长度
function string.utf8len(str)
	local len = #str
	local left = len
	local cnt = 0
	local arr = {0, 0xc0, 0xe0, 0xf0, 0xf8, 0xfc }
	while left > 0 do
		local tmp = string.byte(str, -left)
		local i = #arr
		while arr[i] do
			if tmp >= arr[i] then
				left = left - i
				break
			end
			i = i - 1
		end
		cnt = cnt + 1
	end
	return cnt
end

--按照utf8格式取子串
function string.utf8_sub_str(str,subLen)

	if subLen == 0 then return "" end 
	if str == nil then 
		debug.traceback()
	print(str, "str")
	end

	local len = #str
	local left = len
	local cnt = 0
	local arr = {0, 0xc0, 0xe0, 0xf0, 0xf8, 0xfc }
	while left > 0 do
		local tmp = string.byte(str, -left)
		local i = #arr
		while arr[i] do
			if tmp >= arr[i] then
				left = left - i
				break
			end
			i = i - 1
		end
		cnt = cnt + 1
		if cnt >= subLen then
			break;
		end
	end
	local temp = string.sub(str,0,len - left);
	return temp
end


function string.utf8_char_str( str, index )
 
	 local last = string.utf8_sub_str(str, index - 1)

	 local tem = string.utf8_sub_str(str, index) 
	 local utf8_char_str = string.sub(str, #last + 1, #tem)

	return utf8_char_str
end

-- local string = _G['string'];


-- for k,v in pairs(string) do
--     -- print_string(k)
--     -- print_string(v)
--     if string[k] then
--     	-- print("k---",k)
--     else
--     	string[k] = v;
--     	-- print("k2---",k)
--     end
-- end

return string;