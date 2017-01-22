TWEAK_NAME = libIconSupport

libIconSupport_OBJCC_FILES = IconSupport.xm ISIconSupport.mm ISAlertItem.xm ISLayoutRepairedAlertItem.xm ISStaleFileAlertItem.xm Preferences.xm
libIconSupport_OBJCCFLAGS = -DAPP_ID=\"$(APP_ID)\" -I ../../Common -include Headers.h -include Firmware.h -fvisibility=hidden
libIconSupport_FRAMEWORKS = UIKit
libIconSupport_INSTALL_PATH = "/Library/Application\ Support/IconSupport/Versions/4.0"

ARCHS ?= armv6 arm64

include $(THEOS)/makefiles/common.mk
include $(THEOS)/makefiles/tweak.mk
