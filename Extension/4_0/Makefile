TWEAK_NAME = libIconSupport

libIconSupport_OBJCC_FILES = IconSupport.xm ISIconSupport.xm ISAlertItem.xm ISLayoutRepairedAlertItem.xm ISStaleFileAlertItem.xm Preferences.xm
libIconSupport_OBJCCFLAGS = -DAPP_ID=\"$(APP_ID)\" -I $(THEOS_PROJECT_DIR)/Common -include $(THEOS_PROJECT_DIR)/Libraries/Common/firmware.h -include Headers.h -fvisibility=hidden
libIconSupport_FRAMEWORKS = UIKit
libIconSupport_INSTALL_PATH = "/Library/Application\ Support/IconSupport/Versions/4.0"

ARCHS ?= armv6 arm64

include $(THEOS)/makefiles/common.mk
include $(THEOS)/makefiles/tweak.mk
