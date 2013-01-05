if !has('python')
    echo "Error: Required vim compiled with +python"
    finish
endif
:command Upload call VimPost('upload')
:command Download call VimPost('download')
:command Reconfig call VimPost('config')


function! VimPost(doWhat)
python <<EOF

import vim
import urllib2, urllib, urlparse
import cookielib
from bs4 import BeautifulSoup
from itertools import izip
import json
import mimetools, mimetypes
import os, stat
#FROM http://pipe.scs.fsu.edu/PostHandler/MultipartPostHandler.py
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

doWhat = vim.eval("a:doWhat")
def raw_input(message = 'Input'):
    vim.command('call inputsave()')
    vim.command('let user_input = input("'+message+' ")')
    vim.command('call inputrestore()')
    return  vim.eval('user_input')
if doWhat=='config':
    createConfig()
    exit()
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
    'textField':textField
    }
    f.write(json.dumps(dic,sort_keys = False,indent = 4))
    f.close()
#START 

#Take current file name from the buffer
filename = vim.current.buffer.name.split('/')[-1] #'common.js'
textField = dic['textField']
url = dic['url'] #'http://en.wikipedia.org/w/index.php?title=User:Aravindp1510/'+filename+'&action=edit'
url = url[:url.find('*')]+filename+url[url.find('*')+1:]
values = [] 
loginurl = dic['loginurl'] #'http://en.wikipedia.org/wiki/Special:UserLogin'
redir_to = dic['redir_to'] #'http://en.wikipedia.org/w/index.php?title=Special:UserLogin&action=submitlogin&type=login'
ua = dic['ua'] #'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.11 (KHTML, like Gecko) Chrome/23.0.1271.97 Safari/537.11'
fields = dic['fields'] #['wpName','wpPassword']
for field in fields:
    values.append(raw_input(field+"?"))
extraFields = dic['extraFields'] #['wpLoginToken','wpLoginAttempt']

cookies = cookielib.CookieJar()
opener1 = urllib2.build_opener(urllib2.HTTPCookieProcessor(cookies))
opener1.addheaders = [('User-agent',ua)]

response1 = opener1.open(loginurl)
soup = BeautifulSoup(response1.read())

#Get the extra values 
extraVals = []
for field in extraFields:
    extraField = (soup.select('input[name="'+field+'"]')[0]['value'])
    extraVals.append(extraField)
fields = fields+extraFields
values = values+extraVals

#Form the post data
data = dict(izip(fields,values))
data = urllib.urlencode(data)
data = data.encode('utf-8')

#Send the post data, collect auth tokens
response2 = opener1.open(redir_to,data)

#Open the post url
response3 = opener1.open(url)
soup = BeautifulSoup(response3.read())

txtarea = soup.select('textarea[name="'+textField+'"]')[0]

if(doWhat=='upload'):
    form = txtarea.find_parent('form')
    formAttrs = form.attrs
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
    schemeDomain = scheme+'://'+domain
    if(formAttrs['action'].find(domain) == -1):
        if formAttrs['action'][0] == '/':
            postURL = schemeDomain+formAttrs['action']
        else:
            postURL = schemeDomain+'/'+formAttrs['action']
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
EOF
endfunction
