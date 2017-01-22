TWEAK_NAME = libIconSupport

libIconSupport_OBJCC_FILES = IconSupport.xm ISIconSupport.mm
libIconSupport_OBJCCFLAGS = -DAPP_ID=\"$(APP_ID)\" -include Headers.h -fvisibility=hidden
libIconSupport_FRAMEWORKS = UIKit
libIconSupport_INSTALL_PATH = "/Library/Application\ Support/IconSupport/Versions/3.0"

ARCHS ?= armv6

include $(THEOS)/makefiles/common.mk
include $(THEOS)/makefiles/tweak.mk
