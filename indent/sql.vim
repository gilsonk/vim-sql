" vim: ts=4 fdm=marker sw=4
" Author: Gilson, K
" Custom SQL indent following my personal preferences
" https://github.com/gilsonk/vim-sql
" Loosely based on the original vim one
" https://github.com/vim/vim/blob/master/runtime/indent/sqlanywhere.vim

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
    finish
endif
let b:did_indent = 1
let b:current_indent = "sqlanywhere"

" Remove unuse indentkeys
setlocal indentkeys-=0{
setlocal indentkeys-=0}
setlocal indentkeys-=:
setlocal indentkeys-=0#
setlocal indentkeys-=e

" GetSQLIndent is executed whenever one of the expressions
" in the indentkeys is typed
setlocal indentexpr=GetSQLIndent()

" Only define the functions once.
if exists("*GetSQLIndent")
    finish
endif
let s:keepcpo= &cpo
set cpo&vim

" Block to Increment after
let s:SQLBlockIncrement = '^\s*\('.
                        \ 'select'.
                        \ '\|from'.
                        \ '\|where'.
                        \ '\|group'.
                        \ '\|order'.
                        \ '\|partition'.
                        \ '\|full'.
                        \ '\|inner'.
                        \ '\|left'.
                        \ '\|right'.
                        \ '\|when'.
                        \ '\|else'.
                        \ '\|between'.
                        \ '\)\s*.*$'

" Block to Decrement on
let s:SQLBlockDecrement = '^\s*\('.
                        \ 'from'.
                        \ '\|where'.
                        \ '\|group'.
                        \ '\|order'.
                        \ '\|full'.
                        \ '\|inner'.
                        \ '\|left'.
                        \ '\|right'.
                        \ '\)\s*.*$'

" Block to avoid increment parentheses on
let s:SQLBlockParentInc = '^\s*.*\('.
                        \ 'over'.
                        \ '\|within'.
                        \ '\)\s*.*$'

" Block to avoid decrementing parentheses on
let s:SQLBlockParentDec = '^\s*\('.
                        \ 'and'.
                        \ '\|or'.
                        \ '\)\s*.*$'

" Check if the line is a comment
function! s:IsLineComment(lnum)
    let rc = synIDattr(
                \ synID(a:lnum,
                \     match(getline(a:lnum), '\S')+1, 0)
                \ , "name")
                \ =~? "comment"

    return rc
endfunction

" Instead of returning a column position, return
" an appropriate value as a factor of shiftwidth.
function! s:ModuloIndent(ind)
    let ind = a:ind

    if ind > 0
        let modulo = ind % shiftwidth()

        if modulo > 0
            let ind = ind - modulo
        endif
    " If negative, fix to 0
    else
        return 0
    endif

    return ind
endfunction

" Count paratheses
" Return positive number for single lefts
" Return negative number for single rights
function! s:CountParentheses(line)
    let l = a:line
    let lp = substitute(l, '[^(]', '', 'g')
    let l = a:line
    let rp = substitute(l, '[^)]', '', 'g')

    return (strlen(lp) - strlen(rp))
endfunction

" Main function
function! GetSQLIndent()
    let lnum = v:lnum
    let ind = indent(lnum)

    " Get previous non-blank line
    let prevlnum = prevnonblank(lnum - 1)
    if prevlnum <= 0
        return ind
    endif

    " Find first previous line that isn't a comment
    while s:IsLineComment(prevlnum) == 1
        let prevlnum = prevnonblank(prevlnum -1)
    endwhile

    " Get default indent (from prev. line)
    let ind = indent(prevlnum)
    let prevline = getline(prevlnum)

    " If line is a comment, don't touch the indentation
    if s:IsLineComment(lnum) == 1
        return ind
    endif

    " If previous line is part of a BlockIncrement
    " And previous line is not part of BlockParentInc
    if prevline =~? s:SQLBlockIncrement
    \ && prevline !~? s:SQLBlockParentInc
        " Increment
        let ind = ind + shiftwidth()
    " If previous line is an opening parenthese
    elseif prevline =~ '('
        " Increment based on the number of unmatched opening
        let num_unmatched = s:CountParentheses(prevline)
        let ind = ind + (shiftwidth() * num_unmatched)
    endif

    " Get current line
    let line =  getline(lnum)

    " If current line is part of a BlockDecrement
    " And previous line is not an opening parenthese
    if line =~? s:SQLBlockDecrement
    \ && prevline !~ '('
        " Decrement
        if prevline =~? s:SQLBlockParentDec
        \ && prevline =~ ')'
            let num_unmatched = -1 * s:CountParentheses(prevline)
            let ind = ind - ((2 * shiftwidth()) * num_unmatched)
        elseif prevline !~? s:SQLBlockParentDec
        \ && prevline =~ ')'
            let num_unmatched = -1 * s:CountParentheses(prevline)
            let ind = ind - (shiftwidth() * num_unmatched)
        else
            let ind = ind - shiftwidth()
        endif
    " If current line starts with a when
    elseif line =~? '^\s*when\s*'
        exec 'normal! ^'
        let matching_pair = searchpair('case', '', 'when', 'bW')
        let ind = indent(matching_pair) + shiftwidth()
    " If current line starts with an else
    elseif line =~? '^\s*else\s*'
        exec 'normal! ^'
        let matching_pair = searchpair('case', '', 'else', 'bW')
        let ind = indent(matching_pair) + shiftwidth()
    " If current line starts with an end
    elseif line =~? '^\s*end\s*'
        exec 'normal! ^'
        let matching_pair = searchpair('case', '', 'end', 'bW')
        let ind = indent(matching_pair)
    " If current line has an ending parenthese
    " And current line is not part of BlockParentDec
    elseif line =~ ')'
    \ && line !~? s:SQLBlockParentDec
    \ && s:CountParentheses(line) < 0
        exec 'normal! ^'
        let matching_pair = searchpair('(', '', ')', 'bW')
        let ind = indent(matching_pair)
    " If current line is the end of the query
    elseif line =~ '\;'
        " Reset indent
        let ind = 0
    endif

    " Return indentation
    return s:ModuloIndent(ind)
endfunction

"  Restore:
let &cpo= s:keepcpo
unlet s:keepcpo

