" Aravind Pedapudi
" Vim-Post plugin
" http://arawind.com
" http://github.com/arawind/vim-post
" Requires + python2 compiled vim 
"          + python2 BeautifulSoup module from crummy.com
" Uses POST to sync the current file on the server
" Works with any captcha-less online editors
" Tested for: Wikimedia User script editor, Wordpress theme/plugin editors

" Insert 'source /the/directory/vim-post.vim' in your '~/.vimrc' file
" OR
" Add to your '~/.vim/plugins' folder -- NOT TESTED

" NOTE ##########################################################
" The prompt where this plugin asks for your username/passwd,
" echoes out every character. That is, your password will be visible
" as you enter it. This has to be fixed.

" First run: Creates a config file which asks for the login url, the post url and a bunch of other stuff

" Commands
"       :Upload     Upload the current file onto the server
"       :Download   Download the latest file from the server
"       :Reconfig   Reconfigure the config file (a json file, easier to edit by hand)

" Lots of exceptions to handle, too much work.. Though willing to do if encouraged


if !has('python')
    echo "Error: Required vim compiled with +python"
    finish
endif
:command Upload call VimPost('upload')
:command Download call VimPost('download')
:command Reconfig call VimPost('config')

" You can call this function even this way--  :call VimPost('upload')

function! VimPost(doWhat)
python <<EOF

# VIM module for getting buffer data, updating it too
# BeautifulSoup for screenscraping
# json for config file
# mimetools, mimetypes, os, stat modules required by MultipartPostHandler

import vim
import urllib2, urllib, urlparse
import cookielib
from bs4 import BeautifulSoup
from itertools import izip
import json
import mimetools, mimetypes
import os, stat

# Had to copy/paste this MultipartPostHandler,
# as I didn't know how to import modules into vim-python plugins


# FROM http://pipe.scs.fsu.edu/PostHandler/MultipartPostHandler.py
class Callable:
    def __init__(self, anycallable):
        self.__call__ = anycallable

# Controls how sequences are uncoded. If true, elements may be given multiple values by
#  assigning a sequence.
doseq = 1

class MultipartPostHandler(urllib2.BaseHandler):
    handler_order = urllib2.HTTPHandler.handler_order - 10 # needs to run first
    def http_request(self, request):
        data = request.get_data()
        #print(data)
        if data is not None and type(data) != str:
            v_files = []
            v_vars = []
            try:
                 for(key, value) in data.items():
                     if type(value) == file:
                         v_files.append((key, value))
                     else:
                         v_vars.append((key, value))
            except TypeError:
                systype, value, traceback = sys.exc_info()
                raise TypeError, "not a valid non-string sequence or mapping object", traceback

#            if len(v_files) == 0:
#                data = urllib.urlencode(v_vars, doseq)
#            else:  Removed the conditions as this makes MultipartPostHandler handles only forms with files as multipart-forms
                        
            boundary, data = self.multipart_encode(v_vars, v_files)
            contenttype = 'multipart/form-data; boundary=%s' % boundary
            if(request.has_header('Content-Type')
               and request.get_header('Content-Type').find('multipart/form-data') != 0):
               print "Replacing %s with %s" % (request.get_header('content-type'), 'multipart/form-data')
            request.add_unredirected_header('Content-Type', contenttype)

            request.add_data(data)
        return request

    def multipart_encode(vars, files, boundary = None, buffer = None):
        if boundary is None:
            boundary = mimetools.choose_boundary()
        if buffer is None:
            buffer = ''
        for(key, value) in vars:
            buffer += '--%s\r\n' % boundary
            buffer += 'Content-Disposition: form-data; name="%s"' % key
            buffer += '\r\n\r\n' + value + '\r\n'
        for(key, fd) in files:
            file_size = os.fstat(fd.fileno())[stat.ST_SIZE]
            filename = fd.name.split('/')[-1]
            contenttype = mimetypes.guess_type(filename)[0] or 'application/octet-stream'
            buffer += '--%s\r\n' % boundary
            buffer += 'Content-Disposition: form-data; name="%s"; filename="%s"\r\n' % (key, filename)
            buffer += 'Content-Type: %s\r\n' % contenttype
            # buffer += 'Content-Length: %s\r\n' % file_size
            fd.seek(0)
            buffer += '\r\n' + fd.read() + '\r\n'
        buffer += '--%s--\r\n\r\n' % boundary
        return boundary, buffer
    multipart_encode = Callable(multipart_encode)

    https_request = http_request
#END MultipartPostHandler


# Get arguments

doWhat = vim.eval("a:doWhat")

# Reconfigure raw_input to accept vim inputs

# FIND OUT A WAY TO PREVENT ECHOING

def raw_input(message = 'Input'):
    vim.command('call inputsave()')
    vim.command('let user_input = input("'+message+' ")')
    vim.command('call inputrestore()')
    return  vim.eval('user_input')


# Function to create the config file

def createConfig():
    short = raw_input('Short name: ')
    url = raw_input('URL (replace filename with * ): ')
    loginurl = raw_input('Login url: ')
    redir_to = raw_input('Form action: ')
    ua = raw_input('User agent[optional]: ')
    if ua == '':
        ua = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.11 (KHTML, like Gecko) Chrome/23.0.1271.97 Safari/537.11'
    fields = raw_input('Names of login fields separated by a comma: ')
    fields = fields.split(',')
    extraFields = raw_input('Names of extra login fields separated by a comma: ')
    extraFields = extraFields.split(',')
    textField = raw_input('\'Name\' of the textarea field: ')
    f = open('config','w')
    dic={
    'short':short,
    'url':url,
    'loginurl':loginurl,
    'redir_to':redir_to,
    'ua':ua,
    'fields':fields,
    'extraFields':extraFields,
    'textField':textField,
    'cookieLength':0
    }
    f.write(json.dumps(dic,sort_keys = False,indent = 4))
    f.close()



