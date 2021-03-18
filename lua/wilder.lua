local cached_pattern = nil
local cached_re = nil

local function pcre2_highlight(pattern, str)
  local pcre2 = require('pcre2')

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

  -- remove first element which is the matched string
  for i = 2, #head do
    if tail[i] > 0 then
      -- convert from [{start+1}, {end+1}] to [{start}, {len}]
      table.insert(captures, {head[i] - 1, tail[i] - head[i] + 1})
    end
  end

  return captures
end

local function fzy_highlight(needle, haystack)
  local fzy = require('fzy-lua-native')

  local positions = fzy.positions(needle, haystack)

  if #positions == 0 then
    return {}
  end

  local spans = {}
  local start = positions[1] - 1
  local finish = positions[1] - 1

  -- consecutive sequences may represent multibyte characters so
  -- we merge them together
  for i = 2, #positions do
    local current = positions[i] - 1

    if current ~= finish + 1 then
      table.insert(spans, {start, finish - start + 1})
      start = current
    end

    finish = current
  end

  table.insert(spans, {start, finish - start + 1})

  return spans
end

return {
  fzy_highlight = fzy_highlight,
  pcre2_highlight = pcre2_highlight,
}
