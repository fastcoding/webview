local ffi=require'ffi'
ffi.cdef[[
typedef void *webview_t;
// Creates a new webview instance. If debug is non-zero - developer tools will
// be enabled (if the platform supports them). Window parameter can be a
// pointer to the native window handle. If it's non-null - then child WebView
// is embedded into the given parent window. Otherwise a new window is created.
// Depending on the platform, a GtkWindow, NSWindow or HWND pointer can be
// passed here.
 webview_t webview_create(int debug, void *window);

// Destroys a webview and closes the native window.
 void webview_destroy(webview_t w);

// Runs the main loop until it's terminated. After this function exits - you
// must destroy the webview.
 void webview_run(webview_t w);

// Stops the main loop. It is safe to call this function from another other
// background thread.
 void webview_terminate(webview_t w);

// Posts a function to be executed on the main thread. You normally do not need
// to call this function, unless you want to tweak the native window.
 void
webview_dispatch(webview_t w, void (*fn)(webview_t w, void *arg), void *arg);

// Returns a native window handle pointer. When using GTK backend the pointer
// is GtkWindow pointer, when using Cocoa backend the pointer is NSWindow
// pointer, when using Win32 backend the pointer is HWND pointer.
 void *webview_get_window(webview_t w);

// Updates the title of the native window. Must be called from the UI thread.
 void webview_set_title(webview_t w, const char *title);

// Window size hints

enum { 
    HINT_NONE,  // Width and height are default size
    HINT_MIN,   // Width and height are minimum bounds
    HINT_MAX,   // Width and height are maximum bounds
    HINT_FIXED // Window size can not be changed by a user
};

// Updates native window size. See WEBVIEW_HINT constants.
 void webview_set_size(webview_t w, int width, int height,
                                  int hints);

// Navigates webview to the given URL. URL may be a data URI, i.e.
// "data:text/text,<html>...</html>". It is often ok not to url-encode it
// properly, webview will re-encode it for you.
 void webview_navigate(webview_t w, const char *url);

// Injects JavaScript code at the initialization of the new page. Every time
// the webview will open a the new page - this initialization code will be
// executed. It is guaranteed that code is executed before window.onload.
 void webview_init(webview_t w, const char *js);

// Evaluates arbitrary JavaScript code. Evaluation happens asynchronously, also
// the result of the expression is ignored. Use RPC bindings if you want to
// receive notifications about the results of the evaluation.
 void webview_eval(webview_t w, const char *js);

// Binds a native C callback so that it will appear under the given name as a
// global JavaScript function. Internally it uses webview_init(). Callback
// receives a request string and a user-provided argument pointer. Request
// string is a JSON array of all the arguments passed to the JavaScript
// function.
 void webview_bind(webview_t w, const char *name,
                              void (*fn)(const char *seq, const char *req,
                                         void *arg),
                              void *arg);

// Allows to return a value from the native binding. Original request pointer
// must be provided to help internal RPC engine match requests with responses.
// If status is zero - result is expected to be a valid JSON result value.
// If status is not zero - result is an error JSON object.
 void webview_return(webview_t w, const char *seq, int status,
                                const char *result) ;
]]

-- for windows, run: checknetisolation LoopbackExempt -a -n=Microsoft.Win32WebViewHost_cw5n1h2txyewy

local api=ffi.load('./lib/libwebview.dylib')

local _mt={}

function _mt:__index(key)
    local r=rawget(self,key)
    if r~=nil then return r end
    if key=='reply' then key='return' end
    local meth='webview_'..key 
    local f=api[meth]
    if f then 
       return function(self,...)
           assert(self.view,'webview is nil')
           return f(self.view,...)
       end
    end
end

function _mt:__gc()
    if self.view then 
        api.webview_destroy(self.view)
        self.view=nil
    end
end

local function create(dbg,window)
    local obj={view=api.webview_create(dbg or 0,window)}
    return setmetatable(obj,_mt)
end

if not ... then 
    local cjson=require'cjson'
    local win=create()
    win:set_title('test win')
    win:set_size(640,480,0)
    win:bind('test',function(seq,req,arg)
        local sreq=ffi.string(req)
        print('got req:',sreq,'\nseq:',ffi.string(seq))
        local jsn_req=cjson.decode(sreq);
        local ret=jsn_req[1]+jsn_req[2]
        win:reply(seq,0,cjson.encode(ret))
    end,nil) 
    win:bind('closewin',function(seq,req,arg)
        win:terminate()
    end,nil)
--    win:init('')
    
    win:navigate([[data:text/html,
    <!doctype html>
    <html>
      <body>
      <div><h1>TEST</h1></div>
      <b>result:</b><i id='result'></i>
      <div id='navigator'></div>
      <div><button onclick='closewin()'>Shut me down</button></div>
      </body>
      <script>
        window.onload = function() {
          test(1, 2).then(function(res) {
            console.log('add res', res);
            document.getElementById('result').innerText=res
            document.getElementById('navigator').innerText = `hello, ${navigator.userAgent}`;
          });
        };
        </script>
    </html>
    ]])
    win:run() 
else
   return create
end

