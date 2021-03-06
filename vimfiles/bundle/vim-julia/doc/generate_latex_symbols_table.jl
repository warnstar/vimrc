#!/bin/env julia

const filename = "julia-vim-L2U-table"

# Keeping this from an old revision, just in case:
# Combining chars ranges, as obtained from https://en.wikipedia.org/wiki/Combining_character:
# ('\u0300' ≤ u ≤ '\u036F') ||
# ('\u1AB0' ≤ u ≤ '\u1AFF') ||
# ('\u1DC0' ≤ u ≤ '\u1DFF') ||
# ('\u20D0' ≤ u ≤ '\u20FF') ||
# ('\uFE20' ≤ u ≤ '\uFE2F')

# Most of this code is copy-pasted and slightly adapted from here:
# JULIA_HOME/doc/src/manual/unicode-input.md b/doc/src/manual/unicode-input.md
# except that instead of producing Markdown we want to generate a vim
# documentation file.

function tab_completions(symbols...)
    completions = Dict{String, Vector{String}}()
    for each in symbols, (k, v) in each
        completions[v] = push!(get!(completions, v, String[]), k)
    end
    return completions
end

function unicode_data()
    file = normpath(JULIA_HOME, "..", "..", "doc", "UnicodeData.txt")
    names = Dict{UInt32, String}()
    open(file) do unidata
        for line in readlines(unidata)
            id, name, desc = split(line, ";")[[1, 2, 11]]
            codepoint = parse(UInt32, "0x$id")
            names[codepoint] = (name == "" ? desc : desc == "" ? name : "$name / $desc")
        end
    end
    return names
end

# Prepend a dotted circle ('◌' i.e. '\u25CC') to combining characters
function fix_combining_chars(char)
    cat = Base.UTF8proc.category_code(char)
    return string(cat == 6 || cat == 8 ? "◌" : "", char)
end

function table_entries(completions, unicode_dict)
    code = String[]
    unicode = String[]
    latex = String[]
    desc = String[]

    for (chars, inputs) in sort!(collect(completions), by = first)
        code_points, unicode_names, characters = String[], String[], String[]
        for char in chars
            push!(code_points, "U+$(uppercase(hex(char, 5)))")
            push!(unicode_names, get(unicode_dict, UInt32(char), "(No Unicode name)"))
            push!(characters, isempty(characters) ? fix_combining_chars(char) : "$char")
        end
        push!(code, join(code_points, " + "))
        push!(unicode, join(characters))
        push!(latex, replace(join(inputs, ", "), "\\\\", "\\"))
        push!(desc, join(unicode_names, " + "))
    end
    return code, unicode, latex, desc
end

open("$filename.txt","w") do f
    print(f, """
        $filename.txt  LaTeX-to-Unicode reference table

        ===================================================================
        LATEX-TO-UNICODE REFERENCE TABLE    *L2U-ref* *julia-vim-L2U-reference*

          Note: This file is autogenerated from the script '$(basename(Base.source_path()))'
          The symbols are based on the documentation of Julia version $VERSION
          See |julia-vim| for the LaTeX-to-Unicode manual.

        """)

    col_headers = ["Code point(s)", "Character(s)", "Tab completion sequence(s)", "Unicode name(s)"]

    code, unicode, latex, desc =
        table_entries(
            tab_completions(
                Base.REPLCompletions.latex_symbols,
                Base.REPLCompletions.emoji_symbols
                ),
            unicode_data()
            )

    cw = max(length(col_headers[1]), maximum(map(length, code)))
    uw = max(length(col_headers[2]), maximum(map(length, unicode)))
    lw = max(length(col_headers[3]), maximum(map(length, latex)))
    dw = max(length(col_headers[4]), maximum(map(length, desc)))

    print_padded(c, u, l, d) = println(f, rpad(c, cw), " ", rpad(u, uw), " ", rpad(l, lw), " ", d)

    print_padded(col_headers[1:3]..., col_headers[4] * "~")
    print_padded("-"^cw, "-"^uw, "-"^lw, "-"^dw)

    for (c, u, l, d) in zip(code, unicode, latex, desc)
        print_padded(c, u, l, d)
    end
    print_padded("-"^cw, "-"^uw, "-"^lw, "-"^dw)

    println(f)
    println(f, "  vim", # separated to avoid an error from vim which otherwise tries to parse this line
               ":tw=$(cw+uw+lw+dw+3):et:ft=help:norl:")
end
