local pcre2 = require 'pcre2'

local cached_pattern = nil
local cached_re = nil

local function highlight_pcre2(pattern, str)
	local re
	if pattern == cached_pattern then
		re = cached_re
	else
		re = assert(pcre2.new(pattern, pcre2.UCP, pcre2.UTF))
		re:jit_compile()
	end

	local head, tail, err = re:match(str)
	if err or not head then
		return {}
	end

	local captures = {}

	for i = 1, #head do
		if tail[i] > 0 then
			table.insert(captures, {head[i], tail[i]})
		end
	end

	return captures
end

return {
	highlight_pcre2 = highlight_pcre2,
}
