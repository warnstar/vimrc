" rails.vim - Detect a rails application
" Author:       Tim Pope <http://tpo.pe/>
" GetLatestVimScripts: 1567 1 :AutoInstall: rails.vim

" Install this file as plugin/rails.vim.

if exists('g:loaded_rails') || &cp || v:version < 700
  finish
endif
let g:loaded_rails = 1

" Utility Functions {{{1

function! s:error(str)
  echohl ErrorMsg
  echomsg a:str
  echohl None
  let v:errmsg = a:str
endfunction

" }}}1
" Detection {{{1

function! RailsDetect(...) abort
  if exists('b:rails_root')
    return 1
  endif
  let fn = fnamemodify(a:0 ? a:1 : expand('%'), ':p')
  if fn =~# ':[\/]\{2\}'
    return 0
  endif
  if !isdirectory(fn)
    let fn = fnamemodify(fn, ':h')
  endif
  let file = findfile('config/environment.rb', escape(fn, ', ').';')
  if !empty(file) && isdirectory(fnamemodify(file, ':p:h:h') . '/app')
    let b:rails_root = fnamemodify(file, ':p:h:h')
    return 1
  endif
endfunction

function! s:log_detect() abort
  let path = matchstr(get(w:, 'quickfix_title'), '\<cgetfile \zs.*\ze[\\/]log[\\/].*.log$')
  if !empty(path) && filereadable(path . '/config/environment.rb') && isdirectory(path . '/app')
    let b:rails_root = path
    setlocal filetype=railslog
  endif
endfunction

" }}}1
" Initialization {{{1

if !exists('g:did_load_ftplugin')
  filetype plugin on
endif
if !exists('g:loaded_projectionist')
  runtime! plugin/projectionist.vim
endif

function! s:doau_user(arg) abort
  if exists('#User#'.a:arg)
    try
      let [modelines, &modelines] = [&modelines, 0]
      exe 'doautocmd User' a:arg
    finally
      let &modelines = modelines
    endtry
  endif
endfunction

augroup railsPluginDetect
  autocmd!
  autocmd BufEnter * if exists("b:rails_root")|call s:doau_user('BufEnterRails')|endif
  autocmd BufLeave * if exists("b:rails_root")|call s:doau_user('BufLeaveRails')|endif

  autocmd BufNewFile,BufReadPost *
        \ if RailsDetect(expand("<afile>:p")) && empty(&filetype) |
        \   call rails#buffer_setup() |
        \ endif
  autocmd VimEnter *
        \ if empty(expand("<amatch>")) && RailsDetect(getcwd()) |
        \   call rails#buffer_setup() |
        \   call s:doau_user('BufEnterRails') |
        \ endif
  autocmd FileType netrw
        \ if RailsDetect() |
        \   call s:doau_user('BufEnterRails') |
        \ endif
  autocmd FileType * if RailsDetect() | call rails#buffer_setup() | endif

  autocmd BufNewFile,BufReadPost *.yml,*.yml.example,*.yml.sample
        \ if &filetype !=# 'eruby.yaml' && RailsDetect() |
        \   set filetype=eruby.yaml |
        \ endif
  autocmd BufNewFile,BufReadPost *.rjs,*.rxml,*.builder,*.jbuilder,*.ruby
        \ if &filetype !=# 'ruby' | set filetype=ruby | endif
  autocmd BufReadPost *.log if RailsDetect() | set filetype=railslog | endif

  autocmd FileType qf call s:log_detect()
  autocmd FileType railslog call rails#log_setup()
  autocmd Syntax railslog call rails#log_syntax()
  autocmd Syntax ruby,eruby,haml,javascript,coffee,css,sass,scss
        \ if RailsDetect() | call rails#buffer_syntax() | endif

  autocmd User ProjectionistDetect
        \ if RailsDetect(get(g:, 'projectionist_file', '')) |
        \   call projectionist#append(b:rails_root,
        \     {'*': {"start": rails#app().static_rails_command('server')}}) |
        \ endif
augroup END

command! -bang -bar -nargs=* -count -complete=customlist,rails#complete_rails Rails execute rails#command(<bang>0, '<mods>', !<count> && <line1> ? -1 : <count>, <q-args>)

" }}}1
" abolish.vim support {{{1

function! s:function(name)
    return function(substitute(a:name,'^s:',matchstr(expand('<sfile>'), '<SNR>\d\+_'),''))
endfunction

augroup railsPluginAbolish
  autocmd!
  autocmd VimEnter * call s:abolish_setup()
augroup END

function! s:abolish_setup()
  if exists('g:Abolish') && has_key(g:Abolish,'Coercions')
    if !has_key(g:Abolish.Coercions,'l')
      let g:Abolish.Coercions.l = s:function('s:abolish_l')
    endif
    if !has_key(g:Abolish.Coercions,'t')
      let g:Abolish.Coercions.t = s:function('s:abolish_t')
    endif
  endif
endfunction

function! s:abolish_l(word)
  let singular = rails#singularize(a:word)
  return a:word ==? singular ? rails#pluralize(a:word) : singular
endfunction

function! s:abolish_t(word)
  if a:word =~# '\u'
    return rails#pluralize(rails#underscore(a:word))
  else
    return rails#singularize(rails#camelize(a:word))
  endif
endfunction

" }}}1
" vim:set sw=2 sts=2:
