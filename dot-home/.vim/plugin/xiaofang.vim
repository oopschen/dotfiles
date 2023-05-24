" Xiao Fang is a smart edit assistant girl with beauty and wise
" feature list:
"
"
" Author: Chen Lei linxray@gmail.com
" Last Change: 2022.07.25
"

if exists("xiaofang")
    finish
endif

" map begin

" end

" map search selected text
:vnoremap ss y:let @/=@*<CR>

" search and replace
:vnoremap sr y:%s/<C-R>"//g<LEFT><LEFT>

" map end

" search in a range
function g:SSR(start, end, pattern)
  let @/ = "\\%>" . a:start . "l\\%<" . a:end . "l" . a:pattern
  normal! n
endf

:nnoremap ssr :call g:SSR(,, "")<LEFT><LEFT>

" fzf
let g:rg_command = '
  \ rg --column --no-heading -i -L --color "always" '

command! -bang -nargs=* Rg call fzf#vim#grep(g:rg_command .shellescape(<q-args>), 1, <bang>0)

:nmap <C-o> :Files<CR>
:nmap <C-n> :Rg<CR>
:nmap <C-b> :Buffers<CR>

" pandoc
function! FnPandocOpen(file)
	let file = shellescape(fnamemodify(a:file, ':p'))
	let file_extension = fnamemodify(a:file, ':e')
	if file_extension is? 'pdf'
		if !empty($PDFVIEWER)
			return expand('$PDFVIEWER') . ' ' . file
		elseif executable('zathura')
			return 'zathura ' . file
		elseif executable('mupdf')
			return 'mupdf ' . file
		endif
	elseif file_extension is? 'html'
		if !empty($BROWSER)
			return expand('$BROWSER') . ' ' . file
		elseif executable('firefox')
			return 'firefox ' . file
		elseif executable('firefox-bin')
			return 'firefox-bin ' . file
		elseif executable('chromium')
			return 'chromium ' . file
		elseif executable('google-chrome-stable')
			return 'google-chrome-stable ' . file
		endif
	elseif file_extension is? 'odt' && executable('okular')
		return 'okular ' . file
	elseif file_extension is? 'epub' && executable('okular')
		return 'okular ' . file
	else
		return 'xdg-open ' . file
	endif
endfunction 
" end

" UltiSnips
" Trigger configuration. You need to change this to something other than <tab> if you use one of the following:
" - https://github.com/Valloric/YouCompleteMe
" - https://github.com/nvim-lua/completion-nvim
let g:UltiSnipsExpandTrigger="<c-u>"
let g:UltiSnipsJumpForwardTrigger="<c-j>"
let g:UltiSnipsJumpBackwardTrigger="<c-l>"

" If you want :UltiSnipsEdit to split your window.
let g:UltiSnipsEditSplit="vertical"
" end
