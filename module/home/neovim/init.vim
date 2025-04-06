call deoplete#enable()
call deoplete#custom#option('auto_complete_delay', 0)

let g:suda_smart_edit = 1

filetype plugin on
syntax on
set termguicolors
set bg=dark
set mouse=a
set nohlsearch
set ignorecase
set smartcase
set clipboard+=unnamedplus
set nocompatible
set encoding=utf-8
set relativenumber
set tabstop=4
set shiftwidth=4
set wildmode=longest,list,full
set updatetime=100
set colorcolumn=80
highlight ColorColumn ctermbg=black
highlight clear SignColumn
set list
set listchars=tab:→\ ,extends:»,precedes:«,trail:▒

" Emacs moves
inoremap <C-a> <Esc>I
inoremap <C-b> <Left>
inoremap <C-e> <Esc>A
inoremap <C-f> <Right>
inoremap <C-n> <Down>
inoremap <C-p> <Up>
nnoremap <C-b> <Left>
nnoremap <C-f> <Right>
vnoremap <C-b> <Left>
vnoremap <C-f> <Right>

" Exit with C-d
cnoremap <C-d> <Esc>
inoremap <C-d> <Esc>
nnoremap <C-d> <Esc>
vnoremap <C-d> <Esc>

" Some nice things
inoremap <C-s> <Esc>:w<CR>a
inoremap <C-y> <Esc><C-r>a
inoremap <C-z> <Esc>ua
nnoremap <C-d> :q<CR>
nnoremap <C-e> :Explore<CR>
nnoremap <C-s> :w<CR>
vnoremap <C-s> :sort<CR>

" Tools for tabs
inoremap <C-PageDown> <Esc>:tabnext<CR>
inoremap <C-PageUp> <Esc>:tabprevious<CR>
nnoremap <C-End> :tabnew<CR>:edit<Space>

" Shortcutting split navigation, saving a keypress:
map <C-h> <C-w>h
map <C-j> <C-w>j
map <C-k> <C-w>k
map <C-l> <C-w>l

" Replace all is aliased to S.
nnoremap S :%s//g<Left><Left>

" Remove trailing whitespace
noremap <M-Space> :%s/\s\+$//e<CR>

" Auto-completion
inoremap /* /*<space><space>*/<Esc>2hi
inoremap /** /**<space><space>*/<Esc>2hi
inoremap // //<space>

" Exit terminal with Escape
tnoremap <Esc> <C-\><C-n>

" dark completion menu
highlight Pmenu ctermfg=white ctermbg=black
