" Vim library for short description
" Maintainer:	Barry Arthur     <barry.arthur@gmail.com>
"       	Israel Chauca F. <israelchauca@gmail.com>
" Version:	0.1
" Description:	Long description.
" Last Change:	2013-07-01
" License:	Vim License (see :help license)
" Location:	autoload/vimdictive.vim
" Website:	https://github.com/dahu/vimdictive
"
" See vimdictive.txt for help.  This can be accessed by doing:
"
" :helptags ~/.vim/doc
" :help vimdictive

" Vimscript Setup: {{{1
" Allow use of line continuation.
let s:save_cpo = &cpo
set cpo&vim

" load guard
" uncomment after plugin development
" Remove the conditions you do not need, they are there just as an example.
"if exists("g:loaded_lib_vimdictive")
"      \ || v:version < 700
"      \ || v:version == 703 && !has('patch338')
"      \ || &compatible
"  let &cpo = s:save_cpo
"  finish
"endif
"let g:loaded_lib_vimdictive = 1

" Private Functions: {{{1

function! s:trim(text)
  return substitute(substitute(a:text, '^\_s*', '', ''), '\_s*$', '', '')
endfunction

function! s:uncurl(text, term, db, strategy)
  if a:strategy == 'd'
    return s:uncurl_definition(a:text, a:term, a:db)
  else
    return s:uncurl_match(a:text, a:term, a:db)
  endif
endfunction

function! s:uncurl_match(text, term, db)
  let r = ''
  let capture = 0
  let text = substitute(a:text, '\r', '', 'g')
  for s in split(text, '\n')
    if s =~ '^\_s*$'
      continue
    endif
    if s =~ '^\.'
      let capture = 0
    endif
    if capture == 1
      let r .= substitute(
            \    substitute(s, '^' . a:db . '\s\+"', '', ''),
            \    '"$', '', '')
            \ . "\n"
    endif
    if s =~? '^152\s\+'
      let capture = 1
    endif
  endfor
  return {'type' : 'match',
        \ 'term' : a:term, 'db' : a:db, 'entry' : s:trim(r)}
endfunction

function! s:uncurl_definition(text, term, db)
  let r = ''
  let capture = 0
  let text = substitute(a:text, '\r', '', 'g')
  for s in split(text, '\n')
    if s =~ '^\_s*$'
      continue
    endif
    if s =~ '^\.'
      let capture = 0
    endif
    if capture == 1
      let r .= s . "\n"
    endif
    if s =~? '^151\s\+"' . a:term . '"\s\+' . a:db
      let capture = 1
    endif
  endfor
  return {'type' : 'definition',
        \ 'term' : a:term, 'db' : a:db, 'entry' : s:trim(r)}
endfunction


" Library Interface: {{{1

function! vimdictive#lookup(dictionary, term, strategy)
  let strategy = {'definition' : 'd', 'match' : 'm'}[a:strategy]
  let host = g:vimdictive_dicts[a:dictionary]
  let results = []
  let curl_cmd = get(g:, 'dict_curl_command', 'curl')
  let curl_opts = get(g:, 'dict_curl_options', '')
  for db in host[1]
    let r = system(curl_cmd . ' -s ' . curl_opts . ' dict://' . host[0] . '/' . strategy . ':"' . a:term . '":' . db)
    let result = s:uncurl(r, a:term, db, strategy)
    call add(results, result)
  endfor
  return results
endfunction

function! vimdictive#entries(dictionary, term, strategy)
  let entries = vimdictive#lookup(a:dictionary, a:term, a:strategy)
  return map(entries, 'v:val["entry"]')
endfunction

function! vimdictive#synonyms(term)
  let syn = {}
  for entry in vimdictive#entries('thesaurus', a:term, 'definition')
    let entry = substitute(entry, '^.*:\n\s*', '', '')
    call map(split(entry, ',\_s*'), 'extend(syn, {v:val : 0})')
  endfor
  return sort(keys(syn))
endfunction

function! vimdictive#meanings(term)
  let meanings = []
  for entry in vimdictive#entries('dictionary', a:term, 'definition')
    call extend(meanings, split(entry, '\n'))
  endfor
  return meanings
endfunction

function! vimdictive#matches(term)
  let matches = []
  for entry in vimdictive#entries('dictionary', a:term, 'match')
    call extend(matches, split(entry, '\n'))
  endfor
  return matches
endfunction

"-----

function! vimdictive#rhyme(term)
  let rhymes = []
  if a:term =~ '^\s*$'
    return []
  endif
  if executable('rhyme')
    let data = system('rhyme -m ' . a:term)
    if data !~ '^\*\*\*\s\+.*wasn''t found'
      for line in split(data, "\n")
        if line =~ '^Finding perfect rhymes'
          continue
        endif
        if line =~ '^\s*$'
          continue
        endif
        let line = substitute(line, '^\d\+:\s\+', '', '')
        let line = substitute(line, '(\d\+)', '', 'g')
        call extend(rhymes, map(split(line, ',\s*'), 's:trim(v:val)'))
      endfor
    endif
  endif
  return rhymes
endfunction

"-----

function! vimdictive#antonyms(term)
  let ants = []
  if a:term =~ '^\s*$'
    return []
  endif
  if executable('wn')
    let data = system('wn ' . a:term . ' -antsn -antsv -antsa -antsr')
    for line in split(data, "\n")
      if line =~ '[-=]>'
        let line = substitute(line, '^.*[-=]>\s*', '', '')
        call extend(ants, map(split(line, ',\s*'), 's:trim(v:val)'))
      endif
    endfor
  endif
  return ants
endfunction

" Teardown:{{{1
"reset &cpo back to users setting
let &cpo = s:save_cpo

" vim: set sw=2 sts=2 et fdm=marker:
