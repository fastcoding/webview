OS=$(shell uname)
CXX=c++
ifeq ($(OS), Darwin)
    $(info os is $(OS))
    FLAGS=-DWEBVIEW_COCOA -std=c++11 -Wall -Wextra -pedantic
    LDFLAGS=-framework WebKit
else ifeq ($(OS), Linux)
    LDFLAGS="$(shell pkg-config --cflags --libs gtk+-3.0 webkit2gtk-4.0)"
    FLAGS="-DWEBVIEW_GTK -std=c++11 -Wall -Wextra -pedantic "
else

endif

all: lib/libwebview.dylib test/webview_main test/webview_test

test/webview_main: main.o
	mkdir -p test
	$(CXX) -o $@ $< $(LDFLAGS) 

lib/libwebview.dylib: webview.o
	mkdir -p lib
	$(CXX) -shared -o $@ $< $(LDFLAGS) 

test/webview_test: webview_test.o
	mkdir -p test
	$(CXX) -o $@ $< $(LDFLAGS) 

%.o:%.cc
	$(CXX) $(FLAGS) -c -o $@ $<

clean:
	rm -rf *.o lib/*.dylib test/webview_test test/webview_main
