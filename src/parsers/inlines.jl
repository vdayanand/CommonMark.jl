const ESCAPED_CHAR = "\\\\$(ESCAPABLE)"
const WHITESPACECHAR = collect(" \t\n\x0b\x0c\x0d")

const reLinkTitle             = Regex("^(?:\"($(ESCAPED_CHAR)|[^\"\\x00])*\"|'($(ESCAPED_CHAR)|[^'\\x00])*'|\\(($(ESCAPED_CHAR)|[^()\\x00])*\\))")
const reLinkDestinationBraces = r"^(?:<(?:[^<>\n\\\x00]|\\.)*>)"
const reEscapable             = Regex("^$(ESCAPABLE)")
const reEntityHere            = Regex("^$(ENTITY)", "i")
const reTicks                 = r"`+"
const reTicksHere             = r"^`+"
const reEllipses              = r"\.\.\."
const reDash                  = r"--+"
const reEmailAutolink         = r"^<([a-zA-Z0-9.!#$%&'*+\/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*)>"
const reAutolink              = r"^<[A-Za-z][A-Za-z0-9.+-]{1,31}:[^<>\x00-\x20]*>"i
const reSpnl                  = r"^ *(?:\n *)?"
const reWhitespaceChar        = r"^^[ \t\n\x0b\x0c\x0d]"
const reWhitespace            = r"[ \t\n\x0b\x0c\x0d]+"
const reUnicodeWhitespaceChar = r"^\s"
const reFinalSpace            = r" *$"
const reInitialSpace          = r"^ *"
const reSpaceAtEndOfLine      = r"^ *(?:\n|$)"
const reLinkLabel             = r"^\[(?:[^\\\[\]]|\\.){0,1000}\]"
const reMain                  = r"^[^\n`\[\]\\!<&*_'\"]+"m

mutable struct Delimiter
    cc::Char
    numdelims::Int
    origdelims::Int
    node::Node
    previous::Union{Nothing, Delimiter}
    next::Union{Nothing, Delimiter}
    can_open::Bool
    can_close::Bool
end

mutable struct Bracket
    node::Node
    previous::Union{Nothing, Bracket}
    previousDelimiter::Union{Nothing, Delimiter}
    index::Int
    image::Bool
    active::Bool
    bracket_after::Bool
end

mutable struct InlineParser <: AbstractParser
    # required
    buf::String
    pos::Int
    len::Int
    # extra
    brackets::Union{Nothing, Bracket}
    delimiters::Union{Nothing, Delimiter}
    refmap::Dict
    options::Dict
    inline_parsers::Dict{Char, Vector{Function}}

    function InlineParser(options=Dict())
        parser = new()
        parser.buf = ""
        parser.pos = 1
        parser.len = length(parser.buf)
        parser.brackets = nothing
        parser.delimiters = nothing
        parser.refmap = Dict()
        parser.options = options
        parser.inline_parsers = copy(COMMONMARK_INLINE_PARSERS)
        return parser
    end
end

include("inlines/code.jl")
include("inlines/escapes.jl")
include("inlines/autolinks.jl")
include("inlines/html.jl")
include("inlines/emphasis.jl")
include("inlines/links.jl")
include("inlines/text.jl")

const COMMONMARK_INLINE_PARSERS = Dict(
    '\n' => [parse_newline],
    '\\' => [parse_backslash],
    '`'  => [parse_backticks],
    '*'  => [parse_asterisk],
    '_'  => [parse_underscore],
    '''  => [parse_single_quote],
    '"'  => [parse_double_quote],
    '['  => [parse_open_bracket],
    '!'  => [parse_bang],
    ']'  => [parse_close_bracket],
    '<'  => [parse_autolink, parse_html_tag],
    '&'  => [parse_entity],
)

function parse_inline(parser::InlineParser, block::Node)
    c = trypeek(parser, Char)
    c === nothing && return false
    res = false
    if haskey(parser.inline_parsers, c)
        for λ in parser.inline_parsers[c]
            res = λ(parser, block)
            res && break
        end
    else
        res = parse_string(parser, block)
    end
    if !res
        read(parser, Char)
        append_child(block, text(c))
    end
    return true
end

function parse_inlines(parser::InlineParser, block::Node)
    parser.buf = strip(block.string_content)
    parser.pos = 1
    parser.len = length(parser.buf)
    parser.delimiters = nothing
    parser.brackets = nothing
    while (parse_inline(parser, block))
        nothing
    end
    process_emphasis(parser, nothing)
end

function parse(parser::InlineParser, block::Node)
    return parse_inlines(parser, block)
end