local pcre2 = require 'pcre2'

local cached_pattern = nil
local cached_re = nil

local function extract_captures(pattern, str)
	local re
	if pattern == cached_pattern then
		re = cached_re
	else
		re = assert(pcre2.new(pattern))
		re:jit_compile()
	end

	local head, tail, err = re:match(str)
	if err then
		return {}
	end

	local captures = {}

	while head do
		for i = 1, #head do
			if tail[i] > 0 then
				table.insert(captures, {head[i], tail[i]})
			end
		end
		head, tail, err = re:match(str, tail[1])
		if err then
			break
		end
	end

	return {unpack(captures, 2)}
end

local function pcre2_highlight_captures(pattern, str, hl, selected_hl)
	local captures = extract_captures(pattern, str)

	local result = {}
	local start = #str
	for i = 1, #captures do
		local capture = captures[i]

		table.insert(result, str:sub(start, capture[1] - 1))
		table.insert(result, {
			value = str:sub(capture[1], capture[2]),
			hl = hl,
			selected_hl = selected_hl,
		})

		start = capture[2] + 1
	end

	table.insert(result, str:sub(start, #str))

	return result
end

return {
	pcre2_highlight_captures = pcre2_highlight_captures,
}
