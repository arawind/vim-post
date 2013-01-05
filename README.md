#Vim-Post
####Synchronise your files via POST through Vim
#####A vim plugin written in python

####Requirements:
vim compiled with python2
BeautifulSoup4 python2 module

#####Working:
Add the vim-post.vim file to your plugin directory (~/.vim/plugins) 
or add this to your ~/.vimrc
```viml
source /some/other/dir/vim-post.vim
```
(Optional) The config file goes in your working directory. If the dir doesn't have any config file, a new one will be created on first run

#####Config file:
It contains a json object whose values are used by the plugin to connect
'short'       : short name for the host - no use with this
'url'         : The POST url
'loginurl'    : The login page with the login form
'redir_to'    : The Form action of the login form ------> to be removed in future versions
'ua'          : User Agent - Default is Chromium's User-agent (Optional during entry)
'fields'      : The 'name's of the fields for logging in (The values for these will be taken during runtime via a prompt)
'extraFields' : Hidden fields' names ------> to be removed in future versions
'textField'   : The textarea field's name where the data has to be entered
