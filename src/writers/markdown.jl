# Public.

function Base.show(io::IO, ::MIME"text/markdown", ast::Node, env=Dict{String,Any}())
    writer = Writer(Markdown(io), io, env)
    write_markdown(writer, ast)
    return nothing
end
markdown(args...) = writer(MIME"text/markdown"(), args...)

# Internals.

mime_to_str(::MIME"text/markdown") = "markdown"

mutable struct Markdown{I <: IO}
    buffer::I
    indent::Int
    margin::Vector{MarginSegment}
    list_depth::Int
    list_item_number::Vector{Int}
    Markdown(io::I) where {I} = new{I}(io, 0, [], 0, [])
end

function write_markdown(writer::Writer, ast::Node)
    for (node, entering) in ast
        write_markdown(node.t, writer, node, entering)
    end
end

function linebreak(w, node)
    if !isnull(node.nxt)
        print_margin(w)
        literal(w, "\n")
    end
    return nothing
end

# Writers.

write_markdown(::Document, w, node, ent) = nothing

function write_markdown(::Text, w, node, ent)
    for c in node.literal
        c in MARKDOWN_ESCAPES && literal(w, '\\')
        literal(w, c)
    end
end
const MARKDOWN_ESCAPES = Set("\\[]*_#`")

function write_markdown(::Union{SoftBreak, LineBreak}, w, node, ent)
    cr(w)
    print_margin(w)
end

function write_markdown(::Code, w, node, ent)
    num = foldl(eachmatch(r"`+", node.literal); init=0) do a, b
        max(a, length(b.match))
    end
    literal(w, "`"^(num == 1 ? 3 : 1))
    literal(w, node.literal)
    literal(w, "`"^(num == 1 ? 3 : 1))
end

write_markdown(::HtmlInline, w, node, ent) = literal(w, node.literal)

function write_markdown(link::Link, w, node, ent)
    if ent
        literal(w, "[")
    else
        link = _smart_link(MIME"text/markdown"(), link, w.env)
        literal(w, "](", link.destination)
        isempty(link.title) || literal(w, " \"", link.title, "\"")
        literal(w, ")")
    end
end

function write_markdown(image::Image, w, node, ent)
    if ent
        literal(w, "![")
    else
        image = _smart_link(MIME"text/markdown"(), image, w.env)
        literal(w, "](", image.destination)
        isempty(image.title) || literal(w, " \"", image.title, "\"")
        literal(w, ")")
    end
end

write_markdown(::Emph, w, node, ent) = literal(w, "*")

write_markdown(::Strong, w, node, ent) = literal(w, "**")

function write_markdown(::Paragraph, w, node, ent)
    if ent
        print_margin(w)
    else
        cr(w)
        linebreak(w, node)
    end
end

function write_markdown(heading::Heading, w, node, ent)
    if ent
        print_margin(w)
        literal(w, "#"^heading.level, " ")
    else
        cr(w)
        linebreak(w, node)
    end
end

function write_markdown(::BlockQuote, w, node, ent)
    if ent
        push_margin!(w, ">")
        push_margin!(w, " ")
    else
        pop_margin!(w)
        pop_margin!(w)
        cr(w)
        linebreak(w, node)
    end
end

function write_markdown(list::List, w, node, ent)
    if ent
        w.format.list_depth += 1
        push!(w.format.list_item_number, list.list_data.start)
    else
        w.format.list_depth -= 1
        pop!(w.format.list_item_number)
        cr(w)
        linebreak(w, node)
    end
end

function write_markdown(item::Item, w, node, enter)
    if enter
        if item.list_data.type === :ordered
            number = lpad(string(w.format.list_item_number[end], ". "), 4, " ")
            w.format.list_item_number[end] += 1
            push_margin!(w, 1, number)
        else
            bullets = ['-', '+', '*', '-', '+', '*']
            bullet = bullets[min(w.format.list_depth, length(bullets))]
            push_margin!(w, 1, lpad("$bullet ", 4, " "))
        end
    else
        pop_margin!(w)
        if !item.list_data.tight
            cr(w)
            linebreak(w, node)
        end
    end
end

function write_markdown(::ThematicBreak, w, node, ent)
    print_margin(w)
    literal(w, "* * *")
    cr(w)
    linebreak(w, node)
end

function write_markdown(code::CodeBlock, w, node, ent)
    if code.is_fenced
        fence = code.fence_char^code.fence_length
        print_margin(w)
        literal(w, fence, code.info)
        cr(w)
        for line in eachline(IOBuffer(node.literal))
            print_margin(w)
            literal(w, line)
            cr(w)
        end
        print_margin(w)
        literal(w, fence)
        cr(w)
    else
        for line in eachline(IOBuffer(node.literal))
            print_margin(w)
            isempty(line) || literal(w, ' '^CODE_INDENT, line)
            cr(w)
        end
    end
    linebreak(w, node)
end

function write_markdown(::HtmlBlock, w, node, ent)
    for line in eachline(IOBuffer(node.literal))
        print_margin(w)
        literal(w, line)
        cr(w)
    end
    linebreak(w, node)
end