#START 

try:
    f = open('config','r')
    try:
        dic = json.load(f)
        f.close()
    except ValueError:
        f.close()
        createConfig()
except:
    createConfig()


# Take current file name from the buffer
# Does not so good job as it gets the filename by splitting the '/'s and getting the last word
# Wordpress theme editor uses the '/' character to separate folder and file name, and this causes confusion (index.php and lib/index.php will upload to the same file, index.php)


filename = vim.current.buffer.name.split('/')[-1] #'common.js'
textField = dic['textField']
url = dic['url'] #'http://en.wikipedia.org/w/index.php?title=User:Aravindp1510/'+filename+'&action=edit'

# While entering the url into the config file, add a * where the filename goes
# This * is replaced by the current filename

url = url[:url.find('*')]+filename+url[url.find('*')+1:]
values = [] 
loginurl = dic['loginurl'] #'http://en.wikipedia.org/wiki/Special:UserLogin'

# redir_to = form action; It is redundant as I can scrape it off from the page. Will be removed soon

redir_to = dic['redir_to'] #'http://en.wikipedia.org/w/index.php?title=Special:UserLogin&action=submitlogin&type=login'
ua = dic['ua'] #'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.11 (KHTML, like Gecko) Chrome/23.0.1271.97 Safari/537.11'
fields = dic['fields'] #['wpName','wpPassword']

# extraFields = Input fields through which the form sends generated information
# Unnecessary again. Will be removed

extraFields = dic['extraFields'] #['wpLoginToken','wpLoginAttempt']

# Check for login through cookies

login=True

cookies = cookielib.MozillaCookieJar('.cookies')
if 'cookieLength' in dic:
    if dic['cookieLength'] !=0:
        cookies.load('.cookies',ignore_discard=True)
        login = False
else:
    dic['cookieLength'] = 0
    f=open('config','w')
    f.write(json.dumps(dic,sort_keys=False,indent=4))
    f.close()
    
opener1 = urllib2.build_opener(urllib2.HTTPCookieProcessor(cookies))
opener1.addheaders = [('User-agent',ua)]

if login:
    for field in fields:
        values.append(raw_input(field+"?"))
    response1 = opener1.open(loginurl)
    soup = BeautifulSoup(response1.read())
#Get the generated values (To be removed) 
    extraVals = []
    if len(extraFields[0])>0:
        for field in extraFields:
            extraField = (soup.select('input[name="'+field+'"]')[0]['value'])
            extraVals.append(extraField)
        fields = fields+extraFields
        values = values+extraVals

#Form the post data
    data = dict(izip(fields,values))
    data = urllib.urlencode(data)
    data = data.encode('utf-8')

# opener1 as of now is not MultipartForm compatible. So if the login screen has a multipartform, this needs to be adjusted

#Send the post data, collect auth tokens
    response2 = opener1.open(redir_to,data)


#Open the post url
response3 = opener1.open(url)
soup = BeautifulSoup(response3.read())
txtarea = soup.select('textarea[name="'+textField+'"]')[0]

if doWhat=='config':
    createConfig()

if(doWhat=='upload'):
    form = txtarea.find_parent('form')
    formAttrs = form.attrs
    #print(formAttrs)
    hiddenInputs = form.select('input[type="hidden"]')
    hiddenData={}
    for hidden in hiddenInputs:
        try:
            hiddenData[hidden.attrs['name']] = hidden.attrs['value']
        except:
            hiddenData[hidden.attrs['name']] = ''
            #pass
    scheme = urlparse.urlparse(url)[0]
    domain = urlparse.urlparse(url)[1]
    path=urlparse.urlparse(url)[2]
    schemeDomain = scheme+'://'+domain
    if(formAttrs['action'].find(domain) == -1):
        #print(path)
        if formAttrs['action'][0] == '/':
            postURL = schemeDomain+formAttrs['action']
        else:
            postURL = schemeDomain+path[:path.rfind('/')]+'/'+formAttrs['action']
    #Get current buffer's data
    bData = vim.current.buffer[:]
    bData = ('\n'.join(bData))
    postData = hiddenData
    postData[textField] = bData

    #Test for enctype in form
    try:
        enctype=formAttrs['enctype']
        if(enctype=="multipart/form-data"):
            opener1=urllib2.build_opener(urllib2.HTTPCookieProcessor(cookies),MultipartPostHandler)
            opener1.addheaders = [('User-agent',ua)]
        else:
            postData = urllib.urlencode(postData)
            postData = postData.encode('utf-8')
    except:
        postData = urllib.urlencode(postData)
        postData = postData.encode('utf-8')
    #print(postURL)
    response4 = opener1.open(postURL,postData)
    print('Uploaded!')
#Download
elif doWhat=='download':
    dwnData = txtarea.string
    curFileName = vim.current.buffer.name
    vim.command('w! '+curFileName+'.bak')
    vim.command('bd!')
    f = open(curFileName,'w')
    f.write(dwnData)
    f.close()
    vim.command('badd '+curFileName)
    vim.command('buffer '+curFileName)
    print('Downloaded to '+curFileName+'!')

cookies.save('.cookies',ignore_discard=True)
if dic['cookieLength']==0:
    dic['cookieLength'] = len(cookies)
    f=open('config','w')
    f.write(json.dumps(dic, sort_keys=False, indent=4))
    f.close()
EOF
endfunction
