#
# Makefile
# romgrk, 2020-11-02 21:58
#

CC ?= gcc

CC_EXISTS := $(shell command -v $(CC) 2> /dev/null)
ifndef CC_EXISTS
CC=gcc
endif

OS=$(shell uname | tr A-Z a-z)
ifeq ($(findstring mingw,$(OS)), mingw)
    OS='windows'
endif

ARCH=$(shell uname -m)
ifeq ($(ARCH), aarch64)
ARCH='arm64'
endif

all:
	echo $(ARCH)
	$(CC) -Ofast -c -Wall -static -fpic -o ./src/match.o ./src/match.c
	$(CC) -shared -o ./static/libfzy-$(OS)-$(ARCH).so ./src/match.o


# vim:ft=make
#
