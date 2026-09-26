CXX ?= g++
CXXFLAGS += -O3 -std=c++14 -Wall -Wextra
INC = $(shell pkg-config --cflags libgcrypt)
LIBS = $(shell pkg-config --libs libgcrypt 2>/dev/null || echo "-lgcrypt") -lnvrtc -lcuda -lpthread -ldl

SRCS = main.cpp key_test.cpp key_test_pattern.cpp gpg_helper.cpp
OBJS = $(SRCS:.cpp=.o)

.PHONY: all clean static

all: gpg-fingerprint-filter-gpu

%.o: %.cpp
	$(CXX) -c -o $@ $(CXXFLAGS) $(INC) $<

gpg-fingerprint-filter-gpu: $(OBJS)
	$(CXX) -o $@ $(CXXFLAGS) $^ $(LIBS)

# Static build against static libgcrypt and libgpg-error for max portability
static: $(OBJS)
	$(CXX) -o gpg-fingerprint-filter-gpu $(CXXFLAGS) $^ /usr/lib/x86_64-linux-gnu/libgcrypt.a /usr/lib/x86_64-linux-gnu/libgpg-error.a -lnvrtc -lcuda -lpthread -ldl

clean:
	-rm -f *.o gpg-fingerprint-filter-gpu gpg-fingerprint-filter-gpu.exe
