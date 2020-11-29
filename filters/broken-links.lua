--[[
-- From https://github.com/jgm/pandoc/issues/1621#issuecomment-613336520
--
-- A simple Lua filter to warn about broken anchors to self. This doesn't
-- handle concatenation of multiple Markdown files, so caveat emptor.
--
-- The only modification is to output to stderr in a way that GitHub
-- Actions handle. See
-- https://docs.github.com/en/free-pro-team@latest/actions/reference/workflow-commands-for-github-actions#setting-an-error-message
--]]
local identifiers = {}

function Block (b)
  if b.identifier then
    identifiers[b.identifier] = true
  end
end

function Inline (i)
  if i.identifier then
    identifiers[i.identifier] = true
  end
end

function Link (l)
  local anchor = l.target:match('#(.*)')
  if anchor and not identifiers[anchor] then
    io.stdout:write("::error::Unable to resolve link to " .. anchor .. "\n")
  end
end

return {
  {Block = Block, Inline = Inline},
  {Link = Link}
}
