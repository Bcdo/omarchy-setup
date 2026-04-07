-- OKLCH color highlighting for mini.hipatterns

local hl_cache = {}

vim.api.nvim_create_autocmd("ColorScheme", {
  callback = function()
    hl_cache = {}
  end,
})

--- Convert OKLCH (L: 0-1, C: 0-~0.4, H: 0-360) to a hex color string.
local function oklch_to_hex(L, C, H)
  -- OKLCH to OKLab
  local h_rad = H * math.pi / 180
  local a = C * math.cos(h_rad)
  local b = C * math.sin(h_rad)

  -- OKLab to LMS (cube root space)
  local l_ = L + 0.3963377774 * a + 0.2158037573 * b
  local m_ = L - 0.1055613458 * a - 0.0638541728 * b
  local s_ = L - 0.0894841775 * a - 1.2914855480 * b

  -- Cube to get LMS
  local l = l_ * l_ * l_
  local m = m_ * m_ * m_
  local s = s_ * s_ * s_

  -- LMS to linear sRGB
  local r = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
  local g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
  local bl = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s

  -- Linear sRGB to sRGB (gamma correction)
  local function gamma(c)
    if c <= 0.0031308 then
      return 12.92 * c
    else
      return 1.055 * math.pow(c, 1 / 2.4) - 0.055
    end
  end

  r = math.max(0, math.min(1, gamma(r)))
  g = math.max(0, math.min(1, gamma(g)))
  bl = math.max(0, math.min(1, gamma(bl)))

  return string.format(
    "#%02x%02x%02x",
    math.floor(r * 255 + 0.5),
    math.floor(g * 255 + 0.5),
    math.floor(bl * 255 + 0.5)
  )
end

--- Parse an oklch(...) string into L, C, H values.
local function parse_oklch(str)
  local content = str:match("oklch%((.+)%)")
  if not content then
    return nil
  end

  local parts = {}
  for part in content:gmatch("[%d%.]+%%?%a*") do
    table.insert(parts, part)
  end
  if #parts < 3 then
    return nil
  end

  -- Lightness: 0-1 or 0%-100%
  local L
  if parts[1]:match("%%") then
    L = tonumber(parts[1]:match("([%d%.]+)")) / 100
  else
    L = tonumber(parts[1])
  end

  -- Chroma: 0-0.4 or 0%-100% (100% = 0.4)
  local C
  if parts[2]:match("%%") then
    C = tonumber(parts[2]:match("([%d%.]+)")) / 100 * 0.4
  else
    C = tonumber(parts[2])
  end

  -- Hue: degrees by default, supports deg/rad/turn suffixes
  local H
  local h_num = tonumber(parts[3]:match("([%d%.]+)"))
  if parts[3]:match("rad") then
    H = h_num * 180 / math.pi
  elseif parts[3]:match("turn") then
    H = h_num * 360
  else
    H = h_num
  end

  if not (L and C and H) then
    return nil
  end
  return L, C, H
end

return {
  "nvim-mini/mini.hipatterns",
  opts = {
    highlighters = {
      oklch_color = {
        pattern = "oklch%([^%)]+%)",
        group = function(_, match)
          local L, C, H = parse_oklch(match)
          if not L then
            return nil
          end

          local hex = oklch_to_hex(L, C, H)
          local hl_name = "MiniHipatternsOklch_" .. hex:sub(2)

          if not hl_cache[hl_name] then
            local fg = L > 0.6 and "#000000" or "#ffffff"
            vim.api.nvim_set_hl(0, hl_name, { bg = hex, fg = fg })
            hl_cache[hl_name] = true
          end

          return hl_name
        end,
        extmark_opts = { priority = 2000 },
      },
    },
  },
}
