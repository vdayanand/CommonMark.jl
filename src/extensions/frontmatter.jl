struct FrontMatter <:AbstractBlock
    fence::String
    data::Dict{String, Any}
    FrontMatter(fence) = new(fence, Dict())
end

accepts_lines(::FrontMatter) = true

# GitLab uses the following:
#
# * `---` for YAML
# * `+++` for TOML
# * `;;;` for JSON
#
const reFrontMatter = r"^(\-{3}|\+{3}|;{3})$"

function continue_(frontmatter::FrontMatter, parser::Parser, container::Node)
    ln = SubString(parser.current_line, parser.next_nonspace)
    if !parser.indented
        m = Base.match(reFrontMatter, SubString(ln, parser.next_nonspace))
        if m !== nothing && m.match == frontmatter.fence
            finalize(parser, container, parser.line_number)
            return 2
        end
    end
    return 0
end

function finalize(frontmatter::FrontMatter, parser::Parser, block::Node)
    _, rest = split(block.string_content, '\n'; limit=2)
    block.string_content = rest
    return nothing
end

can_contain(t::FrontMatter) = false

function parse_front_matter(parser::Parser, container::Node)
    if parser.line_number === 1 && !parser.indented && container.t isa Document
        m = Base.match(reFrontMatter, SubString(parser.current_line, parser.next_nonspace))
        if m !== nothing
            close_unmatched_blocks(parser)
            container = add_child(parser, FrontMatter(m.match), parser.next_nonspace)
            advance_next_nonspace(parser)
            advance_offset(parser, length(m.match), false)
            return 2
        end
    end
    return 0
end

struct FrontMatterRule
    json::Function
    toml::Function
    yaml::Function

    function FrontMatterRule(; fs...)
        λ = str -> Dict{String, Any}()
        return new(get(fs, :json, λ), get(fs, :toml, λ), get(fs, :yaml, λ))
    end
end

block_rule(::FrontMatterRule) = Rule(parse_front_matter, 0.5, ";+-")
block_modifier(f::FrontMatterRule) = Rule(0.5) do parser, node
    if node.t isa FrontMatter
        fence = node.t.fence
        λ = fence == ";;;" ? f.json : fence == "+++" ? f.toml : f.yaml
        try
            merge!(node.t.data, λ(node.string_content))
        catch err
            node.literal = string(err)
        end
        node.string_content = ""
    end
    return nothing
end

# Frontmatter isn't displayed in the resulting output.

html(::FrontMatter, rend, node, enter) = nothing
latex(::FrontMatter, rend, node, enter) = nothing
term(::FrontMatter, rend, node, enter) = nothing