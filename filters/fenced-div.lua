function Div(el)
    for _, class in ipairs(el.classes) do
        if string.sub(class, 1, 6) == "layer-" then
            -- for docx
            el.attributes['custom-style'] = class

            -- for pdf
            -- insert element in front
            table.insert(
                el.content, 1,
                pandoc.RawBlock("latex", "\\begin{" .. class .. "}"))
            -- insert element at the back
            table.insert(
                el.content,
                pandoc.RawBlock("latex", "\\end{" .. class .. "}"))
        end
    end
    return el
end
