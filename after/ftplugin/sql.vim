" vim: ts=4 fdm=marker sw=4
" Author: Gilson, K
" Custom SQL after/ftplugin following my personal preferences
" Add a functions to toggle comments type, and format the code
" https://github.com/gilsonk/vim-sql

" Set formatoptions
setlocal formatoptions+=j
setlocal formatoptions-=q

" Convert -- to /* */
function! SQLCommentsLineToBlock()
    silent! :%s/-\{2\}\s*\(.*\)\s*/\/\* \1 \*\//g
endfunction

" Convert /* */ to --
function! SQLCommentsBlockToLine()
    while 1
        try
            silent :%s/\(\/\*[^*]*\)[\r\n]/\1 /g
        catch
            break
        endtry
    endwhile
    silent! :%s/\(\/\*\)\([^*]*\)\(\*\/\)/--\2/g
endfunction

" SQL Formatting
function! SQLFormatFile()
    " TODO: Simplify syntax
    " FIXME:
    " * /, +, * etc are split between quotes

    " Save cursor position
    let l:cursor_pos = winsaveview()

    " Convert single line comments into block comments
    silent! :%s/-\{2\}\s*\(.*\)\s*/\/\* \1 \*\//g

    " Remove carriage return within block comments and put block in a new line
    while 1
        try
            silent :%s/\(\/\*[^*]*\)[\r\n]/\1 /g
        catch
            break
        endtry
    endwhile

    " Select values within quotes and put them on new lines
    silent! :%s/\s*\(\'[^']*\'\)\s*/\r\1\r/g

    " Remove leading spaces for existing comments
    silent! :%s/\s*\(\/\*\)/\1/g

    " Put all lines in lower case except when
    " * Withing quotes
    " * In block comments
    silent! :%s/^\(\(\'\)\|\(\/\*\)\)\@!.*$/\L\0/g

    " Put everything in one line, and remove dupplicate spaces
    silent! :%s/\s*[\r\n]\s*/ /g
    silent! :%s/\s\{2,\}/ /g

    " Uniformisation of (in)equalities
    silent! :%s/\s*\(\(=\)\|\(<>\)\|\(!=\)\|\(<\)\|\(>\)\)\s*/ \1 /g

    " Move slashes that are not part of a comments to their own lines
    " silent! :%s/\%('\)\@![^*']\+\zs\s*\(\/\)\s*\ze[^*']\+\%('\)\@!/\r\1 /g
    silent! :%s/\%('\)\@![^/*']\+\zs\s*\(\/\)\s*\ze[^/*']\+\%('\)\@!/\r\1 /g

    " Move stars that are not part of a comments to their own lines
    " silent! :%s/\%('\)\@![^/']\+\zs\s*\(\*\)\s*\ze[^/']\+\%('\)\@!/\r\1 /g
    silent! :%s/\%('\)\@![^/*']\+\zs\s*\(\*\)\s*\ze[^/*']\+\%('\)\@!/\r\1 /g

    " Move clauses, comments, and concatenations, and operations to new lines
    silent! :%s/\s\+\(select\|from\|where\|having\|order\)\s\+/\r\1 /g
    silent! :%s/\s\+\(within\s\+\)\@<!\(group\)\s\+/\r\2 /g
    silent! :%s/\s\+\(full\|inner\|left\|right\|on\)\s\+/\r\1 /g
    silent! :%s/\s\+\(and\|or\)\s\+/\r\1 /g
    silent! :%s/\s\+\(when\|then\|else\)\s\+/\r\1 /g
    silent! :%s/\s\+\(end\)\s*/\r\1 /g

    " Operators that don't have necessarily spaces before
    silent! :%s/\s*\(||\)\s*/\r\1 /g
    silent! :%s/\%('\)\@![^']\+\zs\s*\([\+\-\%]\)\s*\ze[^']\+\%('\)\@!/\r\1 /g

    " Isolate comments on their own line
    silent! :%s/\(\/\*\([^*]\|\([\r\n]\)\)*\*\/\)/\r\1\r/g

    " New lines before commas, except within quotes
    while 1
        try
            silent :%s/\([^,']\+\)\s*,\s*\([^']*\)/\1\r, \2/g
        catch
            break
        endtry
    endwhile

    " Re-aggregate block comments that were potentially splitted
    while 1
        try
            " Slighty different version from above, excluding a space
            silent :%s/\(\/\*[^*]*\)[\r\n]/\1 /g
        catch
            break
        endtry
    endwhile

    " ; in a new line
    silent! :%s/\([^;]*\);/\1\r;/g

    " table.FIELD as FIELD
    silent! :%s/\(\w\+\)\.\(\w\+\)/\L\1\.\U\2/g
    silent! :%s/\(\s\+as\s\+\)\(\w\+\)/\L\1\U\2/g
    silent! :%s/^\(\(from\|full\|inner\|left\|right\)\s\+.*\)$/\L\1/g

    " Remove spaces in between parentheses
    silent! :%s/(\s*/(/g
    silent! :%s/\s*)/)/g

    " Paratheses on a newline - for opening ones, only if preceded by a space
    " Ignore the ones in a comment
    " silent! :%s/\s\+(/\r(/g
    while 1
        try
            silent :%s/^\%(\%(\'\)\|\%(\/\*\)\)\@!\(.*\)\s\+\((\)/\1\r\2/g
        catch
            break
        endtry
    endwhile

    " silent! :%s/(/(\r/g
    while 1
        try
            silent :%s/^\%(\%(\'\)\|\%(\/\*\)\)\@!\(.*\)(\([^\n\r]\+\)/\1(\r\2/g
        catch
            break
        endtry
    endwhile

    " silent! :%s/)/\r)/g
    while 1
        try
            silent :%s/^\%(\%(\'\)\|\%(\/\*\)\)\@!\([^\n\r]\+\))\(.*\)/\1\r)\2/g
        catch
            break
        endtry
    endwhile

    " Remove empty lines
    silent! :g/^\s*$/d

    " Paratheses with nothing between, or a *, on a same line
    silent! :%s/([\r\n]\+\(\*\?\)[\r\n]\?)/(\1)/g

    " Functions with no parameters in uppercase; e.g. ROW_NUMBER()
    silent! :%s/\(\w\+()\)/\U\1/g

    " Isolate clauses
    silent! :%s/^\%(\%(\'\)\|\%(\/\*\)\)\@!\(.*select\(\s\+distinct\)\?\)\s\+/\1\r/g
    silent! :%s/^\%(\%(\'\)\|\%(\/\*\)\)\@!\(.*\(from\|where\|join\|by\|having\)\)\s\+/\1\r/g
    silent! :%s/^\%(\%(\'\)\|\%(\/\*\)\)\@!\(.*union\(\s\+all\)\?\)\s\+/\1\r/g
    silent! :%s/^\%(\%(\'\)\|\%(\/\*\)\)\@!\(.*between\)\s\+/\1\r/g

    " Remove paratheses newlines for ON clauses
    " FIXME: Ignore comments?
    "        Wrong deletion when there is multiple parentheses
    silent!: %s/on[\r\n]([\r\n]\(\([\r\n]\|[^)]\)*\)[\r\n])/on (\1)/g

    " FIXME: Need to double the indent to fix some cases
    execute "normal! gg=G"
    execute "normal! gg=G"

    " Split comments on 80 characters
    " let l:wrapscan_val = &wrapscan
    setlocal nowrapscan
    execute "normal! gg"
    while 1
        try
            execute "normal! \/\\/\\*\.\\{80\\}\<CR>"
            execute "normal! gqq"
        catch
            break
        endtry
    endwhile
    " set wrapscan<
    " setlocal wrapscan<
    setlocal wrapscan
    " setlocal l:wrapscan_val
    " setlocal wrapscan=&l:wrapscan_val
    " setlocal &l:wrapscan_val

    " Remove trailing spaces
    silent! :%s/\s\+$//g

    " Move cursor to original position
    call winrestview(l:cursor_pos)
endfunction

