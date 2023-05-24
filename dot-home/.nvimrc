" vundle setup
filetype off
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()
Plugin 'VundleVim/Vundle.vim'
Plugin 'https://github.com/kien/ctrlp.vim.git'
Plugin 'https://github.com/Valloric/YouCompleteMe.git'
Plugin 'rdnetto/YCM-Generator'
Plugin 'SirVer/ultisnips'
Plugin 'honza/vim-snippets'
Plugin 'fatih/vim-go'
Plugin 'pangloss/vim-javascript'
Plugin 'mattn/emmet-vim'
Plugin 'https://github.com/mxw/vim-jsx.git'
Plugin 'git://github.com/altercation/vim-colors-solarized.git'
Plugin 'rust-lang/rust.vim'
call vundle#end()

" basic conf
set number
syntax on
set expandtab
set shiftwidth=2
set softtabstop=2
set tabstop=2
set smartindent

set cmdheight=1
set magic
set fileencodings=utf-8,gbk,gb2312

filetype plugin indent on
set t_Co=256
set timeoutlen=700
set pastetoggle=<F12>
set ignorecase
set smartcase
" end

" color
let g:solarized_termcolors=256
syntax enable
set background=light
colorscheme solarized
"colorscheme jellybeans
" end

" set bundle
" ctrlp
let g:ctrlp_working_path_mode = "a"
set runtimepath^=~/.vim/bundle/ctrlp.vim

" ycm
let g:ycm_key_list_select_completion=[]
let g:ycm_key_list_previous_completion=[]
let g:ycm_global_ycm_extra_conf = "~/.vim/ycm_extra_conf.py"
let g:ycm_min_num_of_chars_for_completion = 2
let g:ycm_complete_in_comments = 1

" ultisnips
let g:UltiSnipsExpandTrigger="<c-e>"
let g:UltiSnipsListSnippets="<c-l>"
let g:UltiSnipsEditSplit="vertical"

" ctrlp
set wildignore+=*/tmp/*,*.so,*.swp,*.zip     " MacOSX/Linux
set wildignore+=*\\tmp\\*,*.swp,*.zip,*.exe  " Windows
set wildignore+=*/CMakeFiles/*,**/CMakeCache.txt,*.cmake " cmake
set wildignore+=**/target

let g:ctrlp_custom_ignore = {
  \ 'dir':  '\v[\/]((\.(git|hg|svn))|node_modules|build|bower_components)$',
  \ 'file': '\v\.(exe|so|dll)$',
  \ 'link': 'some_bad_symbolic_links',
  \ }

" vim-javascript
let g:javascript_conceal_function   = "ƒ"
let g:javascript_conceal_null       = "ø"
let g:javascript_conceal_this       = "@"
let g:javascript_conceal_return     = "⇚"
let g:javascript_conceal_undefined  = "¿"
let g:javascript_conceal_NaN        = "ℕ"
let g:javascript_conceal_prototype  = "¶"
let g:javascript_conceal_static     = "•"
let g:javascript_conceal_super      = "Ω"

let g:javascript_enable_domhtmlcss = 1

" emmet 
let g:user_emmet_install_global = 0
autocmd FileType html,css,markdown EmmetInstall
