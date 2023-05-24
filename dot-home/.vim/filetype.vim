if exists("markdown")
    finish
endif
augroup filetypedetect
au BufNewFile,BufRead *.markdown,*.mdown,*.mkd,*.mkdn,*.md setf markdown
augroup END
