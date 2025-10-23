return {
  "nvim-mini/mini.surround",
  opts = {
    custom_surroundings = {
      -- Double curly braces (assign to 'c' identifier)
      c = {
        output = { left = "{{ ", right = " }}" }, -- Adds spaces inside for readability; remove if you prefer "{{text}}"
      },
    },
  },
}
