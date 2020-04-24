if empty(glob('~/.vim/autoload/plug.vim'))
  silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs
    \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif
call plug#begin()
Plug 'scrooloose/nerdtree', { 'tag': '5.0.0' }
Plug 'altercation/vim-colors-solarized'
Plug 'godlygeek/tabular', { 'tag': '1.0.0' }
Plug 'tpope/vim-surround', { 'tag': 'v2.1' }
Plug 'dense-analysis/ale', { 'tag': 'v2.6.0' }
Plug 'leafgarland/typescript-vim'
call plug#end()

set nocompatible
set backspace=indent,eol,start
set history=50
set ruler
set number
set incsearch
set hlsearch
set ignorecase
set smartcase
set tabstop=4
set shiftwidth=4
set expandtab
set wildmenu
set wildmode=list:longest,full
set paste
syntax on
filetype plugin indent on
augroup vimrcEx
au!
autocmd FileType text setlocal textwidth=78
autocmd BufReadPost *
  \ if line("'\"") > 1 && line("'\"") <= line("$") |
  \   exe "normal! g`\"" |
  \ endif
augroup END
runtime macros/matchit.vim
nnoremap <silent> <C-l> :<C-u>nohlsearch<CR><C-l>
set t_Co=256
set background=dark
colorscheme solarized
autocmd VimEnter * NERDTree
autocmd VimEnter * wincmd p
