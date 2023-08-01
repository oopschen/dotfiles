" plug manager
call plug#begin('~/.vim/plugged')

Plug 'SirVer/ultisnips'
Plug 'honza/vim-snippets'
"Plug 'altercation/vim-colors-solarized'
"Plug 'morhetz/gruvbox'
" since 2023/05/13
Plug 'joshdick/onedark.vim'

Plug 'vim-airline/vim-airline-themes'
Plug 'vim-airline/vim-airline'

"Plug 'fatih/vim-go', { 'for': 'go'}

"Plug 'pangloss/vim-javascript', { 'for': 'javascript'}
Plug 'mattn/emmet-vim', { 'for': ['javascript', 'markdown', 'javascript.jsx', 'html']}
"Plug 'mxw/vim-jsx', { 'for': ['javascript', 'javascript.jsx']}

"Plug 'rust-lang/rust.vim', { 'for': 'rust'}

"Plug 'Valloric/YouCompleteMe', { 'do': './install.py --clang-completer --go-completer --js-completer --rust-completer', 'for': ['javascript', 'go', 'javascript.jsx', 'c', 'cpp']}
"Plug 'rdnetto/YCM-Generator', { 'branch': 'stable', 'for': ['javascript', 'go', 'javascript.jsx', 'c', 'cpp']}
Plug 'neoclide/coc.nvim', {'branch': 'release'}

Plug 'vim-pandoc/vim-pandoc'
Plug 'vim-pandoc/vim-pandoc-syntax'

" use zsh installation instead Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --bin' }
Plug '~/.zplug/bin/fzf'
Plug 'junegunn/fzf.vim'

"Plug 'editorconfig/editorconfig-vim'
Plug 'jiangmiao/auto-pairs'
Plug 'godlygeek/tabular'
call plug#end()

" basic conf
set number
syntax on
set expandtab
set smarttab
set shiftwidth=4
set softtabstop=4
set tabstop=4
set autoindent
set smartindent

set history=1000
set autoread
"set cmdheight=1
set hlsearch
set magic
set incsearch
"set laststatus=2
set fileencodings=utf-8,gbk,gb2312

set t_Co=256
set timeoutlen=700
set pastetoggle=<F12>
set ignorecase
set smartcase
filetype indent plugin on
set hidden
set bkc=yes
set wrap
set linebreak
set updatetime=300
" end

"set rtp+=~/.vim/plugged/vim-jsx/after/syntax/jsx.vim

" color
"let g:solarized_termcolors=256
"set background=dark
"colorscheme gruvbox
"colorscheme solarized
"colorscheme dracula
"colorscheme jellybeans
" settings for onedark theme
"
if (empty($TMUX))
  if (has("nvim"))
    "For Neovim 0.1.3 and 0.1.4 < https://github.com/neovim/neovim/pull/2198 >
    let $NVIM_TUI_ENABLE_TRUE_COLOR=1
  endif
  "For Neovim > 0.1.5 and Vim > patch 7.4.1799 < https://github.com/vim/vim/commit/61be73bb0f965a895bfb064ea3e55476ac175162 >
  "Based on Vim patch 7.4.1770 (`guicolors` option) < https://github.com/vim/vim/commit/8a633e3427b47286869aa4b96f2bfc1fe65b25cd >
  " < https://github.com/neovim/neovim/wiki/Following-HEAD#20160511 >
  if (has("termguicolors"))
    set termguicolors
  endif
endif
colorscheme onedark
" end

" set bundle
" ycm
"let g:ycm_global_ycm_extra_conf = "~/.vim/ycm_extra_conf.py"
"let g:ycm_min_num_of_chars_for_completion = 4
"let g:ycm_complete_in_comments = 1
"let g:ycm_server_python_interpreter = 'python'

" vim-javascript
"let g:javascript_plugin_flow = 1
"let g:javascript_plugin_jsdoc = 1

" emmet
"let g:user_emmet_install_global = 0
"autocmd FileType html,css,javascript,markdown,javascript.jsx EmmetInstall


" vim-airline
"let g:airline#extensions#tabline#enabled = 1
let g:airline_theme='onedark'
let g:airline_powerline_fonts=1

" vim-jsx
"let g:jsx_ext_required = 0


" editor config
let g:EditorConfig_exclude_patterns = ['scp://.*']
"let g:EditorConfig_core_mode = 'external_command'

" auto pair
let g:AutoPairsShortcutFastWrap = '<C-e>w'
let g:AutoPairsShortcutToggle = '<C-e>t'

" pandoc
let g:pandoc#folding#level = 4
let g:pandoc#command#custom_open = "FnPandocOpen"

" netrw
let g:netrw_banner = 0
let g:netrw_winsize = 75
let g:netrw_browse_split = 4
let g:netrw_preview   = 1
let g:netrw_alto = 0
let g:netrw_liststyle = 3

" settings based on file type
autocmd FileType pandoc setlocal shiftwidth=2 softtabstop=2 tabstop=2
autocmd FileType c      setlocal shiftwidth=2 softtabstop=2 tabstop=2
autocmd FileType cpp    setlocal shiftwidth=2 softtabstop=2 tabstop=2
autocmd FileType kotlin setlocal shiftwidth=4 softtabstop=4 tabstop=4
